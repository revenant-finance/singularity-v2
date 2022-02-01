pragma solidity ^0.8.10;

interface ISingularityRouter {
    function factory() external returns (address);
    function WETH() external returns (address);
    function PRICE_MULTIPLIER() external returns (uint);
    function FEE_MULTIPLIER() external returns (uint);

    function sortTokens(address tokenA, address tokenB) external pure returns (address token0, address token1);
    function get_L(uint x, uint y, uint A) external pure returns (uint L);
    function get_lp(uint x, uint y, uint A) external pure returns (uint liquidity);
    function get_x_prime(uint x, uint y, uint A, uint L) external pure returns (uint x_prime);
    function get_y_prime(uint x, uint y, uint A, uint L) external pure returns (uint y_prime);
    function get_amplitude(address tokenA, address tokenB) external view returns (uint A);
    function pairFor(address tokenA, address tokenB) external view returns (address pair);
    function getReserves(address tokenA, address tokenB) external view returns (uint reserveA, uint reserveB);
    function getPairPrices(address tokenA, address tokenB) external view returns (uint token0Price, uint token1Price);
    function getAmountOut(uint amountIn, address[2] memory path) external view returns (uint amountOut);
    function getAmountIn(uint amountOut, address[2] memory path) external view returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);

    function getAddLiquidity(
        address tokenA,
        address tokenB,
        uint amountA,
        uint amountB
    ) external returns (uint liquidity);
    
    function addLiquidity(
        address tokenA, 
        address tokenB, 
        uint amountA, 
        uint amountB, 
        uint minLiquidity, 
        address to,
        uint deadline
    ) external returns (uint liquidity);

    function addLiquidityETH(
        address token, 
        uint amountToken,
        uint minLiquidity, 
        address to,
        uint deadline
    ) external payable returns (uint liquidity);

    function getRemoveLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity
    ) external view returns (uint amountA, uint amountB);

    function removeLiquidity(
        address tokenA, 
        address tokenB, 
        uint liquidity, 
        uint minAmountA, 
        uint minAmountB, 
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);

    function removeLiquidityETH(
        address token, 
        uint liquidity, 
        uint minAmountToken, 
        uint minAmountNative, 
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountNative);

    function removeLiquidityWithPermit(
        address tokenA, 
        address tokenB, 
        uint liquidity, 
        uint minAmountA, 
        uint minAmountB, 
        address to, 
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);

    function removeLiquidityETHWithPermit(
        address token, 
        uint liquidity, 
        uint minAmountToken, 
        uint minAmountNative, 
        address to, 
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountNative);

    function swapExactTokensForTokens(
        address[] calldata path, 
        uint amountIn, 
        uint minAmountOut, 
        address to, 
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapTokensForExactTokens(
        address[] calldata path, 
        uint amountOut, 
        uint maxAmountIn, 
        address to, 
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapExactETHForTokens(
        address[] calldata path, 
        uint amountIn, 
        uint minAmountOut, 
        address to, 
        uint deadline
    ) external payable returns (uint[] memory amounts);

    function swapTokensForExactETH(
        address[] calldata path, 
        uint amountOut, 
        uint maxAmountIn, 
        address to, 
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapExactTokensForETH(
        address[] calldata path, 
        uint amountIn, 
        uint minAmountOut, 
        address to, 
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapETHForExactTokens(
        address[] calldata path, 
        uint amountOut, 
        uint maxAmountIn, 
        address to, 
        uint deadline
    ) external payable returns (uint[] memory amounts);
}