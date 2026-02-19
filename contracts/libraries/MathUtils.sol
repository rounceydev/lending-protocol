// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./WadRayMath.sol";

/**
 * @title MathUtils library
 * @notice Provides functions to perform mathematical operations
 */
library MathUtils {
    using WadRayMath for uint256;

    /**
     * @dev Calculates the compounded interest during the timeDelta, in ray
     * @param rate The interest rate, in ray
     * @param lastUpdateTimestamp The timestamp of the last update
     * @return The interest rate compounded during the timeDelta, in ray
     */
    function calculateCompoundedInterest(
        uint256 rate,
        uint256 lastUpdateTimestamp
    ) internal view returns (uint256) {
        uint256 timeDelta = block.timestamp - lastUpdateTimestamp;

        if (timeDelta == 0) {
            return WadRayMath.RAY;
        }

        // Simplified compounded interest calculation
        // For small rates and time periods, we use linear approximation
        // Full implementation would use exponential: (1 + rate)^timeDelta
        uint256 ratePerSecond = rate / 365 days;
        
        // For simplicity, use linear interest for now
        // In production, implement proper exponential calculation
        return WadRayMath.RAY + (ratePerSecond * timeDelta);
    }

    /**
     * @dev Calculates the linear interest during the timeDelta, in ray
     * @param rate The interest rate, in ray
     * @param lastUpdateTimestamp The timestamp of the last update
     * @return The interest rate compounded during the timeDelta, in ray
     */
    function calculateLinearInterest(
        uint256 rate,
        uint256 lastUpdateTimestamp
    ) internal view returns (uint256) {
        uint256 timeDelta = block.timestamp - lastUpdateTimestamp;
        return (rate * timeDelta) / 365 days + WadRayMath.RAY;
    }
}
