// SPDX-License-Identifier: No License

pragma solidity ^0.8.13;

interface IChainlinkFeed {
    function decimals() external view returns (uint8);

    function latestRoundData()
        external
        view
        returns (
            uint80,
            int256,
            uint256,
            uint256,
            uint80
        );
}
