// SPDX-License-Identifier: No License

pragma solidity ^0.8.13;

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
    using FixedPointMathLib for uint256;

    bool public override paused;
    bool public immutable override isStablecoin;

    address public immutable override factory;
    address public immutable override token;

    uint256 public override depositCap;
    uint256 public override assets;
    uint256 public override liabilities;

    uint256 public override baseFee;
    uint256 public override adminFees;
    uint256 public override lockedFees;

    modifier notPaused() {
        require(paused == false, "SingularityPool: PAUSED");
        _;
    }

    modifier onlyFactory() {
        require(msg.sender == factory, "SingularityPool: NOT_FACTORY");
        _;
    }

    modifier onlyRouter() {
        require(msg.sender == ISingularityFactory(factory).router(), "SingularityPool: NOT_ROUTER");
        _;
    }

    constructor() {
        factory = msg.sender;
        (token, isStablecoin, baseFee) = ISingularityFactory(msg.sender).poolParams();
        string memory tranche = ISingularityFactory(msg.sender).tranche();
        string memory tokenSymbol = IERC20(token).symbol();
        name = string(
            abi.encodePacked(
                "Singularity ", tokenSymbol, " Pool (", tranche, ")"
            )
        );
        symbol = string(
            abi.encodePacked(
                "SPT-", tokenSymbol, " (", tranche, ")"
            )
        );
        decimals = IERC20(token).decimals();
        _initialize();
    }

    function getCollateralizationRatio() external view override returns (uint256 collateralizationRatio) {
        if (liabilities == 0) {
            collateralizationRatio = type(uint256).max;
        } else {
            collateralizationRatio = assets.divWadDown(liabilities);
        }
    }

    function getPricePerShare() public view override returns (uint256 pricePerShare) {
        if (totalSupply == 0) {
            pricePerShare = 1e18;
        } else {
            pricePerShare = liabilities.divWadDown(totalSupply);
        }
    }

    function getOracleData() public view override returns (uint256 tokenPrice, uint256 updatedAt) {
        (tokenPrice, updatedAt) = ISingularityOracle(ISingularityFactory(factory).oracle()).getLatestRound(token);
        require(tokenPrice != 0, "SingularityPool: INVALID_ORACLE_PRICE");
    }

    /// @notice Calculates the equivalent USD value of given the number of tokens
    /// @dev USD value is in 1e18
    /// @param amount The amount of tokens to calculate the value of
    /// @return value The USD value equivalent to the number of tokens
    function getAmountToUSD(uint256 amount) public override view returns (uint256 value) {
        (uint256 tokenPrice, ) = getOracleData();
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
    function getUSDToAmount(uint256 value) public override view returns (uint256 amount) {
        (uint256 tokenPrice, ) = getOracleData();
        amount = value.divWadDown(tokenPrice);
        if (decimals <= 18) {
            amount /= 10**(18 - decimals);
        } else {
            amount *= 10**(decimals - 18);
        }
    }

    function getLpFeeRate(uint256 collateralizationRatio) public pure override returns (uint256 lpFeeRate) {
        if (collateralizationRatio == 0) {
            return 0;
        }
        uint256 truncatedCRatio = collateralizationRatio / 10**15; // truncate collateralization ratio precision to 3
        uint256 numerator = 50 ether;
        uint256 denominator = truncatedCRatio.rpow(8, 1);
        lpFeeRate = numerator.divWadUp(denominator);
    }

    function getDepositFee(uint256 amount) public view override returns (uint256 fee) {
        uint256 currentCollateralizationRatio = _calcCollatalizationRatio(assets, liabilities);
        if (currentCollateralizationRatio >= 1 ether) {
            return 0;
        }

        uint256 gCurrent = getG(currentCollateralizationRatio);
        uint256 afterCollateralizationRatio = _calcCollatalizationRatio(assets + amount, liabilities + amount);
        uint256 gAfter = getG(afterCollateralizationRatio);
        fee = (liabilities + amount).mulWadUp(gAfter) - liabilities.mulWadDown(gCurrent);
    }

    function getWithdrawFee(uint256 amount) public view override returns (uint256 fee) {
        uint256 currentCollateralizationRatio = _calcCollatalizationRatio(assets, liabilities);
        if (currentCollateralizationRatio >= 1 ether) {
            return 0;
        }

        uint256 gCurrent = getG(currentCollateralizationRatio);
        uint256 afterCollateralizationRatio = _calcCollatalizationRatio(assets - amount, liabilities - amount);
        uint256 gAfter = getG(afterCollateralizationRatio);
        fee = gAfter.mulWadUp(liabilities - amount) + getG(1 ether).mulWadUp(amount) - gCurrent.mulWadDown(liabilities);
    }

    function getSlippageIn(uint256 amount) public view override returns (uint256 slippageIn) {
        if (amount == 0) {
            return 0;
        }

        uint256 currentCollateralizationRatio = _calcCollatalizationRatio(assets + lockedFees, liabilities);
        uint256 gCurrent = getG(currentCollateralizationRatio);
        uint256 afterCollateralizationRatio = _calcCollatalizationRatio(assets + lockedFees + amount, liabilities);
        uint256 gAfter = getG(afterCollateralizationRatio);
        uint256 gDiff = gCurrent - gAfter;
        if (gDiff == 0) {
            return 0;
        } else {
            slippageIn = gDiff.divWadDown(afterCollateralizationRatio - currentCollateralizationRatio);
        }
        slippageIn = amount.mulWadDown(slippageIn);
    }

    function getSlippageOut(uint256 amount) public view override returns (uint256 slippageOut) {
        if (amount == 0) {
            return 0;
        }
        if (amount >= assets + lockedFees) {
            return amount;
        }

        uint256 currentCollateralizationRatio = _calcCollatalizationRatio(assets + lockedFees, liabilities);
        uint256 afterCollateralizationRatio = _calcCollatalizationRatio(assets + lockedFees - amount, liabilities);
        uint256 gCurrent = getG(currentCollateralizationRatio);
        uint256 gAfter = getG(afterCollateralizationRatio);
        uint256 gDiff = gAfter - gCurrent;
        if (gDiff == 0) {
            return 0;
        } else {
            slippageOut = gDiff.divWadUp(currentCollateralizationRatio - afterCollateralizationRatio);
        }
        slippageOut = amount.mulWadUp(slippageOut);
    }

    function getG(uint256 collateralizationRatio) public pure override returns (uint256 slippageRate) {
        if (collateralizationRatio >= 1 ether) {
            slippageRate = 0.00002 ether;
        } else {
            uint256 truncatedCRatio = collateralizationRatio / 10**15; // truncate collateralization ratio precision to 3
            uint256 numerator = 0.02 ether;
            uint256 denominator = truncatedCRatio.rpow(7, 1);
            slippageRate = numerator.divWadUp(denominator);
        }
    }

    function getTradingFeeRate() public view override returns (uint256 tradingFeeRate) {
        if (isStablecoin) {
            tradingFeeRate = baseFee;
        } else {
            (, uint256 updatedAt) = getOracleData();
            uint256 timeDiff = block.timestamp - updatedAt;
            if (timeDiff > 70) {
                tradingFeeRate = type(uint256).max; // Revert later to allow viewability
            } else if (timeDiff >= 60) {
                tradingFeeRate = baseFee * 2;
            } else {
                tradingFeeRate = baseFee + baseFee * timeDiff / 60;
            }
        }
    }

    function getTradingFees(uint256 amount) public view override returns (uint256 totalFee, uint256 lockedFee, uint256 adminFee, uint256 lpFee) {
        uint256 tradingFeeRate = getTradingFeeRate();
        if (tradingFeeRate == type(uint256).max) {
            return (type(uint256).max, type(uint256).max, type(uint256).max, type(uint256).max);
        }
        totalFee = amount.mulWadUp(tradingFeeRate);
        lockedFee = totalFee * 45 / 100;
        lpFee = totalFee * 45 / 100;
        adminFee = totalFee - lockedFee - lpFee;
    }

    function deposit(uint256 amount, address to) external override onlyRouter notPaused nonReentrant returns (uint256 mintAmount) {
        require(amount != 0, "SingularityPool: AMOUNT_IS_0");
        require(amount + liabilities <= depositCap, "SingularityPool: DEPOSIT_EXCEEDS_CAP");
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        if (liabilities == 0) {
            mintAmount = amount;
        } else {
            mintAmount = amount.divWadDown(getPricePerShare());
        }
        uint256 depositFee = getDepositFee(amount);
        amount -= depositFee;
        adminFees += depositFee;
        liabilities += amount;
        assets += amount;
        _mint(to, mintAmount);
        emit Deposit(msg.sender, amount, mintAmount, to);
    }

    function withdraw(uint256 amount, address to) external override onlyRouter notPaused nonReentrant returns (uint256 withdrawAmount) {
        require(amount != 0, "SingularityPool: AMOUNT_IS_0");
        _burn(msg.sender, amount);
        uint256 liquidityValue = amount.mulWadDown(getPricePerShare());
        uint256 withdrawFee = getWithdrawFee(amount);
        withdrawAmount = liquidityValue - withdrawFee;
        adminFees += withdrawFee;
        liabilities -= withdrawAmount;
        assets -= withdrawAmount;
        IERC20(token).safeTransfer(to, withdrawAmount);
        emit Withdraw(msg.sender, amount, withdrawAmount, to);
    }

    function swapIn(uint256 amountIn) external override onlyRouter notPaused nonReentrant returns (uint256 amountOut) {
        require(amountIn != 0, "SingularityPool: AMOUNT_IS_0");
        IERC20(token).safeTransferFrom(msg.sender, address(this), amountIn);

        // Apply trading fees
        (uint256 totalFee, uint256 lockedFee, uint256 adminFee, uint256 lpFee) = getTradingFees(amountIn);
        require(totalFee != type(uint256).max, "SingularityPool: STALE_ORACLE");
        lockedFees += lockedFee;
        adminFees += adminFee;
        liabilities += lpFee;
        amountIn -= totalFee;

        // Apply slippage (+)
        uint256 slippage = getSlippageIn(amountIn);
        amountIn += slippage;
        assets -= slippage;
        liabilities -= slippage;

        assets += amountIn;
        amountOut = getAmountToUSD(amountIn);
        emit SwapIn(msg.sender, amountIn, amountOut);
    }

    function swapOut(uint256 amountIn, address to) external override onlyRouter notPaused nonReentrant returns (uint256 amountOut) {
        require(amountIn != 0, "SingularityPool: AMOUNT_IS_0");
        amountOut = getUSDToAmount(amountIn);

        // Apply slippage (-)
        uint256 slippage = getSlippageOut(amountOut);
        amountOut -= slippage;
        assets += slippage;
        liabilities += slippage;

        // Apply trading fees
        (uint256 totalFee, uint256 lockedFee, uint256 adminFee, uint256 lpFee) = getTradingFees(amountOut);
        require(totalFee != type(uint256).max, "SingularityPool: STALE_ORACLE");
        lockedFees += lockedFee;
        adminFees += adminFee;
        liabilities += lpFee;

        assets -= amountOut;
        amountOut -= totalFee;

        IERC20(token).safeTransfer(to, amountOut);
        emit SwapOut(msg.sender, amountIn, amountOut, to);
    }

    function _calcCollatalizationRatio(uint256 _assets, uint256 _liabilities) internal pure returns (uint256 afterCollateralizationRatio) {
        if (_liabilities == 0) {
            afterCollateralizationRatio = type(uint256).max;
        } else {
            afterCollateralizationRatio = _assets.divWadDown(_liabilities);
        }
    }

    /* ========== FACTORY FUNCTIONS ========== */

    function collectFees() external override onlyFactory {
        if (adminFees != 0) {
            address feeTo = ISingularityFactory(factory).feeTo();
            IERC20(token).safeTransfer(feeTo, adminFees);
            adminFees = 0;
        }
    }

    function setDepositCap(uint256 newDepositCap) external override onlyFactory {
        depositCap = newDepositCap;
    }

    function setBaseFee(uint256 newBaseFee) external override onlyFactory {
        baseFee = newBaseFee;
    }

    function setPaused(bool state) external override onlyFactory {
        paused = state;
    }
}