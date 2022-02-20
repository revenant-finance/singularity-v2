// SPDX-License-Identifier: No License

pragma solidity ^0.8.11;

interface ISingularityRouter {
    function factory() external returns (address);
    function WETH() external returns (address);

    function poolFor(address token) external view returns (address pool);
    function getAssetsAndLiabilities(address token) external view returns (uint assets, uint liabilities);
    function getAmountOut(uint amountIn, address tokenIn, address tokenOut) external view returns (uint amountOut);

    function swapExactTokensForTokens(
        address tokenIn,
        address tokenOut, 
        uint amountIn, 
        uint minAmountOut, 
        address to, 
        uint deadline
    ) external returns (uint amountOut);

    function swapExactETHForTokens(
        address tokenIn,
        address tokenOut, 
        uint minAmountOut, 
        address to, 
        uint deadline
    ) external payable returns (uint amountOut);

    function swapExactTokensForETH(
        address tokenIn,
        address tokenOut, 
        uint amountIn, 
        uint minAmountOut, 
        address to, 
        uint deadline
    ) external returns (uint amountOut);

    function addLiquidity(
        address token,
        uint amount,
        uint minLiquidity,
        address to,
        uint deadline
    ) external returns (uint liquidity);

    function addLiquidityETH(
        uint minLiquidity,
        address to,
        uint deadline
    ) external payable returns (uint liquidity);

    function removeLiquidity(
        address token,
        uint liquidity,
        uint amountMin,
        address to,
        uint deadline
    ) external returns (uint amount);

    function removeLiquidityETH(
        uint liquidity,
        uint amountMin,
        address to,
        uint deadline
    ) external payable returns (uint amount);

    function removeLiquidityWithPermit(
        address token,
        uint liquidity,
        uint minLiquidity,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amount);

    function removeLiquidityETHWithPermit(
        uint liquidity,
        uint amountMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amount);
}