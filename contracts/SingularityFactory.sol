// SPDX-License-Identifier: No License

pragma solidity ^0.8.11;

import "./interfaces/ISingularityFactory.sol";
import "./SingularityPool.sol";

/**
 * @title Singularity Factory
 * @author Revenant Labs
 */
 contract SingularityFactory is ISingularityFactory {
    struct PoolParams {
        address token;
        bool isStablecoin;
        uint256 baseFee;
    }
    string public override tranche;
    address public override admin;
    address public override oracle;
    address public override feeTo;
    address public override router;

    PoolParams public override poolParams;
    
    mapping(address => address) public override getPool;
    address[] public override allPools;

    event PoolCreated(address indexed token, bool isStablecoin, uint256 baseFee, address pool, uint256);

    modifier onlyAdmin() {
        require(msg.sender == admin, "SingularityFactory: NOT_ADMIN");
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

    function allPoolsLength() external view override returns (uint256) {
        return allPools.length;
    }

    function poolCodeHash() external pure override returns (bytes32) {
        return keccak256(type(SingularityPool).creationCode);
    }

    /* ========== ADMIN FUNCTIONS ========== */

    /// @notice Creates pool for token
    /// @dev Only one pool can exist per token
    /// @param token The pool token
    /// @param isStablecoin If token is a stablecoin (bypasses oracle penalty)
    /// @param baseFee The base fee for the pool
    /// @return pool The address of the pool created
    function createPool(
        address token, 
        bool isStablecoin, 
        uint256 baseFee
    ) external override onlyAdmin returns (address pool) {
        require(router != address(0), "SingularityFactory: ROUTER_IS_0");
        require(token != address(0), "SingularityFactory: ZERO_ADDRESS");
        require(getPool[token] == address(0), "SingularityFactory: POOL_EXISTS");
        require(baseFee > 0, "SingularityFactory: FEE_IS_0");
        poolParams = PoolParams({token: token, isStablecoin: isStablecoin, baseFee: baseFee});
        pool = address(new SingularityPool{salt: keccak256(abi.encodePacked(token))}());
        delete poolParams;
        getPool[token] = pool;
        allPools.push(pool);
        emit PoolCreated(token, isStablecoin, baseFee, pool, allPools.length);
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
        for (uint256 i; i < allPools.length; i++) {
            ISingularityPool(allPools[i]).collectFees();
        }
    }

    function setDepositCaps(address[] calldata tokens, uint256[] calldata caps) external override onlyAdmin {
        require(tokens.length == caps.length, "SingularityFactory: NOT_SAME_LENGTH");
        for (uint256 i; i < tokens.length; i++) {
            address pool = getPool[tokens[i]];
            ISingularityPool(pool).setDepositCap(caps[i]);
        }
    }

    function setBaseFees(address[] calldata tokens, uint256[] calldata baseFees) external override onlyAdmin {
        require(tokens.length == baseFees.length, "SingularityFactory: NOT_SAME_LENGTH");
        for (uint256 i; i < tokens.length; i++) {
            require(baseFees[i] > 0, "SingularityFactory: BASE_FEE_IS_0");
            address pool = getPool[tokens[i]];
            ISingularityPool(pool).setBaseFee(baseFees[i]);
        }
    }

    function setPaused(address[] calldata tokens, bool[] calldata states) external override onlyAdmin {
        require(tokens.length == states.length, "SingularityFactory: NOT_SAME_LENGTH");
        for (uint256 i; i < tokens.length; i++) {
            address pool = getPool[tokens[i]];
            ISingularityPool(pool).setPaused(states[i]);
        }
    }

    function setPausedForAll(bool state) external override onlyAdmin {
        for (uint256 i; i < allPools.length; i++) {
            ISingularityPool(allPools[i]).setPaused(state);
        }
    }
}