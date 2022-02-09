pragma solidity ^0.8.11;

interface ISingularityFactory {
    function name() external view returns (string memory);

    function admin() external view returns (address);
    function oracle() external view returns (address);
    function feeTo() external view returns (address);
    function router() external view returns (address);

    function allPools(uint) external view returns (address pool);
    function getPool(address token) external view returns (address pool);
    function pausers(address pauser) external view returns (bool allowed);
    function allPoolsLength() external view returns (uint);

    function createPool(address token, bool isStablecoin, string calldata poolName, string calldata poolSymbol, uint baseFee) external returns (address pool);

    function setAdmin(address _admin) external;
    function setOracle(address _oracle) external;
    function setFeeTo(address _feeTo) external;
    function setRouter(address _router) external;
    
    function collectFees() external;
    function setDepositCaps(address[] calldata pools, uint[] calldata caps) external;
    function setBaseFees(address[] calldata pools, uint[] calldata baseFees) external;
    function setPaused(address[] calldata pools, bool[] calldata paused) external;
}
