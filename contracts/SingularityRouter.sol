// SPDX-License-Identifier: No License

pragma solidity ^0.8.13;

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
    bytes32 public immutable override poolCodeHash;

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "SingularityRouter: EXPIRED");
        _;
    }

    constructor(address _factory, address _WETH) {
        factory = _factory;
        WETH = _WETH;
        poolCodeHash = ISingularityFactory(_factory).poolCodeHash();
    }

    receive() external payable {
        assert(msg.sender == WETH);
    }

    function poolFor(address _factory, address token) public view override returns (address pool) {
        pool = address(uint160(uint256(keccak256(abi.encodePacked(
                hex'ff',
                _factory,
                keccak256(abi.encodePacked(token)),
                poolCodeHash
        )))));
    }

    function getAmountOut(uint256 amountIn, address tokenIn, address tokenOut) public view override returns (uint256 amountOut) {
        require(amountIn != 0, "SingularityRouter: INSUFFICIENT_INPUT_AMOUNT");
        address poolIn = poolFor(factory, tokenIn);
        uint256 slippageIn = ISingularityPool(poolIn).getSlippageIn(amountIn);
        amountIn += slippageIn;
        (uint256 totalFee, , ,) = ISingularityPool(poolIn).getTradingFees(amountIn);
        require(totalFee != type(uint256).max, "SingularityRouter: STALE_ORACLE");
        amountIn -= totalFee;
        uint256 swapInAmountOut = ISingularityPool(poolIn).getAmountToUSD(amountIn);

        address poolOut = poolFor(factory, tokenOut);
        amountOut = ISingularityPool(poolOut).getUSDToAmount(swapInAmountOut);
        (totalFee, , ,) = ISingularityPool(poolOut).getTradingFees(amountOut);
        require(totalFee != type(uint256).max, "SingularityRouter: STALE_ORACLE");
        amountOut -= totalFee;
        uint256 slippageOut = ISingularityPool(poolOut).getSlippageOut(amountOut);
        amountOut -= slippageOut;
    }

    function swapExactTokensForTokens(
        address tokenIn,
        address tokenOut, 
        uint256 amountIn, 
        uint256 minAmountOut, 
        address to, 
        uint256 deadline
    ) external override ensure(deadline) returns (uint256 amountOut) {
        amountOut = getAmountOut(amountIn, tokenIn, tokenOut);
        require(amountOut >= minAmountOut, "SingularityRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        _swap(amountIn, tokenIn, tokenOut, to);
    }

    function swapExactETHForTokens(
        address tokenIn,
        address tokenOut, 
        uint256 minAmountOut, 
        address to, 
        uint256 deadline
    ) external payable override ensure(deadline) returns (uint256 amountOut) {
        require(tokenIn == WETH, "SingularityRouter: INVALID_IN_TOKEN");
        amountOut = getAmountOut(msg.value, tokenIn, tokenOut);
        require(amountOut >= minAmountOut, "SingularityRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        IWETH(WETH).deposit{value: msg.value}();
        _swap(msg.value, tokenIn, tokenOut, to);
    }

    function swapExactTokensForETH(
        address tokenIn,
        address tokenOut, 
        uint256 amountIn, 
        uint256 minAmountOut, 
        address to, 
        uint256 deadline
    ) external override ensure(deadline) returns (uint256 amountOut) {
        require(tokenOut == WETH, "SingularityRouter: INVALID_OUT_TOKEN");
        amountOut = getAmountOut(amountIn, tokenIn, tokenOut);
        require(amountOut >= minAmountOut, "SingularityRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        _swap(amountIn, tokenIn, tokenOut, address(this));
        IWETH(WETH).withdraw(amountOut);
        _safeTransferETH(to, amountOut);
    }

    function _swap(uint256 amountIn, address tokenIn, address tokenOut, address to) internal virtual {
        address poolIn = poolFor(factory, tokenIn);
        IERC20(tokenIn).safeIncreaseAllowance(poolIn, amountIn);
        uint256 amountOut = ISingularityPool(poolIn).swapIn(amountIn);
        address poolOut = poolFor(factory, tokenOut);
        ISingularityPool(poolOut).swapOut(amountOut, to);
    }

    function addLiquidity(
        address token,
        uint256 amount,
        uint256 minLiquidity,
        address to,
        uint256 deadline
    ) public override ensure(deadline) returns (uint256 liquidity) {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        liquidity = _addLiquidity(token, amount, minLiquidity, to);
    }

    function addLiquidityETH(
        uint256 minLiquidity,
        address to,
        uint256 deadline
    ) external payable override ensure(deadline) returns (uint256 liquidity) {
        IWETH(WETH).deposit{value: msg.value}();
        liquidity = _addLiquidity(WETH, msg.value, minLiquidity, to);
    }

    function _addLiquidity(
        address token,
        uint256 amount,
        uint256 minLiquidity,
        address to
    ) internal returns (uint256 liquidity) {
        address pool = poolFor(factory, token);
        IERC20(token).safeIncreaseAllowance(pool, amount);
        liquidity = ISingularityPool(pool).deposit(amount, to);
        require(liquidity >= minLiquidity, "SingularityRouter: INSUFFICIENT_LIQUIDITY_AMOUNT");
    }

    function removeLiquidity(
        address token,
        uint256 liquidity,
        uint256 amountMin,
        address to,
        uint256 deadline
    ) public override ensure(deadline) returns (uint256 amount) {
        address pool = poolFor(factory, token);
        IERC20(pool).safeTransferFrom(msg.sender, address(this), liquidity);
        amount = ISingularityPool(pool).withdraw(liquidity, to);
        require(amount >= amountMin, "SingularityRouter: INSUFFICIENT_TOKEN_AMOUNT");
    }

    function removeLiquidityETH(
        uint256 liquidity,
        uint256 amountMin,
        address to,
        uint256 deadline
    ) public payable override ensure(deadline) returns (uint256 amount) {
        amount = removeLiquidity(WETH, liquidity, amountMin, address(this), deadline);
        IWETH(WETH).withdraw(amount);
        _safeTransferETH(to, amount);
    }

    function removeLiquidityWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountMin,
        address to,
        uint256 deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external override returns (uint256 amount) {
        address pool = poolFor(factory, token);
        uint256 value = approveMax ? type(uint256).max : liquidity;
        ISingularityPool(pool).permit(msg.sender, address(this), value, deadline, v, r, s);
        amount = removeLiquidity(token, liquidity, amountMin, to, deadline);
    }

    function removeLiquidityETHWithPermit(
        uint256 liquidity,
        uint256 amountMin,
        address to,
        uint256 deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external override returns (uint256 amount) {
        address pool = poolFor(factory, WETH);
        uint256 value = approveMax ? type(uint256).max : liquidity;
        ISingularityPool(pool).permit(msg.sender, address(this), value, deadline, v, r, s);
        amount = removeLiquidityETH(liquidity, amountMin, to, deadline);
    }

    function _safeTransferETH(address to, uint256 amount) internal {
        bool callStatus;

        assembly {
            // Transfer the ETH and store if it succeeded or not.
            callStatus := call(gas(), to, amount, 0, 0, 0, 0)
        }

        require(callStatus, "SingularityRouter: ETH_TRANSFER_FAILED");
    }
}