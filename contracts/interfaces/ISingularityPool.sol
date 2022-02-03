pragma solidity ^0.8.10;

interface ISingularityPool {
    event Mint(address indexed sender, uint indexed amountDeposited, uint amountMinted, address indexed to);
    event Burn(address indexed sender, uint indexed amountBurned, uint amountWithdrawn, address indexed to);
    event Swap(
        address indexed sender,
        address indexed to
    );

    function paused() external view returns (bool);
    function factory() external view returns (address);
    function token() external view returns (address);

    function deposits() external view returns (uint);
    function debts() external view returns (uint);
    function fees() external view returns (uint);
    function depositCap() external view returns (uint);

    function getTokenPrice() external view returns (uint);
    function getPricePerShare() external view returns (uint);
    function getPercentDebt() external view returns (uint);
    function calculatePenalty(uint amount) external view returns (uint);

    function mint(uint amount, address to) external returns (uint);
    function burn(uint amount, address to) external returns (uint);
    function swap(address to) external;

    function collectFees() external;
    function setDepositCap(uint newDepositCap) external;
    function setPaused(bool paused) external;

    function initialize(address token, string calldata name, string calldata symbol) external;
}
