// SPDX-License-Identifier: bsl-1.1

pragma solidity ^0.8.11;

import "./interfaces/ISingularityRouter.sol";
import "./interfaces/ISingularityPool.sol";
import "./interfaces/ISingularityFactory.sol";
import "./interfaces/ISingularityERC20.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IOracle.sol";
import "./interfaces/IWETH.sol";
import "./utils/SafeERC20.sol";

import "hardhat/console.sol";

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

    function getAmountOut(uint amountIn, address[2] memory path) public view override returns (uint amountOut) {
        require(amountIn != 0, "SingularityRouter: INSUFFICIENT_INPUT_AMOUNT");
        address inPool = poolFor(path[0]);
        (uint lockedFee, uint adminFee, uint lpFee) = ISingularityPool(inPool).getFees(amountIn);
        amountIn -= lockedFee + adminFee + lpFee;
        amountOut = ISingularityPool(inPool).amountToValue(amountIn);

        address outPool = poolFor(path[1]);
        amountOut = ISingularityPool(outPool).valueToAmount(amountOut);
        (uint assets, uint liabilities) = ISingularityPool(outPool).getAssetsAndLiabilities();
        uint penalty = ISingularityPool(outPool).calculatePenalty(amountOut, assets - amountOut, liabilities);
        amountOut -= penalty;
        (lockedFee, adminFee, lpFee) = ISingularityPool(outPool).getFees(amountOut);
        amountOut -= lockedFee + adminFee + lpFee;
    }

    function getAmountsOut(uint amountIn, address[] calldata path) public view override returns (uint[] memory amounts) {
        require(path.length >= 2, "SingularityRouter: INVALID_PATH");
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        for (uint i; i < path.length - 1; i++) {
            amounts[i + 1] = getAmountOut(amounts[i], [path[i], path[i+1]]);
        }
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
        IERC20(path[0]).safeTransferFrom(msg.sender, address(this), amountIn);
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
        IWETH(WETH).deposit{value: amountIn}();
        _swap(amounts, path, to);
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
        IWETH(WETH).deposit{value: amounts[amounts.length - 1]}();
        _safeTransferETH(to, amounts[amounts.length - 1]);
    }

    function _swap(uint[] memory amounts, address[] memory path, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            address inPool = poolFor(path[i]);
            IERC20(path[i]).safeIncreaseAllowance(inPool, amounts[i]);
            uint amountOut = ISingularityPool(inPool).swapIn(amounts[i]);
            address outPool = poolFor(path[i + 1]);
            address to = i < path.length - 2 ? address(this) : _to;
            ISingularityPool(outPool).swapOut(amountOut, to);
        }
    }

    function _safeTransferETH(address to, uint value) internal {
        (bool success,) = to.call{value:value}(new bytes(0));
        require(success, "SingularityRouter: ETH_TRANSFER_FAILED");
    }
}