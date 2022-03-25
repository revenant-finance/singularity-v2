// SPDX-License-Identifier: No License

pragma solidity ^0.8.13;

interface ISingularityOracle {
    function getLatestRound(address token) external view returns (uint256, uint256);
    function getLatestRounds(address[] calldata tokens) external view returns (uint256[] memory prices, uint256[] memory updatedAts);
}