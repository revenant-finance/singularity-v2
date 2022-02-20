// SPDX-License-Identifier: No License

pragma solidity ^0.8.11;

import "./SingularityPoolToken.sol";
import "./interfaces/ISingularityPool.sol";
import "./interfaces/ISingularityFactory.sol";
import "./interfaces/ISingularityOracle.sol";
import "./interfaces/IERC20.sol";
import "./utils/SafeERC20.sol";
import "./utils/FixedPointMathLib.sol";
import "./utils/ReentrancyGuard.sol";

/**
 * @title Singularity Pool
 * @author Revenant Labs
 */
contract SingularityPool is ISingularityPool, SingularityPoolToken, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using FixedPointMathLib for uint;

    bool public override paused;
    bool public override isStablecoin;

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

    modifier notPaused() {
        require(paused == false, "SingularityPool: PAUSED");
        _;
    }

    modifier onlyFactory() {
        require(msg.sender == factory, "SingularityPool: FORBIDDEN");
        _;
    }

    modifier onlyRouter() {
        require(msg.sender == ISingularityFactory(factory).router(), "SingularityPool: NOT_ROUTER");
        _;
    }

    constructor() {
        factory = msg.sender;
    }

    /// @notice Only initializable once by factory
    function initialize(address _token, bool _isStablecoin, uint _baseFee) external override onlyFactory {
        token = _token;
        isStablecoin = _isStablecoin;
        name = string(abi.encodePacked(
            "Singularity ", 
            IERC20(_token).symbol(), 
            " Pool (", 
            ISingularityFactory(factory).tranche(), 
            ")"
        ));
        symbol = string(abi.encodePacked(
            "SPT-", 
            IERC20(_token).symbol(), 
            " (", 
            ISingularityFactory(factory).tranche(), 
            ")"
        ));
        decimals = IERC20(_token).decimals();
        baseFee = _baseFee;
    }

    function getAssetsAndLiabilities() external view override returns (uint _assets, uint _liabilities) {
        _assets = assets;
        _liabilities = liabilities;
    }

    function getCollateralizationRatio() external view override returns (uint collateralizationRatio) {
        if (liabilities == 0) {
            collateralizationRatio = type(uint).max;
        } else {
            collateralizationRatio = assets.divWadDown(liabilities);
        }
    }

    function getPricePerShare() public view override returns (uint pricePerShare) {
        if (totalSupply == 0) {
            pricePerShare = 1e18;
        } else {
            pricePerShare = liabilities.divWadDown(totalSupply);
        }
    }

    function getOracleData() public view override returns (uint tokenPrice, uint updatedAt) {
        (tokenPrice, updatedAt) = ISingularityOracle(ISingularityFactory(factory).oracle()).getLatestRound(token);
        require(tokenPrice != 0, "SingularityPool: INVALID_ORACLE_PRICE");
        require(updatedAt != 0, "SingularityPool: INVALID_ORACLE_UPDATE_TIMESTAMP");
    }

    /// @notice Calculates the equivalent USD value of given the number of tokens
    /// @dev USD value is in 1e18
    /// @param amount The amount of tokens to calculate the value of
    /// @return value The USD value equivalent to the number of tokens
    function getAmountToUSD(uint amount) public override view returns (uint value) {
        (uint tokenPrice, ) = getOracleData();
        value = amount.mulWadDown(tokenPrice);
        if (decimals <= 18) {
            value *= 10**(18 - decimals);
        } else {
            value /= 10**(decimals - 18);
        }
    }

    /// @notice Calculates the equivalent number of tokens given the USD value
    /// @dev USD value is in 1e18
    /// @param value The USD value of tokens to calculate the amount of
    /// @return amount The number of tokens equivalent to the USD value
    function getUSDToAmount(uint value) public override view returns (uint amount) {
        (uint tokenPrice, ) = getOracleData();
        amount = value.divWadDown(tokenPrice);
        if (decimals <= 18) {
            amount /= 10**(18 - decimals);
        } else {
            amount *= 10**(decimals - 18);
        }
    }

    function getDepositFee(uint amount) public view override returns (uint fee) {
        uint collateralizationRatio = _calcCollatalizationRatio(assets + amount, liabilities + amount);
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
        uint collateralizationRatio = _calcCollatalizationRatio(assets - amount, liabilities - amount);
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
        uint collateralizationRatio = _calcCollatalizationRatio(newAssets, newLiabilities);
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
        uint rate;
        if (isStablecoin) {
            rate = baseFee;
        } else {
            (, uint updatedAt) = getOracleData();
            uint timeDiff = block.timestamp - updatedAt;
            if (timeDiff >= 60) {
                rate = baseFee * 2;
            } else {
                rate = baseFee + baseFee * timeDiff / 60;
            }
        }
        lockedFee = rate * amount / (3 * MULTIPLIER);
        adminFee = rate * amount / (3 * MULTIPLIER);
        lpFee = rate * amount / (3 * MULTIPLIER);
    }

    function deposit(uint amount, address to) external override onlyRouter notPaused nonReentrant returns (uint amountMinted) {
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

    function withdraw(uint amount, address to) external override onlyRouter notPaused nonReentrant returns (uint amountWithdrawn) {
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

    function swapIn(uint amountIn) external override onlyRouter notPaused nonReentrant returns (uint amountOut) {
        require(amountIn != 0, "SingularityPool: AMOUNT_IS_0");
        IERC20(token).safeTransferFrom(msg.sender, address(this), amountIn);

        // Apply slippage (positive)
        uint slippage = getSlippage(amountIn, assets + amountIn, liabilities);
        amountIn += slippage;
        // TODO: should liabilities reflect slippage???

        // Apply trading fees
        (uint lockedFee, uint adminFee, uint lpFee) = getTradingFees(amountIn);
        lockedFees += lockedFee;
        adminFees += adminFee;
        liabilities += lpFee;
        amountIn -= lockedFee + adminFee + lpFee;
        assets += amountIn;
        amountOut = getAmountToUSD(amountIn);
        emit SwapIn(msg.sender, amountIn, amountOut);
    }

    function swapOut(uint amountIn, address to) external override onlyRouter notPaused nonReentrant returns (uint amountOut) {
        require(amountIn != 0, "SingularityPool: AMOUNT_IS_0");
        amountOut = getUSDToAmount(amountIn);

        // Apply slippage (negative)
        uint slippage = getSlippage(amountOut, assets - amountOut, liabilities);
        amountOut -= slippage;
        // TODO: should liabilities reflect slippage???

        // Apply trading fees
        (uint lockedFee, uint adminFee, uint lpFee) = getTradingFees(amountOut);
        lockedFees += lockedFee;
        adminFees += adminFee;
        liabilities += lpFee;
        amountOut -= lockedFee + adminFee + lpFee;
        assets -= amountOut;
        IERC20(token).safeTransfer(to, amountOut);
        emit SwapOut(msg.sender, amountIn, amountOut, to);
    }

    function _calcCollatalizationRatio(uint _assets, uint _liabilities) internal pure returns (uint newCollateralizationRatio) {
        if (_liabilities == 0) {
            newCollateralizationRatio = type(uint).max;
        } else {
            newCollateralizationRatio = MULTIPLIER * _assets / _liabilities;
        }
    }

    /* ========== FACTORY FUNCTIONS ========== */

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