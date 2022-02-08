// SPDX-License-Identifier: bsl-1.1

pragma solidity ^0.8.11;

import "./SingularityERC20.sol";
import "./interfaces/ISingularityPool.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/ISingularityFactory.sol";
import "./interfaces/IOracle.sol";
import "./utils/SafeERC20.sol";
import "hardhat/console.sol";

contract SingularityPool is ISingularityPool, SingularityERC20 {
    using SafeERC20 for IERC20;

    bool public override paused;

    address public immutable override factory;
    address public override token;

    uint public override depositCap;
    uint public override assets;
    uint public override liabilities;

    uint public override baseFee;
    uint public override adminFees;
    uint public override lockedFees;
    
    uint private constant MULTIPLIER = 10**18;
    uint private locked = 1;

    modifier lock() {
        require(locked == 1, "SingularityPool: REENTRANCY");
        locked = 2;
        _;
        locked = 1;
    }

    modifier notPaused() {
        require(paused == false, "SingularityPool: PAUSED");
        _;
    }

    modifier onlyFactory() {
        require(msg.sender == factory, "SingularityPool: FORBIDDEN");
        _;
    }

    constructor() {
        factory = msg.sender;
    }

    function initialize(address _token, string calldata _name, string calldata _symbol, uint _baseFee) external override onlyFactory {
        token = _token;
        name = _name;
        symbol = _symbol;
        decimals = IERC20(_token).decimals();
        baseFee = _baseFee;
    }

    function getPricePerShare() public view override returns (uint pricePerShare) {
        if (totalSupply == 0) {
            pricePerShare = MULTIPLIER;
        } else {
            pricePerShare = MULTIPLIER * liabilities / totalSupply;
        }
    }

    function getAssetsAndLiabilities() external view override returns (uint _assets, uint _liabilities) {
        _assets = assets;
        _liabilities = liabilities;
    }

    function getTokenPrice() public view override returns (uint tokenPrice) {
        (tokenPrice, ) = IOracle(ISingularityFactory(factory).oracle()).getPriceUSD(token);
        require(tokenPrice != 0, "SingularityPool: INVALID_ORACLE_PRICE");
    }

    function amountToValue(uint amount) public override view returns (uint value) {
        value = amount * 10**(18 - decimals) * getTokenPrice() / MULTIPLIER;
    }

    function valueToAmount(uint value) public override view returns (uint amount) {
        amount = value * MULTIPLIER / (getTokenPrice() * 10**(18 - decimals));
    }

    function getDepositFee(uint amount) public view override returns (uint fee) {
        uint collateralizationRatio = getCollatalizationRatio(assets + amount, liabilities + amount);
        uint depositFeeRate;
        if (collateralizationRatio <= 1 ether) {
            depositFeeRate = 0;
        } else {
            depositFeeRate = 0.0000005 ether * MULTIPLIER / (collateralizationRatio / 10**16)**8;
        }
        uint percentOfPool = 100 * amount * MULTIPLIER / (liabilities + amount);
        depositFeeRate = depositFeeRate * percentOfPool / MULTIPLIER;
        fee = amount * depositFeeRate / MULTIPLIER;
    }

    function getWithdrawFee(uint amount) public view override returns (uint fee) {
        uint collateralizationRatio = getCollatalizationRatio(assets - amount, liabilities - amount);
        uint withdrawFeeRate;
        if (collateralizationRatio >= 1 ether) {
            withdrawFeeRate = 0;
        } else {
            withdrawFeeRate = 0.0000005 ether * MULTIPLIER / (collateralizationRatio / 10**16)**8;
        }
        uint percentOfPool = liabilities != 0 ? 100 * amount * MULTIPLIER / liabilities : 100 ether;
        withdrawFeeRate = withdrawFeeRate * percentOfPool / MULTIPLIER;
        fee = amount * withdrawFeeRate / MULTIPLIER;
        if (fee > amount) {
            fee = amount;
        }
    }

    function getSlippage(uint amount, uint newAssets, uint newLiabilities) public override pure returns (uint slippage) {
        uint collateralizationRatio = getCollatalizationRatio(newAssets, newLiabilities);
        uint slippageRate;
        if (collateralizationRatio >= 1 ether) {
            slippageRate = 0;
        } else if (collateralizationRatio > 0.33 ether) {
            slippageRate = 0.000000014 ether * MULTIPLIER / (collateralizationRatio / 10**16)**8;
        } else {
            slippageRate = 0.01 ether;
        }
        slippage = amount * slippageRate / MULTIPLIER;
    }

    function getTradingFees(uint amount) public view override returns (uint lockedFee, uint adminFee, uint lpFee) {
        (, uint updateTime) = IOracle(ISingularityFactory(factory).oracle()).getPriceUSD(token);
        uint timeDiff = block.timestamp - updateTime;
        uint rate;
        if (timeDiff >= 60) {
            rate = baseFee * 2;
        } else {
            rate = baseFee + baseFee * timeDiff / 60;
        }
        lockedFee = rate * amount / (3 * MULTIPLIER);
        adminFee = rate * amount / (3 * MULTIPLIER);
        lpFee = rate * amount / (3 * MULTIPLIER);
    }

    function deposit(uint amount, address to) external override notPaused lock returns (uint amountMinted) {
        require(amount != 0, "SingularityPool: AMOUNT_IS_0");
        require(amount + liabilities <= depositCap, "SingularityPool: DEPOSIT_EXCEEDS_CAP");
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        if (liabilities == 0) {
            amountMinted = amount;
        } else {
            amountMinted = amount * MULTIPLIER / getPricePerShare();
        }
        uint depositFee = getDepositFee(amount);
        amount -= depositFee;
        adminFees += depositFee;
        liabilities += amount;
        assets += amount;
        _mint(to, amountMinted);
        emit Deposit(msg.sender, amount, amountMinted, to);
    }

    function withdraw(uint amount, address to) external override notPaused lock returns (uint amountWithdrawn) {
        require(amount != 0, "SingularityPool: AMOUNT_IS_0");
        _burn(msg.sender, amount);
        uint liquidityValue = amount * getPricePerShare() / MULTIPLIER;
        uint withdrawFee = getWithdrawFee(amount);
        amountWithdrawn = liquidityValue - withdrawFee;
        adminFees += withdrawFee;
        liabilities -= amountWithdrawn;
        assets -= amountWithdrawn;
        IERC20(token).safeTransfer(to, amountWithdrawn);
        emit Withdraw(msg.sender, amount, amountWithdrawn, to);
    }

    function swapIn(uint amountIn) external override notPaused lock returns (uint amountOut) {
        require(msg.sender == ISingularityFactory(factory).router(), "SingularityPool: NOT_ROUTER");
        require(amountIn != 0, "SingularityPool: AMOUNT_IS_0");
        IERC20(token).safeTransferFrom(msg.sender, address(this), amountIn);
        // Apply slippage (bonus)
        uint slippage = getSlippage(amountIn, assets + amountIn, liabilities);
        amountIn += slippage;
        liabilities -= slippage;
        assets += amountIn;
        amountOut = amountToValue(amountIn);
        emit SwapIn(msg.sender, amountIn, amountOut);
    }

    function swapOut(uint amountIn, address to) external override notPaused lock returns (uint amountOut) {
        require(msg.sender == ISingularityFactory(factory).router(), "SingularityPool: NOT_ROUTER");
        require(amountIn != 0, "SingularityPool: AMOUNT_IS_0");
        amountOut = valueToAmount(amountIn);
        // Apply slippage (penalty)
        uint slippage = getSlippage(amountOut, assets - amountOut, liabilities);
        amountOut -= slippage;
        // Apply fees
        (uint lockedFee, uint adminFee, uint lpFee) = getTradingFees(amountOut);
        lockedFees += lockedFee;
        adminFees += adminFee;
        liabilities += lpFee;
        amountOut -= lockedFee + adminFee + lpFee;
        assets -= amountOut;
        IERC20(token).safeTransfer(to, amountOut);
        emit SwapOut(msg.sender, amountIn, amountOut, to);
    }

    function getCollatalizationRatio(uint _assets, uint _liabilities) internal pure returns (uint newCollateralizationRatio) {
        if (_liabilities == 0) {
            newCollateralizationRatio = type(uint).max;
        } else {
            newCollateralizationRatio = MULTIPLIER * _assets / _liabilities;
        }
    }

    /* ========== ADMIN FUNCTIONS ========== */

    function collectFees() external override onlyFactory {
        address feeTo = ISingularityFactory(factory).feeTo();
        IERC20(token).safeTransfer(feeTo, adminFees);
        adminFees = 0;
    }

    function setDepositCap(uint newDepositCap) external override onlyFactory {
        depositCap = newDepositCap;
    }

    function setBaseFee(uint newBaseFee) external override onlyFactory {
        baseFee = newBaseFee;
    }

    function setPaused(bool _paused) external override onlyFactory {
        paused = _paused;
    }
}