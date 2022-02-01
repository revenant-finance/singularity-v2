pragma solidity ^0.8.10;

interface ISingularityPair {
    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function decimals0() external view returns (uint);
    function decimals1() external view returns (uint);
    function standardDecimals() external view returns (uint8);
    function token0Fees() external view returns (uint);
    function token1Fees() external view returns (uint);

    function getReserves() external view returns (uint reserve0, uint reserve1, uint32 blockTimestampLast);
    function getTokens() external view returns (address token0, address token1);
    function getTokenPrices() external view returns (uint token0Price, uint token1Price);
    function getDecimals() external view returns (uint decimals0, uint decimals1);
    function getFees() external view returns (uint token0Fees, uint token1Fees);
    
    function amplitude() external view returns (uint);
    function fee() external view returns (uint);
    function FEE_MULTIPLIER() external view returns (uint);
    function PRICE_MULTIPLIER() external view returns (uint);
    function collectFees() external;
    function setAmplitude(uint newA) external;
    function setFee(uint newFee) external;

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function sync() external;

    function initialize(address token0, address token1, uint A, uint fee) external;
}
