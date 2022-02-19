// SPDX-License-Identifier: No License

pragma solidity ^0.8.11;

interface ISingularityOracle {
    function getPriceUSD(address token) external view returns (uint, uint);
}