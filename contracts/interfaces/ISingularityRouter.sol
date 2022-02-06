pragma solidity ^0.8.11;

interface ISingularityRouter {
    function factory() external returns (address);
    function WETH() external returns (address);

    function poolFor(address token) external view returns (address pool);
    function getAssetsAndLiabilities(address token) external view returns (uint assets, uint liabilities);
    function getAmountOut(uint amountIn, address[2] memory path) external view returns (uint amountOut);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);

    function swapExactTokensForTokens(
        address[] calldata path, 
        uint amountIn, 
        uint minAmountOut, 
        address to, 
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapExactETHForTokens(
        address[] calldata path, 
        uint minAmountOut, 
        address to, 
        uint deadline
    ) external payable returns (uint[] memory amounts);

    function swapExactTokensForETH(
        address[] calldata path, 
        uint amountIn, 
        uint minAmountOut, 
        address to, 
        uint deadline
    ) external returns (uint[] memory amounts);

    function addLiquidity(
        address token,
        uint amount,
        address to,
        uint deadline
    ) external returns (uint);

    function addLiquidityETH(
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
}