// SPDX-License-Identifier: bsl-1.1

pragma solidity ^0.8.10;

import "./libraries/Math.sol";
import "./interfaces/ISingularityRouter.sol";
import "./interfaces/ISingularityPair.sol";
import "./interfaces/ISingularityFactory.sol";
import "./interfaces/ISingularityERC20.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IOracle.sol";
import "./interfaces/IWrappedNative.sol";
import "./utils/SafeERC20.sol";

contract SingularityRouter is ISingularityRouter {
    using SafeERC20 for IERC20;

    address public immutable override factory;
    address public immutable override WETH;
    uint public constant override PRICE_MULTIPLIER = 10**8;
    uint public constant override FEE_MULTIPLIER = 10**18;

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

    function sortTokens(address tokenA, address tokenB) public pure override returns (address token0, address token1) {
        require(tokenA != tokenB, "SingularityRouter: IDENTICAL_ADDRESSES");
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "SingularityRouter: ZERO_ADDRESS");
    }

    function get_L(uint x, uint y, uint A) public pure override returns (uint L) {
        uint numerator = 2 * Math.sqrt(A * x * y) * (x + y);
        uint denominator = Math.sqrt(A * x * y) + Math.sqrt((A + 8) * x * y + 4 * x**2 + 4 * y**2);
        L = numerator / denominator;
    }

    function get_lp(uint x, uint y, uint A) public pure override returns (uint liquidity) {
        return get_L(x, y, A) * 10**9;
    }

    function get_x_prime(uint x, uint y, uint A, uint L) public pure override returns (uint x_prime) {
        uint denominator = 2 * A * y;
        uint sqrt = Math.sqrt(A**2 * y**4 + 2 * A * L**3 * y + A * (A + 2) * L**2 * y**2 + L**4 - 2 * A**2 * L * y**3);
        uint numerator = sqrt + A * L * y + L**2 - 2 * A * x * y - A * y**2;
        x_prime = numerator / denominator;
    }

    function get_y_prime(uint x, uint y, uint A, uint L) public pure override returns (uint y_prime) {
        uint denominator = 2 * A * x;
        uint sqrt = Math.sqrt(A**2 * x**4 + 2 * A * L**3 * x + A * (A + 2) * L**2 * x**2 + L**4 - 2 * A**2 * L * x**3);
        uint numerator = 2 * A * x * y + A * x**2 - A * L * x - L**2 - sqrt;
        y_prime = numerator / denominator;
    }

    function get_amplitude(address tokenA, address tokenB) public view override returns (uint amplitude) {
        address pair = pairFor(tokenA, tokenB);
        amplitude = ISingularityPair(pair).amplitude();
    }

    function pairFor(address tokenA, address tokenB) public view override returns (address pair) {
        require(tokenA != tokenB, "SingularityRouter: IDENTICAL_ADDRESSES");
        pair = ISingularityFactory(factory).getPair(tokenA, tokenB);
        require(pair != address(0), "SingularityRouter: PAIR_DOES_NOT_EXIST");
    }

    function getReserves(address tokenA, address tokenB) public view override returns (uint reserveA, uint reserveB) {
        (address token0,) = sortTokens(tokenA, tokenB);
        (uint reserve0, uint reserve1,) = ISingularityPair(pairFor(tokenA, tokenB)).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    function getPairPrices(address tokenA, address tokenB) public view override returns (uint token0Price, uint token1Price) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        address oracle = ISingularityFactory(factory).oracle();
        token0Price = IOracle(oracle).getPriceUSD(token0);
        token1Price = IOracle(oracle).getPriceUSD(token1);
        require(token0Price != 0 && token1Price != 0, "SingularityRouter: INVALID_ORACLE");
    }

    function getAmountOut(uint amountIn, address[2] memory path) public view override returns (uint amountOut) {
        require(amountIn != 0, "SingularityRouter: INSUFFICIENT_INPUT_AMOUNT");
        address pair = pairFor(path[0], path[1]);
        require(pair != address(0), "SingularityRouter: PAIR_DOES_NOT_EXIST");
        uint fee = ISingularityPair(pair).fee();
        uint amountInWithFee = amountIn * (FEE_MULTIPLIER - fee) / FEE_MULTIPLIER;
        (uint _token0Price, uint _token1Price) = getPairPrices(path[0], path[1]);
        (uint _reserve0, uint _reserve1,) = ISingularityPair(pair).getReserves();
        (uint _decimals0, uint _decimals1) = ISingularityPair(pair).getDecimals();
        uint A = get_amplitude(path[0], path[1]);
        uint L = get_L(_reserve0 * _token0Price / (_decimals0 * PRICE_MULTIPLIER), _reserve1 * _token1Price / (_decimals1 * PRICE_MULTIPLIER), A);
        uint x;
        uint y;
        if (path[0] == ISingularityPair(pair).token0()) {
            x = (_reserve0 + amountInWithFee) * _token0Price / (_decimals0 * PRICE_MULTIPLIER);
            y = _reserve1 * _token1Price / (_decimals1 * PRICE_MULTIPLIER);
            amountOut = get_y_prime(x, y, A, L) * _decimals1 * PRICE_MULTIPLIER / _token1Price;
        } else {
            x = (_reserve1 + amountInWithFee) * _token1Price / (_decimals1 * PRICE_MULTIPLIER);
            y = _reserve0 * _token0Price / (_decimals0 * PRICE_MULTIPLIER);
            amountOut = get_y_prime(x, y, A, L) * _decimals0 * PRICE_MULTIPLIER / _token0Price;
        }
    }

    function getAmountIn(uint amountOut, address[2] memory path) public view override returns (uint amountIn) {
        require(amountOut != 0, "SingularityRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        address pair = pairFor(path[0], path[1]);
        require(pair != address(0), "SingularityRouter: PAIR_DOES_NOT_EXIST");
        (uint _token0Price, uint _token1Price) = getPairPrices(path[0], path[1]);
        (uint _reserve0, uint _reserve1,) = ISingularityPair(pair).getReserves();
        (uint _decimals0, uint _decimals1) = ISingularityPair(pair).getDecimals();
        uint A = get_amplitude(path[0], path[1]);
        uint L = get_L(_reserve0 * _token0Price / (_decimals0 * PRICE_MULTIPLIER), _reserve1 * _token1Price / (_decimals1 * PRICE_MULTIPLIER), A);
        uint x;
        uint y;
        if (path[0] == ISingularityPair(pair).token0()) {
            x = _reserve0 * _token0Price / (_decimals0 * PRICE_MULTIPLIER);
            y = (_reserve1 - amountOut) * _token1Price / (_decimals1 * PRICE_MULTIPLIER);
            amountIn = get_x_prime(x, y, A, L) * _decimals0 * PRICE_MULTIPLIER / _token0Price;
        } else {
            x = _reserve1 * _token1Price / (_decimals1 * PRICE_MULTIPLIER);
            y = (_reserve0 - amountOut) * _token0Price / (_decimals0 * PRICE_MULTIPLIER);
            amountIn = get_x_prime(x, y, A, L) * _decimals1 * PRICE_MULTIPLIER / _token1Price;
        }
        uint fee = ISingularityPair(pair).fee();
        amountIn = amountIn * FEE_MULTIPLIER / (FEE_MULTIPLIER - fee) + 1;
    }

    function getAmountsOut(uint amountIn, address[] calldata path) public view override returns (uint[] memory amounts) {
        require(path.length >= 2, "SingularityRouter: INVALID_PATH");
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        for (uint i; i < path.length - 1; i++) {
            amounts[i + 1] = getAmountOut(amounts[i], [path[i], path[i+1]]);
        }
    }

    function getAmountsIn(uint amountOut, address[] calldata path) public view override returns (uint[] memory amounts) {
        require(path.length >= 2, "SingularityRouter: INVALID_PATH");
        amounts = new uint[](path.length);
        amounts[amounts.length - 1] = amountOut;
        for (uint i = path.length - 1; i != 0; i--) {
            amounts[i - 1] = getAmountIn(amounts[i], [path[i - 1], path[i]]);
        }
    }

    function getAddLiquidity(
        address tokenA,
        address tokenB,
        uint amountA,
        uint amountB
    ) external view override returns (uint liquidity) {
        address pair = pairFor(tokenA, tokenB);
        (address token0,) = sortTokens(tokenA, tokenB);
        (uint amount0, uint amount1) = token0 == tokenA ? (amountA, amountB) : (amountB, amountA);
        (uint decimals0, uint decimals1) = ISingularityPair(pair).getDecimals();
        (uint token0Price, uint token1Price) = getPairPrices(tokenA, tokenB);
        uint A = get_amplitude(tokenA, tokenB);
        if (ISingularityERC20(pair).totalSupply() == 0) {
            require(amount0 != 0 && amount1 != 0, "SingularityRouter: INSUFFICIENT_SEED_LIQUIDITY");
            uint amount1Adjusted = amount1 * token1Price / (decimals1 * PRICE_MULTIPLIER);
            uint amount0Adjusted = amount0 * token0Price / (decimals0 * PRICE_MULTIPLIER);
            liquidity = get_lp(amount0Adjusted, amount1Adjusted, A) - 10**3;
        } else {
            (uint _reserve0, uint _reserve1,) = ISingularityPair(pair).getReserves();
            uint balance0Adjusted = (amount0 + _reserve0) * token0Price / (decimals0 * PRICE_MULTIPLIER);
            uint balance1Adjusted = (amount1 + _reserve1) * token1Price / (decimals1 * PRICE_MULTIPLIER);
            uint reserve0Adjusted = _reserve0 * token0Price / (decimals0 * PRICE_MULTIPLIER);
            uint reserve1Adjusted = _reserve1 * token1Price / (decimals1 * PRICE_MULTIPLIER);
            liquidity = get_lp(balance0Adjusted, balance1Adjusted, A) - get_lp(reserve0Adjusted, reserve1Adjusted, A);
        }
    }

    function addLiquidity(
        address tokenA, 
        address tokenB, 
        uint amountA, 
        uint amountB, 
        uint minLiquidity, 
        address to,
        uint deadline
    ) external override ensure(deadline) returns (uint liquidity) {
        address pair = pairFor(tokenA, tokenB);
        IERC20(tokenA).safeTransferFrom(msg.sender, pair, amountA);
        IERC20(tokenB).safeTransferFrom(msg.sender, pair, amountB);
        liquidity = ISingularityPair(pair).mint(to);
        require(liquidity >= minLiquidity, "SingularityRouter: INSUFFICIENT_OUTPUT_AMOUNT");
    }

    function addLiquidityETH(
        address token, 
        uint amountToken,
        uint minLiquidity, 
        address to,
        uint deadline
    ) external payable override ensure(deadline) returns (uint liquidity) {
        address pair = pairFor(token, WETH);
        IERC20(token).safeTransferFrom(msg.sender, pair, amountToken);
        IWrappedNative(WETH).deposit{value: msg.value}();
        IERC20(WETH).safeTransfer(pair, msg.value);
        liquidity = ISingularityPair(pair).mint(to);
        require(liquidity >= minLiquidity, "SingularityRouter: INSUFFICIENT_OUTPUT_AMOUNT");
    }

    function getRemoveLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity
    ) external view override returns (uint amountA, uint amountB) {
        address pair = pairFor(tokenA, tokenB);
        uint totalSupply = ISingularityERC20(pair).totalSupply();
        uint balanceA = IERC20(tokenA).balanceOf(pair);
        uint balanceB = IERC20(tokenB).balanceOf(pair);
        (uint token0Fees, uint token1Fees) = ISingularityPair(pair).getFees();
        (address token0,) = sortTokens(tokenA, tokenB);
        (uint tokenAFees, uint tokenBFees) = token0 == tokenA ? (token0Fees, token1Fees) : (token1Fees, token0Fees);
        amountA = liquidity * (balanceA - tokenAFees) / totalSupply;
        amountB = liquidity * (balanceB - tokenBFees) / totalSupply;
    }

    function removeLiquidity(
        address tokenA, 
        address tokenB, 
        uint liquidity, 
        uint minAmountA, 
        uint minAmountB, 
        address to,
        uint deadline
    ) public override ensure(deadline) returns (uint amountA, uint amountB) {
        address pair = pairFor(tokenA, tokenB);
        ISingularityERC20(pair).transferFrom(msg.sender, pair, liquidity);
        (uint amount0, uint amount1) = ISingularityPair(pair).burn(to);
        (address token0,) = sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= minAmountA, "SingularityRouter: INSUFFICIENT_A_AMOUNT");
        require(amountB >= minAmountB, "SingularityRouter: INSUFFICIENT_B_AMOUNT");
    }

    function removeLiquidityETH(
        address token, 
        uint liquidity, 
        uint minAmountToken, 
        uint minAmountNative, 
        address to,
        uint deadline
    ) public override ensure(deadline) returns (uint amountToken, uint amountNative) {
        (amountToken, amountNative) = removeLiquidity(token, WETH, liquidity, minAmountToken, minAmountNative, address(this), deadline);
        IERC20(token).safeTransfer(to, amountToken);
        IWrappedNative(WETH).withdraw(amountNative);
        _safeTransferETH(to, amountNative);
    }

    function removeLiquidityWithPermit(
        address tokenA, 
        address tokenB, 
        uint liquidity, 
        uint minAmountA, 
        uint minAmountB, 
        address to, 
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external override ensure(deadline) returns (uint amountA, uint amountB) {
        uint value = approveMax ? type(uint).max : liquidity;
        ISingularityERC20(pairFor(tokenA, tokenB)).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountA, amountB) = removeLiquidity(tokenA, tokenB, liquidity, minAmountA, minAmountB, to, deadline);
    }

    function removeLiquidityETHWithPermit(
        address token, 
        uint liquidity, 
        uint minAmountToken, 
        uint minAmountNative, 
        address to, 
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external override ensure(deadline) returns (uint amountToken, uint amountNative) {
        address pair = pairFor(token, WETH);
        uint value = approveMax ? type(uint).max : liquidity;
        ISingularityERC20(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountToken, amountNative) = removeLiquidityETH(token, liquidity, minAmountToken, minAmountNative, to, deadline);
    }

    function swapExactTokensForTokens(
        address[] calldata path, 
        uint amountIn, 
        uint minAmountOut, 
        address to, 
        uint deadline
    ) external override ensure(deadline) returns (uint[] memory amounts) {
        amounts = getAmountsOut(amountIn, path);
        require(amounts[amounts.length - 1] >= minAmountOut, "SingularityRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        IERC20(path[0]).safeTransferFrom(msg.sender, pairFor(path[0], path[1]), amounts[0]);
        _swap(amounts, path, to);
    }

    function swapTokensForExactTokens(
        address[] calldata path, 
        uint amountOut, 
        uint maxAmountIn, 
        address to, 
        uint deadline
    ) external override ensure(deadline) returns (uint[] memory amounts) {
        amounts = getAmountsIn(amountOut, path);
        require(amounts[0] <= maxAmountIn, "SingularityRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        IERC20(path[0]).safeTransferFrom(msg.sender, pairFor(path[0], path[1]), amounts[0]);
        _swap(amounts, path, to);
    }

    function swapExactETHForTokens(
        address[] calldata path, 
        uint amountIn, 
        uint minAmountOut, 
        address to, 
        uint deadline
    ) external payable override ensure(deadline) returns (uint[] memory amounts) {
        require(path[0] == WETH, "SingularityRouter: INVALID_PATH");
        amounts = getAmountsOut(amountIn, path);
        require(amounts[amounts.length - 1] >= minAmountOut, "SingularityRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        IWrappedNative(WETH).deposit{value: amountIn}();
        IERC20(WETH).safeTransfer(pairFor(path[0], path[1]), amounts[0]);
        _swap(amounts, path, to);
    }

    function swapTokensForExactETH(
        address[] calldata path, 
        uint amountOut, 
        uint maxAmountIn, 
        address to, 
        uint deadline
    ) external override ensure(deadline) returns (uint[] memory amounts) {
        require(path[path.length - 1] == WETH, "SingularityRouter: INVALID_PATH");
        amounts = getAmountsIn(amountOut, path);
        require(amounts[0] <= maxAmountIn, "SingularityRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        _swap(amounts, path, address(this));
        IWrappedNative(WETH).deposit{value: amountOut}();
        _safeTransferETH(to, amountOut);
    }

    function swapExactTokensForETH(
        address[] calldata path, 
        uint amountIn, 
        uint minAmountOut, 
        address to, 
        uint deadline
    ) external override ensure(deadline) returns (uint[] memory amounts) {
        require(path[path.length - 1] == WETH, "SingularityRouter: INVALID_PATH");
        amounts = getAmountsOut(amountIn, path);
        require(amounts[amounts.length - 1] >= minAmountOut, "SingularityRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        _swap(amounts, path, address(this));
        IWrappedNative(WETH).deposit{value: amounts[amounts.length - 1]}();
        _safeTransferETH(to, amounts[amounts.length - 1]);
    }

    function swapETHForExactTokens(
        address[] calldata path, 
        uint amountOut, 
        uint maxAmountIn, 
        address to, 
        uint deadline
    ) external payable override ensure(deadline) returns (uint[] memory amounts) {
        require(path[0] == WETH, "SingularityRouter: INVALID_PATH");
        amounts = getAmountsIn(amountOut, path);
        require(amounts[0] <= maxAmountIn, "SingularityRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        IWrappedNative(WETH).deposit{value: amounts[0] }();
        _swap(amounts, path, to);
        if (msg.value > amounts[0]) _safeTransferETH(msg.sender, msg.value - amounts[0]);
    }

    function _swap(uint[] memory amounts, address[] memory path, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            address to = i < path.length - 2 ? pairFor(output, path[i + 2]) : _to;
            ISingularityPair(pairFor(input, output)).swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    function _safeTransferETH(address to, uint value) internal {
        (bool success,) = to.call{value:value}(new bytes(0));
        require(success, "SingularityRouter: ETH_TRANSFER_FAILED");
    }
}