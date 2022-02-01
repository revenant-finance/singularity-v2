// SPDX-License-Identifier: bsl-1.1

pragma solidity ^0.8.10;

import "./SingularityPair.sol";
import "./interfaces/ISingularityFactory.sol";
import "./interfaces/ISingularityPair.sol";

contract SingularityFactory is ISingularityFactory {
    address public override admin;
    address public override oracle;
    address public override feeTo;

    mapping(address => address) public override getPool;
    address[] public override allPools;

    event PoolCreated(address indexed token, address indexed pool, uint index);

    constructor (address _admin, address _oracle) {
        require(_admin != address(0), "SingularityFactory: ADMIN_IS_0");
        require(_oracle != address(0), "SingularityFactory: ORACLE_IS_0");
        admin = _admin;
        oracle = _oracle;
    }

    function allPoolsLength() external override view returns (uint) {
        return allPairs.length;
    }

    function createPool(address token) external override returns (address pool) {
        require(msg.sender == admin, "SingularityFactory: FORBIDDEN");
        require(token != address(0), "SingularityFactory: ZERO_ADDRESS");
        require(getPool[token] == address(0), "SingularityFactory: POOL_EXISTS");
        bytes memory bytecode = type(SingularityPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token));
        assembly {
            pool := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        ISingularityPair(pool).initialize(token);
        getPool[token] = pool;
        allPairs.push(pool);
        emit PairCreated(token, pool, allPairs.length);
    }

    function setAdmin(address _admin) external override {
        require(msg.sender == admin, "SingularityFactory: FORBIDDEN");
        admin = _admin;
    }

    function setOracle(address _oracle) external override {
        require(msg.sender == admin, "SingularityFactory: FORBIDDEN");
        oracle = _oracle;
    }

    function setFeeTo(address _feeTo) external override {
        require(msg.sender == admin, "SingularityFactory: FORBIDDEN");
        feeTo = _feeTo;
    }

    function collectFees(address[] calldata pairs) external override {
        require(msg.sender == admin, "SingularityFactory: FORBIDDEN");
        require(feeTo != address(0), "SingularityFactory: FEES_NOT_ENABLED");
        for (uint i; i < pairs.length; i++) {
            ISingularityPair(pairs[i]).collectFees();
        }
    }
}