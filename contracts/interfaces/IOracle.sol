pragma solidity ^0.8.10;

interface IOracle {
    function getPriceUSD(address token) external view returns (uint, uint);
}