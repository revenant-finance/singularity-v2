// SPDX-License-Identifier: No License

pragma solidity ^0.8.11;

interface ISingularityRouter {
    function factory() external returns (address);
    function WETH() external returns (address);
    function poolCodeHash() external returns (bytes32);

    function poolFor(address factory, address token) external view returns (address pool);
    function getAmountOut(uint256 amountIn, address tokenIn, address tokenOut) external view returns (uint256 amountOut);

    function swapExactTokensForTokens(
        address tokenIn,
        address tokenOut, 
        uint256 amountIn, 
        uint256 minAmountOut, 
        address to, 
        uint256 deadline
    ) external returns (uint256 amountOut);

    function swapExactETHForTokens(
        address tokenIn,
        address tokenOut, 
        uint256 minAmountOut, 
        address to, 
        uint256 deadline
    ) external payable returns (uint256 amountOut);

    function swapExactTokensForETH(
        address tokenIn,
        address tokenOut, 
        uint256 amountIn, 
        uint256 minAmountOut, 
        address to, 
        uint256 deadline
    ) external returns (uint256 amountOut);

    function addLiquidity(
        address token,
        uint256 amount,
        uint256 minLiquidity,
        address to,
        uint256 deadline
    ) external returns (uint256 liquidity);

    function addLiquidityETH(
        uint256 minLiquidity,
        address to,
        uint256 deadline
    ) external payable returns (uint256 liquidity);

    function removeLiquidity(
        address token,
        uint256 liquidity,
        uint256 amountMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amount);

    function removeLiquidityETH(
        uint256 liquidity,
        uint256 amountMin,
        address to,
        uint256 deadline
    ) external payable returns (uint256 amount);

    function removeLiquidityWithPermit(
        address token,
        uint256 liquidity,
        uint256 minLiquidity,
        address to,
        uint256 deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint256 amount);

    function removeLiquidityETHWithPermit(
        uint256 liquidity,
        uint256 amountMin,
        address to,
        uint256 deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint256 amount);
}