// SPDX-License-Identifier: No License

pragma solidity ^0.8.11;

import "./interfaces/ISingularityFactory.sol";
import "./SingularityPool.sol";

/**
 * @title Singularity Factory
 * @author Revenant Labs
 */
 contract SingularityFactory is ISingularityFactory {
    string public override tranche;
    address public override admin;
    address public override oracle;
    address public override feeTo;
    address public override router;
    
    mapping(address => address) public override getPool;
    address[] public override allPools;

    event PoolCreated(address indexed token, address indexed pool, uint index);

    modifier onlyAdmin() {
        require(msg.sender == admin, "SingularityFactory: FORBIDDEN");
        _;
    }

    constructor(string memory _tranche, address _admin, address _oracle, address _feeTo) {
        require(bytes(_tranche).length > 0, "SingularityFactory: TRANCHE_IS_EMPTY");
        require(_admin != address(0), "SingularityFactory: ADMIN_IS_0");
        require(_oracle != address(0), "SingularityFactory: ORACLE_IS_0");
        require(_feeTo != address(0), "SingularityFactory: FEE_TO_IS_0");
        tranche = _tranche;
        admin = _admin;
        oracle = _oracle;
        feeTo = _feeTo;
    }

    function allPoolsLength() external override view returns (uint) {
        return allPools.length;
    }

    /* ========== ADMIN FUNCTIONS ========== */

    /// @notice Creates pool for token
    /// @dev Only one pool can exist per token
    /// @param token The pool token
    /// @param isStablecoin If token is a stablecoin (bypasses oracle fee)
    /// @param baseFee The base fee for the pool
    /// @return pool The address of the pool created
    function createPool(
        address token, 
        bool isStablecoin, 
        uint baseFee
    ) external override onlyAdmin returns (address pool) {
        require(router != address(0), "SingularityFactory: ROUTER_IS_0");
        require(token != address(0), "SingularityFactory: ZERO_ADDRESS");
        require(getPool[token] == address(0), "SingularityFactory: POOL_EXISTS");
        require(baseFee > 0, "SingularityFactory: FEE_IS_0");
        bytes memory bytecode = type(SingularityPool).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token));
        assembly {
            pool := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        SingularityPool(pool).initialize(token, isStablecoin, baseFee);
        getPool[token] = pool;
        allPools.push(pool);
        emit PoolCreated(token, pool, allPools.length);
    }

    function setAdmin(address _admin) external override onlyAdmin {
        require(_admin != address(0), "SingularityFactory: ZERO_ADDRESS");
        admin = _admin;
    }

    function setOracle(address _oracle) external override onlyAdmin {
        require(_oracle != address(0), "SingularityFactory: ZERO_ADDRESS");
        oracle = _oracle;
    }

    function setFeeTo(address _feeTo) external override onlyAdmin {
        require(_feeTo != address(0), "SingularityFactory: ZERO_ADDRESS");
        feeTo = _feeTo;
    }

    function setRouter(address _router) external override onlyAdmin {
        require(_router != address(0), "SingularityFactory: ZERO_ADDRESS");
        router = _router;
    }

    function collectFees() external override onlyAdmin {
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
            require(baseFees[i] > 0, "SingularityFactory: FEE_IS_0");
            ISingularityPool(pools[i]).setBaseFee(baseFees[i]);
        }
    }

    function setPaused(address[] calldata pools, bool[] calldata paused) external override onlyAdmin {
        require(pools.length == paused.length, "SingularityFactory: NOT_SAME_LENGTH");
        for (uint i; i < pools.length; i++) {
            ISingularityPool(pools[i]).setPaused(paused[i]);
        }
    }

    function setPausedForAll(bool paused) external override onlyAdmin {
        for (uint i; i < allPools.length; i++) {
            ISingularityPool(allPools[i]).setPaused(paused);
        }
    }
}