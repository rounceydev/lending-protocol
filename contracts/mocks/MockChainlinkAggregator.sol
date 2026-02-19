// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MockChainlinkAggregator
 * @notice Mock Chainlink price feed aggregator for testing
 */
contract MockChainlinkAggregator {
    int256 private _latestAnswer;
    uint256 private _updatedAt;
    uint8 private _decimals;

    constructor(int256 initialAnswer, uint8 decimals_) {
        _latestAnswer = initialAnswer;
        _decimals = decimals_;
        _updatedAt = block.timestamp;
    }

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (1, _latestAnswer, _updatedAt, _updatedAt, 1);
    }

    function latestAnswer() external view returns (int256) {
        return _latestAnswer;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function updateAnswer(int256 newAnswer) external {
        _latestAnswer = newAnswer;
        _updatedAt = block.timestamp;
    }
}
