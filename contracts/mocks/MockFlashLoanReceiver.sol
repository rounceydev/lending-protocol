// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../interfaces/IFlashLoanReceiver.sol";

/**
 * @title MockFlashLoanReceiver
 * @notice Mock flash loan receiver for testing
 */
contract MockFlashLoanReceiver is IFlashLoanReceiver {
    using SafeERC20 for IERC20;

    bool public shouldFail;
    uint256 public receivedAmount;

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address,
        bytes calldata
    ) external override returns (bool) {
        if (shouldFail) {
            return false;
        }

        // Store received amount for testing
        if (assets.length > 0) {
            receivedAmount = amounts[0];
        }

        // Repay flash loan + premium
        for (uint256 i = 0; i < assets.length; i++) {
            uint256 amountOwed = amounts[i] + premiums[i];
            IERC20(assets[i]).safeTransfer(msg.sender, amountOwed);
        }

        return true;
    }

    function setShouldFail(bool _shouldFail) external {
        shouldFail = _shouldFail;
    }
}
