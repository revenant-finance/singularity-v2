// SPDX-License-Identifier: No License

pragma solidity ^0.8.11;

import "./interfaces/ISingularityRouter.sol";
import "./interfaces/ISingularityFactory.sol";
import "./interfaces/ISingularityPool.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IWETH.sol";
import "./utils/SafeERC20.sol";

/**
 * @title Singularity Router
 * @author Revenant Labs
 */
contract SingularityRouter is ISingularityRouter {
    using SafeERC20 for IERC20;

    address public immutable override factory;
    address public immutable override WETH;
    uint private constant MULTIPLIER = 10**18;

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, "SingularityRouter: EXPIRED");
        _;
    }

    constructor(address _factory, address _WETH) {
        factory = _factory;
        WETH = _WETH;
    }

    receive() external payable {
        assert(msg.sender == WETH);
    }

    function poolFor(address token) public view override returns (address pool) {
        pool = ISingularityFactory(factory).getPool(token);
        require(pool != address(0), "SingularityRouter: POOL_DOES_NOT_EXIST");
    }

    function getAssetsAndLiabilities(address token) public view override returns (uint assets, uint liabilities) {
        address pool = poolFor(token);
        (assets, liabilities) = ISingularityPool(pool).getAssetsAndLiabilities();
    }

    function getAmountOut(uint amountIn, address tokenIn, address tokenOut) public view override returns (uint amountOut) {
        require(amountIn != 0, "SingularityRouter: INSUFFICIENT_INPUT_AMOUNT");
        address poolIn = poolFor(tokenIn);
        (uint assets, uint liabilities) = getAssetsAndLiabilities(tokenIn);
        uint slippageIn = ISingularityPool(poolIn).getSlippage(amountIn, assets + amountIn, liabilities);
        amountIn += slippageIn;
        (uint lockedFee, uint adminFee, uint lpFee) = ISingularityPool(poolIn).getTradingFees(amountIn);
        amountIn -= lockedFee + adminFee + lpFee;
        uint swapInAmountOut = ISingularityPool(poolIn).getAmountToUSD(amountIn);

        address poolOut = poolFor(tokenOut);
        uint swapOutAmountOut = ISingularityPool(poolOut).getUSDToAmount(swapInAmountOut);
        (assets, liabilities) = getAssetsAndLiabilities(tokenOut);
        uint slippageOut = ISingularityPool(poolOut).getSlippage(swapOutAmountOut, assets - swapOutAmountOut, liabilities);
        swapOutAmountOut -= slippageOut;
        (lockedFee, adminFee, lpFee) = ISingularityPool(poolOut).getTradingFees(swapOutAmountOut);
        amountOut = swapOutAmountOut - lockedFee - adminFee - lpFee;
    }

    function swapExactTokensForTokens(
        address tokenIn,
        address tokenOut, 
        uint amountIn, 
        uint minAmountOut, 
        address to, 
        uint deadline
    ) external override ensure(deadline) returns (uint amountOut) {
        amountOut = getAmountOut(amountIn, tokenIn, tokenOut);
        require(amountOut >= minAmountOut, "SingularityRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        _swap(amountIn, tokenIn, tokenOut, to);
    }

    function swapExactETHForTokens(
        address tokenIn,
        address tokenOut, 
        uint minAmountOut, 
        address to, 
        uint deadline
    ) external payable override ensure(deadline) returns (uint amountOut) {
        require(tokenIn == WETH, "SingularityRouter: INVALID_PATH");
        amountOut = getAmountOut(msg.value, tokenIn, tokenOut);
        require(amountOut >= minAmountOut, "SingularityRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        IWETH(WETH).deposit{value: msg.value}();
        _swap(msg.value, tokenIn, tokenOut, to);
    }

    function swapExactTokensForETH(
        address tokenIn,
        address tokenOut, 
        uint amountIn, 
        uint minAmountOut, 
        address to, 
        uint deadline
    ) external override ensure(deadline) returns (uint amountOut) {
        require(tokenOut == WETH, "SingularityRouter: INVALID_PATH");
        amountOut = getAmountOut(amountIn, tokenIn, tokenOut);
        require(amountOut >= minAmountOut, "SingularityRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        _swap(amountIn, tokenIn, tokenOut, address(this));
        IWETH(WETH).withdraw(amountOut);
        _safeTransferETH(to, amountOut);
    }

    function _swap(uint amountIn, address tokenIn, address tokenOut, address to) internal virtual {
        address poolIn = poolFor(tokenIn);
        IERC20(tokenIn).safeIncreaseAllowance(poolIn, amountIn);
        uint amountOut = ISingularityPool(poolIn).swapIn(amountIn);
        address poolOut = poolFor(tokenOut);
        ISingularityPool(poolOut).swapOut(amountOut, to);
    }

    function addLiquidity(
        address token,
        uint amount,
        uint minLiquidity,
        address to,
        uint deadline
    ) public override ensure(deadline) returns (uint liquidity) {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        liquidity = _addLiquidity(token, amount, minLiquidity, to);
    }

    function addLiquidityETH(
        uint minLiquidity,
        address to,
        uint deadline
    ) external payable override ensure(deadline) returns (uint liquidity) {
        IWETH(WETH).deposit{value: msg.value}();
        liquidity = _addLiquidity(WETH, msg.value, minLiquidity, to);
    }

    function _addLiquidity(
        address token,
        uint amount,
        uint minLiquidity,
        address to
    ) internal returns (uint liquidity) {
        address pool = poolFor(token);
        IERC20(token).safeIncreaseAllowance(pool, amount);
        liquidity = ISingularityPool(pool).deposit(amount, to);
        require(liquidity >= minLiquidity, "SingularityRouter: INSUFFICIENT_LIQUIDITY_AMOUNT");
    }

    function removeLiquidity(
        address token,
        uint liquidity,
        uint amountMin,
        address to,
        uint deadline
    ) public override ensure(deadline) returns (uint amount) {
        address pool = poolFor(token);
        IERC20(pool).safeTransferFrom(msg.sender, address(this), liquidity);
        amount = ISingularityPool(pool).withdraw(liquidity, to);
        require(amount >= amountMin, "SingularityRouter: INSUFFICIENT_TOKEN_AMOUNT");
    }

    function removeLiquidityETH(
        uint liquidity,
        uint amountMin,
        address to,
        uint deadline
    ) public payable override ensure(deadline) returns (uint amount) {
        amount = removeLiquidity(WETH, liquidity, amountMin, address(this), deadline);
        IWETH(WETH).withdraw(amount);
        _safeTransferETH(to, amount);
    }

    function removeLiquidityWithPermit(
        address token,
        uint liquidity,
        uint amountMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external override returns (uint amount) {
        address pool = poolFor(token);
        uint value = approveMax ? type(uint).max : liquidity;
        ISingularityPool(pool).permit(msg.sender, address(this), value, deadline, v, r, s);
        amount = removeLiquidity(token, liquidity, amountMin, to, deadline);
    }

    function removeLiquidityETHWithPermit(
        uint liquidity,
        uint amountMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external override returns (uint amount) {
        address pool = poolFor(WETH);
        uint value = approveMax ? type(uint).max : liquidity;
        ISingularityPool(pool).permit(msg.sender, address(this), value, deadline, v, r, s);
        amount = removeLiquidityETH(liquidity, amountMin, to, deadline);
    }

    function _safeTransferETH(address to, uint amount) internal {
        bool callStatus;

        assembly {
            // Transfer the ETH and store if it succeeded or not.
            callStatus := call(gas(), to, amount, 0, 0, 0, 0)
        }

        require(callStatus, "ETH_TRANSFER_FAILED");
    }
}