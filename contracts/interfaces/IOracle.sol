pragma solidity ^0.8.11;

interface IOracle {
    function getPriceUSD(address token) external view returns (uint, uint);
}