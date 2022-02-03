// SPDX-License-Identifier: bsl-1.1

pragma solidity ^0.8.10;

import "./SingularityPool.sol";
import "./interfaces/ISingularityFactory.sol";
import "./interfaces/ISingularityPool.sol";

contract SingularityFactory is ISingularityFactory {
    address public override admin;
    address public override oracle;
    address public override feeTo;

    address[] public override allPools;
    mapping(address => address) public override getPool;
    mapping(address => bool) public override pausers;

    event PoolCreated(address indexed token, address indexed pool, uint index);

    modifier onlyAdmin() {
        require(msg.sender == admin, "SingularityFactory: FORBIDDEN");
        _;
    }

    constructor (address _admin, address _oracle) {
        require(_admin != address(0), "SingularityFactory: ADMIN_IS_0");
        require(_oracle != address(0), "SingularityFactory: ORACLE_IS_0");
        admin = _admin;
        oracle = _oracle;
        pausers[msg.sender] = true;
    }

    function allPoolsLength() external override view returns (uint) {
        return allPools.length;
    }

    function createPool(address token, string calldata name, string calldata symbol) external override onlyAdmin returns (address pool) {
        require(token != address(0), "SingularityFactory: ZERO_ADDRESS");
        require(getPool[token] == address(0), "SingularityFactory: POOL_EXISTS");
        bytes memory bytecode = type(SingularityPool).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token));
        assembly {
            pool := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        ISingularityPool(pool).initialize(token, name, symbol);
        getPool[token] = pool;
        allPools.push(pool);
        emit PoolCreated(token, pool, allPools.length);
    }

    function setAdmin(address _admin) external override onlyAdmin {
        admin = _admin;
    }

    function setOracle(address _oracle) external override onlyAdmin {
        oracle = _oracle;
    }

    function setFeeTo(address _feeTo) external override onlyAdmin {
        feeTo = _feeTo;
    }

    function collectFees(address[] calldata pools) external override onlyAdmin {
        require(feeTo != address(0), "SingularityFactory: FEES_NOT_ENABLED");
        for (uint i; i < pools.length; i++) {
            ISingularityPool(pools[i]).collectFees();
        }
    }

    function setPaused(address[] calldata pools, bool[] calldata paused) external {
        require(pausers[msg.sender], "SingularityFactory: FORBIDDEN");
        require(pools.length == paused.length, "SingularityFactory: NOT_SAME_LENGTH");
        for (uint i; i < pools.length; i++) {
            ISingularityPool(pools[i]).setPaused(paused[i]);
        }
    }
}