pragma solidity ^0.8.10;

import "../interfaces/IOracle.sol";
import "../interfaces/IChainlinkOracle.sol";

contract TestOracle is IOracle {
    mapping(address => uint) public oracles;

    function getPriceUSD(address token) external view override returns (uint price) {
        price = oracles[token];
    }

    function setOracle(address token, uint price) external {
        oracles[token] = price;
    }
}