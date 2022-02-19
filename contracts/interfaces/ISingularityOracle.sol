// SPDX-License-Identifier: No License

pragma solidity ^0.8.11;

interface ISingularityOracle {
    function getLatestRound(address token) external view returns (uint, uint);
}