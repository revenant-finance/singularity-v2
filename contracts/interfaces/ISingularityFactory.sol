pragma solidity ^0.8.10;

interface ISingularityFactory {
    function admin() external view returns (address);
    function oracle() external view returns (address);
    function feeTo() external view returns (address);

    function getPool(address tokenA, address tokenB) external view returns (address pool);
    function allPools(uint) external view returns (address pool);
    function allPoolsLength() external view returns (uint);

    function createPool(address token) external returns (address pool);

    function setAdmin(address) external;
    function setOracle(address) external;
    function setFeeTo(address newFeeTo) external;
    function collectFees(address[] calldata pairs) external;
}
