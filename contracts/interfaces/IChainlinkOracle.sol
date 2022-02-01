pragma solidity ^0.8.10;

interface IChainlinkOracle {
    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80);
}