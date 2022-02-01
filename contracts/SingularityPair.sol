// SPDX-License-Identifier: bsl-1.1

pragma solidity ^0.8.10;

import "./SingularityERC20.sol";
import "./libraries/Math.sol";
import "./interfaces/ISingularityPair.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/ISingularityFactory.sol";
import "./interfaces/ISingularityCallee.sol";
import "./interfaces/IOracle.sol";
import "./utils/SafeERC20.sol";

contract SingularityPair is ISingularityPair, SingularityERC20 {
    using SafeERC20 for IERC20;
    
    address public immutable override factory;

    // V2 Vars
    address public override token;
    uint public deposits;
    uint public debts;
    uint public fees;
    uint public depositCap;
    
    uint32 private blockTimestampLast;
    
    uint public override fee;
    uint public constant MULTIPLIER = 10**18;

    uint256 private locked = 1;
    modifier lock() {
        require(locked == 1, "REENTRANCY");
        locked = 2;
        _;
        locked = 1;
    }

    function getTokenPrice() public view override returns (uint _tokenPrice) {
        _tokenPrice = IOracle(ISingularityFactory(factory).oracle()).getPriceUSD(_token);
        require(_tokenPrice != 0, "SingularityPair: INVALID_ORACLE_PRICE");
    }

    constructor() {
        factory = msg.sender;
    }

    function initialize(address _token) external override {
        require(msg.sender == factory, "SingularityPair: FORBIDDEN");
        token = _token;
    }

    function _update() private {
        blockTimestampLast = uint32(block.timestamp);
    }

    function collectFees() external override {
        require(msg.sender == factory, "SingularityPair: NOT_FACTORY");
        address feeTo = ISingularityFactory(factory).feeTo();
        IERC20(token).safeTransfer(feeTo, fees);
        fees = 0;
    }

    function setDepositCap(uint newDepositCap) external {
        require(msg.sender == factory, "SingularityPair: NOT_FACTORY");
        depositCap = newDepositCap;
    }

    function setFee(uint newFee) external override {
        require(msg.sender == factory, "SingularityPair: NOT_FACTORY");
        fee = newFee;
    }

    function getPricePerShare() external view returns (uint pricePerShare) {
        if (totalSupply == 0) {
            pricePerShare = MULTIPLIER;
        } else {
            pricePerShare = MULTIPLIER * (deposits + fees) / deposits;
        }
    }
    
    function mint(uint amount, address to) external override lock returns (uint liquidity) {
        require(amount != 0, "SingularityPair: AMOUNT_IS_0");
        require(amount + deposits <= depositCap, "SingularityPair: MINT_EXCEEDS_CAP");
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        uint amountToMint;
        if (deposits == 0) {
            amountToMint = amount;
        } else {
            amountToMint = amount * MULTIPLIER / getPricePerShare();
        }
        _mint(to, amountToMint);
        deposits += amount;
        _update();
        emit Mint(msg.sender, amount, amountToMint, to);
    }

    function calculatePenalty(uint amount) external view returns (uint penalty) {
        if (debts == 0) {
            penalty = 0;
        } else {
            
        }
    }

    function burn(uint amount, address to) external override lock returns (uint amount) {
        require(amount != 0, "SingularityPair: AMOUNT_IS_0");
        _burn(msg.sender, amount);
        uint liquidityValue = liquidity * getPricePerShare() / MULTIPLIER;
        uint penalty = calculatePenalty(liquidityValue);
        uint tokenAmount = liquidityValue - penalty;
        IERC20(token).safeTransfer(to, tokenAmount);
        deposits -= tokenAmount;
        _update();
        emit Burn(msg.sender, amount, tokenAmount, to);
    }

    function swap(uint amount0Out, uint amount1Out, address to) external override lock {
       
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    function _updateAccumulatedFees(uint amountIn) internal {
        address feeTo = ISingularityFactory(factory).feeTo();
        if (feeTo != address(0)) {
            fees += amountIn * fee / (6 * FEE_MULTIPLIER);
        }
    }

    function sync() external override lock {
        _update(IERC20(token).balanceOf(address(this)) - fees);
    }
}