// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../interfaces/IPool.sol";
import "../../interfaces/IAToken.sol";
import "../../interfaces/IDebtToken.sol";
import "../../interfaces/IPriceOracle.sol";
import "../../interfaces/IInterestRateStrategy.sol";
import "../../interfaces/IFlashLoanReceiver.sol";
import "../../libraries/ReserveConfiguration.sol";
import "../../libraries/WadRayMath.sol";
import "../../libraries/MathUtils.sol";
import "../libraries/types/DataTypes.sol";

/**
 * @title Pool
 * @notice Main entry point for user interactions with the lending protocol
 */
contract Pool is IPool, ReentrancyGuard, Pausable, Ownable {
    using SafeERC20 for IERC20;
    using ReserveConfiguration for ReserveConfigurationMap;
    using WadRayMath for uint256;

    // Constants
    uint256 public constant FLASHLOAN_PREMIUM_TOTAL = 9; // 0.09%
    uint256 public constant FLASHLOAN_PREMIUM_TO_PROTOCOL = 3; // 0.03%
    uint256 public constant MAX_NUMBER_RESERVES = 128;
    uint256 public constant LIQUIDATION_CLOSE_FACTOR_PERCENT = 5000; // 50%
    uint256 public constant LIQUIDATION_PROTOCOL_FEE = 1000; // 10%

    // State variables
    mapping(address => DataTypes.ReserveData) public reserves;
    mapping(address => mapping(address => DataTypes.UserConfigurationMap)) public usersConfig;
    address[] public reservesList;
    address public priceOracle;
    uint256 public reservesCount;

    // Events
    event ReserveInitialized(
        address indexed asset,
        address indexed aToken,
        address stableDebtToken,
        address variableDebtToken,
        address interestRateStrategy
    );

    event Supply(
        address indexed reserve,
        address user,
        address indexed onBehalfOf,
        uint256 amount,
        uint16 indexed referralCode
    );

    event Withdraw(
        address indexed reserve,
        address indexed user,
        address indexed to,
        uint256 amount
    );

    event Borrow(
        address indexed reserve,
        address user,
        address indexed onBehalfOf,
        uint256 amount,
        uint256 borrowRateMode,
        uint256 borrowRate,
        uint16 indexed referralCode
    );

    event Repay(
        address indexed reserve,
        address indexed user,
        address indexed repayer,
        uint256 amount,
        bool useATokens
    );

    event FlashLoan(
        address indexed target,
        address indexed initiator,
        address indexed asset,
        uint256 amount,
        uint256 premium
    );

    event LiquidationCall(
        address indexed collateralAsset,
        address indexed debtAsset,
        address indexed user,
        uint256 debtToCover,
        uint256 liquidatedCollateralAmount,
        address liquidator,
        bool receiveAToken
    );

    modifier onlyReserve(address asset) {
        require(reserves[asset].id != 0 || reservesList[0] == asset, "INVALID_RESERVE");
        _;
    }

    constructor(address _priceOracle) Ownable(msg.sender) {
        priceOracle = _priceOracle;
    }

    /**
     * @notice Initializes a reserve
     */
    function initReserve(
        address asset,
        address aTokenAddress,
        address stableDebtTokenAddress,
        address variableDebtTokenAddress,
        address interestRateStrategyAddress
    ) external onlyOwner {
        require(reserves[asset].id == 0 && reservesList[0] != asset, "RESERVE_EXISTS");
        require(reservesCount < MAX_NUMBER_RESERVES, "MAX_RESERVES");

        reserves[asset].id = uint16(reservesCount);
        reserves[asset].aTokenAddress = aTokenAddress;
        reserves[asset].stableDebtTokenAddress = stableDebtTokenAddress;
        reserves[asset].variableDebtTokenAddress = variableDebtTokenAddress;
        reserves[asset].interestRateStrategyAddress = interestRateStrategyAddress;
        reserves[asset].liquidityIndex = uint128(WadRayMath.RAY);
        reserves[asset].variableBorrowIndex = uint128(WadRayMath.RAY);
        reserves[asset].lastUpdateTimestamp = uint40(block.timestamp);

        reservesList.push(asset);
        reservesCount++;

        emit ReserveInitialized(
            asset,
            aTokenAddress,
            stableDebtTokenAddress,
            variableDebtTokenAddress,
            interestRateStrategyAddress
        );
    }

    /**
     * @notice Supplies an `amount` of underlying asset into the reserve
     */
    function supply(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16
    ) external override nonReentrant whenNotPaused {
        DataTypes.ReserveData storage reserve = reserves[asset];
        require(reserve.id != 0 || reservesList[0] == asset, "INVALID_RESERVE");
        require(amount > 0, "INVALID_AMOUNT");

        _updateInterestRates(asset, reserve, 0, 0);

        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        uint256 normalizedIncome = _getNormalizedIncome(reserve);
        IAToken(reserve.aTokenAddress).mint(
            onBehalfOf,
            amount.wadToRay().rayDiv(normalizedIncome)
        );

        emit Supply(asset, msg.sender, onBehalfOf, amount, 0);
    }

    /**
     * @notice Withdraws an `amount` of underlying asset from the reserve
     */
    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external override nonReentrant whenNotPaused {
        DataTypes.ReserveData storage reserve = reserves[asset];
        require(reserve.id != 0 || reservesList[0] == asset, "INVALID_RESERVE");

        uint256 userBalance = IAToken(reserve.aTokenAddress).balanceOf(msg.sender);
        uint256 amountToWithdraw = amount;

        if (amount == type(uint256).max) {
            amountToWithdraw = userBalance;
        }

        require(amountToWithdraw > 0, "INVALID_AMOUNT");
        require(userBalance >= amountToWithdraw, "INSUFFICIENT_BALANCE");

        _updateInterestRates(asset, reserve, 0, 0);

        uint256 normalizedIncome = _getNormalizedIncome(reserve);
        IAToken(reserve.aTokenAddress).burn(
            msg.sender,
            amountToWithdraw.wadToRay().rayDiv(normalizedIncome)
        );

        IERC20(asset).safeTransfer(to, amountToWithdraw);

        emit Withdraw(asset, msg.sender, to, amountToWithdraw);
    }

    /**
     * @notice Allows users to borrow a specific `amount` of the reserve underlying asset
     */
    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16,
        address onBehalfOf
    ) external override nonReentrant whenNotPaused {
        DataTypes.ReserveData storage reserve = reserves[asset];
        require(reserve.id != 0 || reservesList[0] == asset, "INVALID_RESERVE");
        require(amount > 0, "INVALID_AMOUNT");
        require(
            interestRateMode == uint256(DataTypes.InterestRateMode.STABLE) ||
                interestRateMode == uint256(DataTypes.InterestRateMode.VARIABLE),
            "INVALID_INTEREST_RATE_MODE"
        );

        _updateInterestRates(asset, reserve, 0, 0);

        // Check health factor
        (uint256 totalCollateralBase, uint256 totalDebtBase, , , , uint256 healthFactor) = getUserAccountData(
            onBehalfOf
        );
        require(healthFactor > 1e18, "HEALTH_FACTOR_TOO_LOW");

        uint256 normalizedDebt;
        if (interestRateMode == uint256(DataTypes.InterestRateMode.VARIABLE)) {
            normalizedDebt = _getNormalizedVariableDebt(reserve);
            IDebtToken(reserve.variableDebtTokenAddress).mint(
                onBehalfOf,
                amount.wadToRay().rayDiv(normalizedDebt),
                reserve.variableBorrowIndex
            );
        } else {
            revert("STABLE_BORROW_NOT_IMPLEMENTED");
        }

        IERC20(asset).safeTransfer(onBehalfOf, amount);

        uint256 borrowRate = reserve.currentVariableBorrowRate;
        emit Borrow(
            asset,
            msg.sender,
            onBehalfOf,
            amount,
            interestRateMode,
            borrowRate,
            0
        );
    }

    /**
     * @notice Repays a borrowed `amount` on a specific reserve
     */
    function repay(
        address asset,
        uint256 amount,
        uint256 rateMode,
        address onBehalfOf
    ) external override nonReentrant whenNotPaused returns (uint256) {
        DataTypes.ReserveData storage reserve = reserves[asset];
        require(reserve.id != 0 || reservesList[0] == asset, "INVALID_RESERVE");

        _updateInterestRates(asset, reserve, 0, 0);

        uint256 repayAmount = amount;
        if (rateMode == uint256(DataTypes.InterestRateMode.VARIABLE)) {
            uint256 userDebt = IDebtToken(reserve.variableDebtTokenAddress).balanceOf(
                onBehalfOf
            );
            if (repayAmount == type(uint256).max) {
                repayAmount = userDebt;
            }
            require(repayAmount > 0, "INVALID_AMOUNT");

            uint256 normalizedDebt = _getNormalizedVariableDebt(reserve);
            IDebtToken(reserve.variableDebtTokenAddress).burn(
                onBehalfOf,
                repayAmount.wadToRay().rayDiv(normalizedDebt),
                reserve.variableBorrowIndex
            );
        } else {
            revert("STABLE_BORROW_NOT_IMPLEMENTED");
        }

        IERC20(asset).safeTransferFrom(msg.sender, address(this), repayAmount);

        emit Repay(asset, onBehalfOf, msg.sender, repayAmount, false);
        return repayAmount;
    }

    /**
     * @notice Allows smartcontracts to access the liquidity of the pool within one transaction
     */
    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata,
        address,
        bytes calldata params,
        uint16
    ) external override nonReentrant whenNotPaused {
        require(assets.length == amounts.length, "INCONSISTENT_PARAMS");

        uint256[] memory premiums = new uint256[](assets.length);
        uint256[] memory totalAmounts = new uint256[](assets.length);

        // Transfer assets to receiver
        for (uint256 i = 0; i < assets.length; i++) {
            DataTypes.ReserveData storage reserve = reserves[assets[i]];
            require(reserve.id != 0 || reservesList[0] == assets[i], "INVALID_RESERVE");

            premiums[i] = amounts[i].wadMul(FLASHLOAN_PREMIUM_TOTAL).wadDiv(10000);
            totalAmounts[i] = amounts[i] + premiums[i];

            IERC20(assets[i]).safeTransfer(receiverAddress, amounts[i]);
        }

        // Execute flash loan
        require(
            IFlashLoanReceiver(receiverAddress).executeOperation(
                assets,
                amounts,
                premiums,
                msg.sender,
                params
            ),
            "FLASH_LOAN_EXECUTION_FAILED"
        );

        // Collect repayment
        for (uint256 i = 0; i < assets.length; i++) {
            IERC20(assets[i]).safeTransferFrom(
                receiverAddress,
                address(this),
                totalAmounts[i]
            );

            emit FlashLoan(
                receiverAddress,
                msg.sender,
                assets[i],
                amounts[i],
                premiums[i]
            );
        }
    }

    /**
     * @notice Allows liquidators to repay a borrow on behalf of a borrower and receive collateral
     */
    function liquidationCall(
        address collateralAsset,
        address debtAsset,
        address user,
        uint256 debtToCover,
        bool receiveAToken
    ) external override nonReentrant whenNotPaused {
        DataTypes.ReserveData storage collateralReserve = reserves[collateralAsset];
        DataTypes.ReserveData storage debtReserve = reserves[debtAsset];

        require(
            collateralReserve.id != 0 || reservesList[0] == collateralAsset,
            "INVALID_COLLATERAL"
        );
        require(debtReserve.id != 0 || reservesList[0] == debtAsset, "INVALID_DEBT");

        (uint256 totalCollateralBase, uint256 totalDebtBase, , , , uint256 healthFactor) = getUserAccountData(
            user
        );
        require(healthFactor < 1e18, "HEALTH_FACTOR_NOT_BELOW_THRESHOLD");

        _updateInterestRates(collateralAsset, collateralReserve, 0, 0);
        _updateInterestRates(debtAsset, debtReserve, 0, 0);

        uint256 userDebt = IDebtToken(debtReserve.variableDebtTokenAddress).balanceOf(user);
        uint256 maxLiquidationDebt = userDebt.wadMul(LIQUIDATION_CLOSE_FACTOR_PERCENT).wadDiv(
            10000
        );
        uint256 actualDebtToCover = debtToCover > maxLiquidationDebt
            ? maxLiquidationDebt
            : debtToCover;

        uint256 normalizedDebt = _getNormalizedVariableDebt(debtReserve);
        IDebtToken(debtReserve.variableDebtTokenAddress).burn(
            user,
            actualDebtToCover.wadToRay().rayDiv(normalizedDebt),
            debtReserve.variableBorrowIndex
        );

        IERC20(debtAsset).safeTransferFrom(msg.sender, address(this), actualDebtToCover);

        uint256 collateralPrice = IPriceOracle(priceOracle).getAssetPrice(collateralAsset);
        uint256 debtPrice = IPriceOracle(priceOracle).getAssetPrice(debtAsset);
        
        // Convert prices from 8 decimals to 18 decimals (WAD)
        uint256 collateralPriceWad = collateralPrice * 1e10;
        uint256 debtPriceWad = debtPrice * 1e10;
        
        uint256 collateralAmount = actualDebtToCover
            .wadMul(debtPriceWad)
            .wadDiv(collateralPriceWad)
            .wadMul(10500)
            .wadDiv(10000); // 5% bonus

        uint256 normalizedIncome = _getNormalizedIncome(collateralReserve);
        if (receiveAToken) {
            IAToken(collateralReserve.aTokenAddress).mint(
                msg.sender,
                collateralAmount.wadToRay().rayDiv(normalizedIncome)
            );
        } else {
            IAToken(collateralReserve.aTokenAddress).burn(
                user,
                collateralAmount.wadToRay().rayDiv(normalizedIncome)
            );
            IERC20(collateralAsset).safeTransfer(msg.sender, collateralAmount);
        }

        emit LiquidationCall(
            collateralAsset,
            debtAsset,
            user,
            actualDebtToCover,
            collateralAmount,
            msg.sender,
            receiveAToken
        );
    }

    /**
     * @notice Returns the user account data across all the reserves
     */
    function getUserAccountData(
        address user
    )
        public
        view
        override
        returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        )
    {
        for (uint256 i = 0; i < reservesList.length; i++) {
            address asset = reservesList[i];
            DataTypes.ReserveData storage reserve = reserves[asset];

            uint256 assetPrice = IPriceOracle(priceOracle).getAssetPrice(asset);
            uint256 collateralBalance = IAToken(reserve.aTokenAddress).balanceOf(user);
            uint256 debtBalance = IDebtToken(reserve.variableDebtTokenAddress).balanceOf(user);

            // Convert price from 8 decimals to 18 decimals (WAD)
            uint256 assetPriceWad = assetPrice * 1e10;

            if (collateralBalance > 0) {
                totalCollateralBase += collateralBalance.wadMul(assetPriceWad);
            }
            if (debtBalance > 0) {
                totalDebtBase += debtBalance.wadMul(assetPriceWad);
            }
        }

        if (totalCollateralBase == 0) {
            return (0, 0, 0, 0, 0, type(uint256).max);
        }

        ltv = 7500; // 75% default LTV
        currentLiquidationThreshold = 8000; // 80% default
        availableBorrowsBase = totalCollateralBase.wadMul(ltv).wadDiv(10000) - totalDebtBase;

        if (totalDebtBase == 0) {
            healthFactor = type(uint256).max;
        } else {
            healthFactor = totalCollateralBase
                .wadMul(currentLiquidationThreshold)
                .wadDiv(10000)
                .wadDiv(totalDebtBase);
        }
    }

    /**
     * @notice Returns the configuration of the reserve
     */
    function getConfiguration(
        address asset
    ) external view override returns (ReserveConfigurationMap memory) {
        return reserves[asset].configuration;
    }

    /**
     * @notice Returns the normalized income per unit of asset
     */
    function getReserveNormalizedIncome(
        address asset
    ) external view override returns (uint256) {
        return _getNormalizedIncome(reserves[asset]);
    }

    /**
     * @notice Returns the normalized variable debt per unit of asset
     */
    function getReserveNormalizedVariableDebt(
        address asset
    ) external view override returns (uint256) {
        return _getNormalizedVariableDebt(reserves[asset]);
    }

    /**
     * @notice Internal function to update interest rates
     */
    function _updateInterestRates(
        address asset,
        DataTypes.ReserveData storage reserve,
        uint256 liquidityAdded,
        uint256 liquidityTaken
    ) internal {
        uint256 totalVariableDebt = IDebtToken(reserve.variableDebtTokenAddress)
            .scaledTotalSupply()
            .rayMul(_getNormalizedVariableDebt(reserve));

        uint256 totalLiquidity = IAToken(reserve.aTokenAddress)
            .scaledTotalSupply()
            .rayMul(_getNormalizedIncome(reserve));

        (
            uint256 newLiquidityRate,
            uint256 newStableBorrowRate,
            uint256 newVariableBorrowRate
        ) = IInterestRateStrategy(reserve.interestRateStrategyAddress).calculateInterestRates(
                asset,
                liquidityAdded,
                liquidityTaken,
                0,
                totalVariableDebt,
                0,
                reserve.configuration.getReserveFactor()
            );

        reserve.currentLiquidityRate = uint128(newLiquidityRate);
        reserve.currentVariableBorrowRate = uint128(newVariableBorrowRate);

        uint256 cumulatedLiquidityInterest = MathUtils.calculateLinearInterest(
            newLiquidityRate,
            reserve.lastUpdateTimestamp
        );
        reserve.liquidityIndex = uint128(
            cumulatedLiquidityInterest.rayMul(reserve.liquidityIndex)
        );

        uint256 cumulatedVariableBorrowInterest = MathUtils.calculateCompoundedInterest(
            newVariableBorrowRate,
            reserve.lastUpdateTimestamp
        );
        reserve.variableBorrowIndex = uint128(
            cumulatedVariableBorrowInterest.rayMul(reserve.variableBorrowIndex)
        );

        reserve.lastUpdateTimestamp = uint40(block.timestamp);
    }

    /**
     * @notice Internal function to get normalized income
     */
    function _getNormalizedIncome(
        DataTypes.ReserveData storage reserve
    ) internal view returns (uint256) {
        uint256 cumulatedLiquidityInterest = MathUtils.calculateLinearInterest(
            reserve.currentLiquidityRate,
            reserve.lastUpdateTimestamp
        );
        return cumulatedLiquidityInterest.rayMul(reserve.liquidityIndex);
    }

    /**
     * @notice Internal function to get normalized variable debt
     */
    function _getNormalizedVariableDebt(
        DataTypes.ReserveData storage reserve
    ) internal view returns (uint256) {
        uint256 cumulatedVariableBorrowInterest = MathUtils.calculateCompoundedInterest(
            reserve.currentVariableBorrowRate,
            reserve.lastUpdateTimestamp
        );
        return cumulatedVariableBorrowInterest.rayMul(reserve.variableBorrowIndex);
    }

    /**
     * @notice Pauses the pool
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpauses the pool
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Sets the price oracle
     */
    function setPriceOracle(address _priceOracle) external onlyOwner {
        priceOracle = _priceOracle;
    }
}
