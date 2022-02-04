pragma solidity ^0.8.10;

interface ISingularityPool {
    event Mint(address indexed sender, uint indexed amountDeposited, uint amountMinted, address indexed to);
    event Burn(address indexed sender, uint indexed amountBurned, uint amountWithdrawn, address indexed to);
    event SwapIn(
        address indexed sender,
        uint indexed amountIn,
        uint amountOut
    );
    event SwapOut(
        address indexed sender,
        uint indexed amountIn,
        uint amountOut,
        address indexed to
    );

    function paused() external view returns (bool);
    function factory() external view returns (address);
    function token() external view returns (address);

    function depositCap() external view returns (uint);
    function liabilities() external view returns (uint);
    function assets() external view returns (uint);
    function adminFees() external view returns (uint);
    function lockedFees() external view returns (uint);
    function baseFee() external view returns (uint);

    function getTokenPrice() external view returns (uint);
    function getFees(uint amount) external view returns (uint, uint, uint);
    function getPricePerShare() external view returns (uint);
    function getCollatalizationRatio() external view returns (uint);
    function calculatePenalty(uint amount, uint newAssets, uint newLiabilities) external view returns (uint);

    function mint(uint amount, address to) external returns (uint);
    function burn(uint amount, address to) external returns (uint);
    function swapIn(uint256 amountIn) external returns (uint);
    function swapOut(uint256 amountIn, address to) external returns (uint);

    function collectFees() external;
    function setDepositCap(uint newDepositCap) external;
    function setBaseFee(uint newBaseFee) external;
    function setPaused(bool paused) external;

    function initialize(address token, string calldata name, string calldata symbol, uint baseFee) external;
}
