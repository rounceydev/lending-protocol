// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../interfaces/IInterestRateStrategy.sol";
import "../../libraries/WadRayMath.sol";

/**
 * @title DefaultReserveInterestRateStrategy
 * @notice Calculates interest rates based on utilization rate
 * @dev Implements optimal utilization model with base rate, slope1, and slope2
 */
contract DefaultReserveInterestRateStrategy is IInterestRateStrategy {
    using WadRayMath for uint256;

    uint256 public immutable OPTIMAL_UTILIZATION_RATE;
    uint256 public immutable BASE_VARIABLE_BORROW_RATE;
    uint256 public immutable SLOPE1;
    uint256 public immutable SLOPE2;
    uint256 public immutable STABLE_RATE_SLOPE1;
    uint256 public immutable STABLE_RATE_SLOPE2;

    constructor(
        uint256 optimalUtilizationRate,
        uint256 baseVariableBorrowRate,
        uint256 slope1,
        uint256 slope2,
        uint256 stableRateSlope1,
        uint256 stableRateSlope2
    ) {
        OPTIMAL_UTILIZATION_RATE = optimalUtilizationRate;
        BASE_VARIABLE_BORROW_RATE = baseVariableBorrowRate;
        SLOPE1 = slope1;
        SLOPE2 = slope2;
        STABLE_RATE_SLOPE1 = stableRateSlope1;
        STABLE_RATE_SLOPE2 = stableRateSlope2;
    }

    /**
     * @notice Calculates the interest rates depending on the reserve's state and configurations
     */
    function calculateInterestRates(
        address,
        uint256 liquidityAdded,
        uint256 liquidityTaken,
        uint256 totalStableDebt,
        uint256 totalVariableDebt,
        uint256,
        uint256 reserveFactor
    ) external view override returns (uint256, uint256, uint256) {
        // Calculate total liquidity (simplified - in production would use actual reserve balance)
        uint256 totalLiquidity = totalStableDebt + totalVariableDebt + liquidityAdded - liquidityTaken;
        
        if (totalLiquidity == 0) {
            return (0, 0, BASE_VARIABLE_BORROW_RATE);
        }

        uint256 utilizationRate = (totalVariableDebt + totalStableDebt).wadDiv(totalLiquidity);

        uint256 currentVariableBorrowRate;
        uint256 currentStableBorrowRate;

        if (utilizationRate > OPTIMAL_UTILIZATION_RATE) {
            uint256 excessUtilizationRateRatio = (utilizationRate - OPTIMAL_UTILIZATION_RATE)
                .wadDiv(WadRayMath.WAD - OPTIMAL_UTILIZATION_RATE);
            
            currentVariableBorrowRate =
                BASE_VARIABLE_BORROW_RATE +
                SLOPE1 +
                (excessUtilizationRateRatio.wadMul(SLOPE2));
            
            currentStableBorrowRate =
                BASE_VARIABLE_BORROW_RATE +
                STABLE_RATE_SLOPE1 +
                (excessUtilizationRateRatio.wadMul(STABLE_RATE_SLOPE2));
        } else {
            currentVariableBorrowRate =
                BASE_VARIABLE_BORROW_RATE +
                (utilizationRate.wadDiv(OPTIMAL_UTILIZATION_RATE).wadMul(SLOPE1));
            
            currentStableBorrowRate =
                BASE_VARIABLE_BORROW_RATE +
                (utilizationRate.wadDiv(OPTIMAL_UTILIZATION_RATE).wadMul(STABLE_RATE_SLOPE1));
        }

        uint256 totalBorrows = totalStableDebt + totalVariableDebt;
        uint256 weightedBorrowRate = 0;
        if (totalBorrows > 0) {
            weightedBorrowRate =
                (totalStableDebt.wadMul(currentStableBorrowRate) +
                    totalVariableDebt.wadMul(currentVariableBorrowRate))
                    .wadDiv(totalBorrows);
        }

        uint256 currentLiquidityRate = weightedBorrowRate
            .wadMul(utilizationRate)
            .wadMul(WadRayMath.WAD - reserveFactor.wadDiv(10000));

        return (
            currentLiquidityRate,
            currentStableBorrowRate,
            currentVariableBorrowRate
        );
    }
}
