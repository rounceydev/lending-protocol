// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IPool
 * @notice Main entry point for user interactions with the lending protocol
 */
interface IPool {
    /**
     * @notice Supplies an `amount` of underlying asset into the reserve
     * @param asset The address of the underlying asset to supply
     * @param amount The amount to be supplied
     * @param onBehalfOf The address that will receive the aTokens
     * @param referralCode Unused, kept for compatibility
     */
    function supply(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;

    /**
     * @notice Withdraws an `amount` of underlying asset from the reserve
     * @param asset The address of the underlying asset to withdraw
     * @param amount The amount to be withdrawn
     * @param to The address that will receive the underlying
     */
    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external;

    /**
     * @notice Allows users to borrow a specific `amount` of the reserve underlying asset
     * @param asset The address of the underlying asset to borrow
     * @param amount The amount to be borrowed
     * @param interestRateMode The interest rate mode: 1 for Stable, 2 for Variable
     * @param referralCode Unused, kept for compatibility
     * @param onBehalfOf The address that will receive the debt
     */
    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external;

    /**
     * @notice Repays a borrowed `amount` on a specific reserve
     * @param asset The address of the borrowed underlying asset
     * @param amount The amount to repay
     * @param rateMode The interest rate mode: 1 for Stable, 2 for Variable
     * @param onBehalfOf The address that will receive the debt reduction
     */
    function repay(
        address asset,
        uint256 amount,
        uint256 rateMode,
        address onBehalfOf
    ) external returns (uint256);

    /**
     * @notice Allows smartcontracts to access the liquidity of the pool within one transaction
     * @param receiverAddress The address of the contract receiving the funds
     * @param assets The addresses of the assets being flash-borrowed
     * @param amounts The amounts of the assets being flash-borrowed
     * @param modes Types of the debt to open if the flash loan is not returned
     * @param onBehalfOf The address that will receive the debt
     * @param params Variadic packed params to pass to the receiver
     * @param referralCode Unused, kept for compatibility
     */
    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata modes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external;

    /**
     * @notice Allows liquidators to repay a borrow on behalf of a borrower and receive collateral
     * @param collateralAsset The address of the collateral asset
     * @param debtAsset The address of the borrowed asset
     * @param user The address of the borrower
     * @param debtToCover The amount of debt to repay
     * @param receiveAToken True if the liquidator wants to receive aTokens, false for underlying
     */
    function liquidationCall(
        address collateralAsset,
        address debtAsset,
        address user,
        uint256 debtToCover,
        bool receiveAToken
    ) external;

    /**
     * @notice Returns the user account data across all the reserves
     * @param user The address of the user
     * @return totalCollateralBase The total collateral of the user in the base currency
     * @return totalDebtBase The total debt of the user in the base currency
     * @return availableBorrowsBase The borrowing power left of the user in the base currency
     * @return currentLiquidationThreshold The liquidation threshold of the user
     * @return ltv The loan to value of the user
     * @return healthFactor The current health factor of the user
     */
    function getUserAccountData(
        address user
    )
        external
        view
        returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        );

    /**
     * @notice Returns the configuration of the reserve
     * @param asset The address of the underlying asset of the reserve
     * @return The configuration data
     */
    function getConfiguration(
        address asset
    ) external view returns (ReserveConfigurationMap memory);

    /**
     * @notice Returns the normalized income per unit of asset
     * @param asset The address of the underlying asset of the reserve
     * @return The reserve's normalized income
     */
    function getReserveNormalizedIncome(
        address asset
    ) external view returns (uint256);

    /**
     * @notice Returns the normalized variable debt per unit of asset
     * @param asset The address of the underlying asset of the reserve
     * @return The reserve normalized variable debt
     */
    function getReserveNormalizedVariableDebt(
        address asset
    ) external view returns (uint256);
}

/**
 * @title ReserveConfigurationMap
 * @notice Structure containing the configuration of a reserve
 */
struct ReserveConfigurationMap {
    uint256 data;
}
