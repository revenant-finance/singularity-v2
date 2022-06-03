// SPDX-License-Identifier: No License

pragma solidity ^0.8.14;

import "../interfaces/IChainlinkFeed.sol";

contract TestChainlinkFeed is IChainlinkFeed {
    int256 price;
    uint256 timestamp;

    constructor (int256 _price) {
        price = _price;
        timestamp = block.timestamp;
    }

    function decimals() external pure returns (uint8) {
        return 8;
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (0, price, timestamp, timestamp, 0);
    }

    function setPrice(int256 _price) external {
        price = _price;
        timestamp = block.timestamp;
    }
}