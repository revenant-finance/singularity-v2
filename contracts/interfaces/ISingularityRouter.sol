pragma solidity ^0.8.11;

interface ISingularityRouter {
    function factory() external returns (address);
    function WETH() external returns (address);

    function poolFor(address token) external view returns (address pool);
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
        uint amountIn, 
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
}