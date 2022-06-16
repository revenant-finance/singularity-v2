// SPDX-License-Identifier: No License

pragma solidity ^0.8.15;

interface ISingularityFactory {
    struct PoolParams {
        address factory;
        address token;
        bool isStablecoin;
        uint256 baseFee;
    }

    event PoolCreated(address indexed token, bool isStablecoin, uint256 baseFee, address pool, uint256 index);

    function tranche() external view returns (string memory);

    function admin() external view returns (address);

    function oracle() external view returns (address);

    function feeTo() external view returns (address);

    function router() external view returns (address);

    function protocolFeeShare() external view returns (uint256);

    function oracleSens() external view returns (uint256);

    function poolParams()
        external
        view
        returns (
            address factory,
            address token,
            bool isStablecoin,
            uint256 baseFee
        );

    function getPool(address token) external view returns (address pool);

    function allPools(uint256) external view returns (address pool);

    function allPoolsLength() external view returns (uint256);

    function poolCodeHash() external pure returns (bytes32);

    function createPool(
        address token,
        bool isStablecoin,
        uint256 baseFee
    ) external returns (address pool);

    function setAdmin(address _admin) external;

    function setOracle(address _oracle) external;

    function setFeeTo(address _feeTo) external;

    function setRouter(address _router) external;

    function setProtocolFeeShare(uint256 _protocolFeeShare) external;

    function setOracleSens(uint256 _oracleSens) external;

    function collectFees() external;

    function setDepositCaps(address[] calldata tokens, uint256[] calldata caps) external;

    function setBaseFees(address[] calldata tokens, uint256[] calldata baseFees) external;

    function setPaused(address[] calldata tokens, bool[] calldata states) external;

    function setPausedForAll(bool state) external;
}
