// SPDX-License-Identifier: bsl-1.1

pragma solidity ^0.8.10;

import "./interfaces/ISingularityPool.sol";
import "./interfaces/ISingularityFactory.sol";
import "./interfaces/ISingularityERC20.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IOracle.sol";
import "./interfaces/IWrappedNative.sol";
import "./utils/SafeERC20.sol";

import "hardhat/console.sol";

contract SingularityRouter {
    using SafeERC20 for IERC20;

    address public immutable factory;
    address public immutable WETH;
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

    function poolFor(address token) public view returns (address pool) {
        pool = ISingularityFactory(factory).getPool(token);
        require(pool != address(0), "SingularityRouter: POOL_DOES_NOT_EXIST");
    }

    function getTokenPrice(address token) public view returns (uint tokenPrice) {
        address oracle = ISingularityFactory(factory).oracle();
        (tokenPrice, ) = IOracle(oracle).getPriceUSD(token);
        require(tokenPrice != 0, "SingularityRouter: INVALID_ORACLE_PRICE");
    }


    // function getAmountOut(uint amountIn, address[2] memory path) public view override returns (uint amountOut) {
    //     require(amountIn != 0, "SingularityRouter: INSUFFICIENT_INPUT_AMOUNT");
    //     address pair = poolFor(path[0], path[1]);
    //     require(pair != address(0), "SingularityRouter: PAIR_DOES_NOT_EXIST");
    //     uint fee = SingularityPool(pair).fee();
    //     uint amountInWithFee = amountIn * (FEE_MULTIPLIER - fee) / FEE_MULTIPLIER;
    //     (uint _token0Price, uint _token1Price) = getPairPrices(path[0], path[1]);
    //     (uint _reserve0, uint _reserve1,) = SingularityPool(pair).getReserves();
    //     (uint _decimals0, uint _decimals1) = SingularityPool(pair).getDecimals();
    //     uint A = get_amplitude(path[0], path[1]);
    //     uint L = get_L(_reserve0 * _token0Price / (_decimals0 * PRICE_MULTIPLIER), _reserve1 * _token1Price / (_decimals1 * PRICE_MULTIPLIER), A);
    //     uint x;
    //     uint y;
    //     if (path[0] == SingularityPool(pair).token0()) {
    //         x = (_reserve0 + amountInWithFee) * _token0Price / (_decimals0 * PRICE_MULTIPLIER);
    //         y = _reserve1 * _token1Price / (_decimals1 * PRICE_MULTIPLIER);
    //         amountOut = get_y_prime(x, y, A, L) * _decimals1 * PRICE_MULTIPLIER / _token1Price;
    //     } else {
    //         x = (_reserve1 + amountInWithFee) * _token1Price / (_decimals1 * PRICE_MULTIPLIER);
    //         y = _reserve0 * _token0Price / (_decimals0 * PRICE_MULTIPLIER);
    //         amountOut = get_y_prime(x, y, A, L) * _decimals0 * PRICE_MULTIPLIER / _token0Price;
    //     }
    // }

    // function getAmountIn(uint amountOut, address[2] memory path) public view override returns (uint amountIn) {
    //     require(amountOut != 0, "SingularityRouter: INSUFFICIENT_OUTPUT_AMOUNT");
    //     address pair = poolFor(path[0], path[1]);
    //     require(pair != address(0), "SingularityRouter: PAIR_DOES_NOT_EXIST");
    //     (uint _token0Price, uint _token1Price) = getPairPrices(path[0], path[1]);
    //     (uint _reserve0, uint _reserve1,) = SingularityPool(pair).getReserves();
    //     (uint _decimals0, uint _decimals1) = SingularityPool(pair).getDecimals();
    //     uint A = get_amplitude(path[0], path[1]);
    //     uint L = get_L(_reserve0 * _token0Price / (_decimals0 * PRICE_MULTIPLIER), _reserve1 * _token1Price / (_decimals1 * PRICE_MULTIPLIER), A);
    //     uint x;
    //     uint y;
    //     if (path[0] == SingularityPool(pair).token0()) {
    //         x = _reserve0 * _token0Price / (_decimals0 * PRICE_MULTIPLIER);
    //         y = (_reserve1 - amountOut) * _token1Price / (_decimals1 * PRICE_MULTIPLIER);
    //         amountIn = get_x_prime(x, y, A, L) * _decimals0 * PRICE_MULTIPLIER / _token0Price;
    //     } else {
    //         x = _reserve1 * _token1Price / (_decimals1 * PRICE_MULTIPLIER);
    //         y = (_reserve0 - amountOut) * _token0Price / (_decimals0 * PRICE_MULTIPLIER);
    //         amountIn = get_x_prime(x, y, A, L) * _decimals1 * PRICE_MULTIPLIER / _token1Price;
    //     }
    //     uint fee = SingularityPool(pair).fee();
    //     amountIn = amountIn * FEE_MULTIPLIER / (FEE_MULTIPLIER - fee) + 1;
    // }

    // function getAmountsOut(uint amountIn, address[] calldata path) public view override returns (uint[] memory amounts) {
    //     require(path.length >= 2, "SingularityRouter: INVALID_PATH");
    //     amounts = new uint[](path.length);
    //     amounts[0] = amountIn;
    //     for (uint i; i < path.length - 1; i++) {
    //         amounts[i + 1] = getAmountOut(amounts[i], [path[i], path[i+1]]);
    //     }
    // }

    // function getAmountsIn(uint amountOut, address[] calldata path) public view override returns (uint[] memory amounts) {
    //     require(path.length >= 2, "SingularityRouter: INVALID_PATH");
    //     amounts = new uint[](path.length);
    //     amounts[amounts.length - 1] = amountOut;
    //     for (uint i = path.length - 1; i != 0; i--) {
    //         amounts[i - 1] = getAmountIn(amounts[i], [path[i - 1], path[i]]);
    //     }
    // }

    function swap(address[] calldata path, uint amountIn, address to) external {
        IERC20(path[0]).safeTransferFrom(msg.sender, address(this), amountIn);
        _swap(path, amountIn, to);
    }


    // function swapExactTokensForTokens(
    //     address[] calldata path, 
    //     uint amountIn, 
    //     uint minAmountOut, 
    //     address to, 
    //     uint deadline
    // ) external override ensure(deadline) returns (uint[] memory amounts) {
    //     amounts = getAmountsOut(amountIn, path);
    //     require(amounts[amounts.length - 1] >= minAmountOut, "SingularityRouter: INSUFFICIENT_OUTPUT_AMOUNT");
    //     IERC20(path[0]).safeTransferFrom(msg.sender, poolFor(path[0], path[1]), amounts[0]);
    //     _swap(amounts, path, to);
    // }

    // function swapTokensForExactTokens(
    //     address[] calldata path, 
    //     uint amountOut, 
    //     uint maxAmountIn, 
    //     address to, 
    //     uint deadline
    // ) external override ensure(deadline) returns (uint[] memory amounts) {
    //     amounts = getAmountsIn(amountOut, path);
    //     require(amounts[0] <= maxAmountIn, "SingularityRouter: INSUFFICIENT_OUTPUT_AMOUNT");
    //     IERC20(path[0]).safeTransferFrom(msg.sender, poolFor(path[0], path[1]), amounts[0]);
    //     _swap(amounts, path, to);
    // }

    // function swapExactETHForTokens(
    //     address[] calldata path, 
    //     uint amountIn, 
    //     uint minAmountOut, 
    //     address to, 
    //     uint deadline
    // ) external payable override ensure(deadline) returns (uint[] memory amounts) {
    //     require(path[0] == WETH, "SingularityRouter: INVALID_PATH");
    //     amounts = getAmountsOut(amountIn, path);
    //     require(amounts[amounts.length - 1] >= minAmountOut, "SingularityRouter: INSUFFICIENT_OUTPUT_AMOUNT");
    //     IWrappedNative(WETH).deposit{value: amountIn}();
    //     IERC20(WETH).safeTransfer(poolFor(path[0], path[1]), amounts[0]);
    //     _swap(amounts, path, to);
    // }

    // function swapTokensForExactETH(
    //     address[] calldata path, 
    //     uint amountOut, 
    //     uint maxAmountIn, 
    //     address to, 
    //     uint deadline
    // ) external override ensure(deadline) returns (uint[] memory amounts) {
    //     require(path[path.length - 1] == WETH, "SingularityRouter: INVALID_PATH");
    //     amounts = getAmountsIn(amountOut, path);
    //     require(amounts[0] <= maxAmountIn, "SingularityRouter: INSUFFICIENT_OUTPUT_AMOUNT");
    //     _swap(amounts, path, address(this));
    //     IWrappedNative(WETH).deposit{value: amountOut}();
    //     _safeTransferETH(to, amountOut);
    // }

    // function swapExactTokensForETH(
    //     address[] calldata path, 
    //     uint amountIn, 
    //     uint minAmountOut, 
    //     address to, 
    //     uint deadline
    // ) external override ensure(deadline) returns (uint[] memory amounts) {
    //     require(path[path.length - 1] == WETH, "SingularityRouter: INVALID_PATH");
    //     amounts = getAmountsOut(amountIn, path);
    //     require(amounts[amounts.length - 1] >= minAmountOut, "SingularityRouter: INSUFFICIENT_OUTPUT_AMOUNT");
    //     _swap(amounts, path, address(this));
    //     IWrappedNative(WETH).deposit{value: amounts[amounts.length - 1]}();
    //     _safeTransferETH(to, amounts[amounts.length - 1]);
    // }

    // function swapETHForExactTokens(
    //     address[] calldata path, 
    //     uint amountOut, 
    //     uint maxAmountIn, 
    //     address to, 
    //     uint deadline
    // ) external payable override ensure(deadline) returns (uint[] memory amounts) {
    //     require(path[0] == WETH, "SingularityRouter: INVALID_PATH");
    //     amounts = getAmountsIn(amountOut, path);
    //     require(amounts[0] <= maxAmountIn, "SingularityRouter: INSUFFICIENT_OUTPUT_AMOUNT");
    //     IWrappedNative(WETH).deposit{value: amounts[0] }();
    //     _swap(amounts, path, to);
    //     if (msg.value > amounts[0]) _safeTransferETH(msg.sender, msg.value - amounts[0]);
    // }
    function _swap(address[] memory path, uint amountIn, address to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            address inPool = poolFor(path[i]);
            IERC20(path[i]).safeIncreaseAllowance(inPool, amountIn);
            uint amountOut = ISingularityPool(inPool).swapIn(amountIn);
            address outPool = poolFor(path[i + 1]);
            address to = i < path.length - 2 ? address(this) : to;
            amountOut = ISingularityPool(outPool).swapOut(amountOut, to);
        }
    }

    // function _swap(uint[] memory amounts, address[] memory path, address _to) internal virtual {
    //     for (uint i; i < path.length - 1; i++) {
    //         (address input, address output) = (path[i], path[i + 1]);
    //         (address token0,) = sortTokens(input, output);
    //         uint amountOut = amounts[i + 1];
    //         (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
    //         address to = i < path.length - 2 ? poolFor(output, path[i + 2]) : _to;
    //         SingularityPool(poolFor(input, output)).swap(amount0Out, amount1Out, to, new bytes(0));
    //     }
    // }

    // function _safeTransferETH(address to, uint value) internal {
    //     (bool success,) = to.call{value:value}(new bytes(0));
    //     require(success, "SingularityRouter: ETH_TRANSFER_FAILED");
    // }
}