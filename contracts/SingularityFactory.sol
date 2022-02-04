// SPDX-License-Identifier: bsl-1.1

pragma solidity ^0.8.11;

import "./SingularityPool.sol";
import "./interfaces/ISingularityFactory.sol";
import "./interfaces/ISingularityPool.sol";

contract SingularityFactory is ISingularityFactory {
    string public override name;

    address public override admin;
    address public override oracle;
    address public override feeTo;
    address public override router;

    address[] public override allPools;
    mapping(address => address) public override getPool;
    mapping(address => bool) public override pausers;

    event PoolCreated(address indexed token, address indexed pool, string name, string symbol, uint index);

    modifier onlyAdmin() {
        require(msg.sender == admin, "SingularityFactory: FORBIDDEN");
        _;
    }

    constructor(string memory _name, address _admin, address _oracle) {
        require(_admin != address(0), "SingularityFactory: ADMIN_IS_0");
        require(_oracle != address(0), "SingularityFactory: ORACLE_IS_0");
        name = _name;
        admin = _admin;
        oracle = _oracle;
        pausers[msg.sender] = true;
    }

    function allPoolsLength() external override view returns (uint) {
        return allPools.length;
    }

    /* ========== ADMIN FUNCTIONS ========== */

    function createPool(address _token, string calldata _name, string calldata _symbol, uint _baseFee) external override onlyAdmin returns (address pool) {
        require(_token != address(0), "SingularityFactory: ZERO_ADDRESS");
        require(getPool[_token] == address(0), "SingularityFactory: POOL_EXISTS");
        require(_baseFee > 0, "SingularityFactory: FEE_IS_0");
        bytes memory bytecode = type(SingularityPool).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(_token));
        assembly {
            pool := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        ISingularityPool(pool).initialize(_token, _name, _symbol, _baseFee);
        getPool[_token] = pool;
        allPools.push(pool);
        emit PoolCreated(_token, pool, _name, _symbol, allPools.length);
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

    function setRouter(address _router) external override onlyAdmin {
        router = _router;
    }

    function collectFees() external override onlyAdmin {
        require(feeTo != address(0), "SingularityFactory: FEES_NOT_ENABLED");
        for (uint i; i < allPools.length; i++) {
            ISingularityPool(allPools[i]).collectFees();
        }
    }

    function setDepositCaps(address[] calldata pools, uint[] calldata caps) external override onlyAdmin {
        require(pools.length == caps.length, "SingularityFactory: NOT_SAME_LENGTH");
        for (uint i; i < pools.length; i++) {
            ISingularityPool(pools[i]).setDepositCap(caps[i]);
        }
    }

    function setBaseFees(address[] calldata pools, uint[] calldata baseFees) external override onlyAdmin {
        require(pools.length == baseFees.length, "SingularityFactory: NOT_SAME_LENGTH");
        for (uint i; i < pools.length; i++) {
            ISingularityPool(pools[i]).setBaseFee(baseFees[i]);
        }
    }

    function setPaused(address[] calldata pools, bool[] calldata paused) external override {
        require(pausers[msg.sender], "SingularityFactory: FORBIDDEN");
        require(pools.length == paused.length, "SingularityFactory: NOT_SAME_LENGTH");
        for (uint i; i < pools.length; i++) {
            ISingularityPool(pools[i]).setPaused(paused[i]);
        }
    }
}