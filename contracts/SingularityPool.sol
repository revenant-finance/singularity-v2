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
    uint256 public override protocolFees;

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

    /// @notice Calculates the price-per-share (PPS)
    /// @dev PPS = 1 when pool is empty
    /// @return pricePerShare The PPS of 1 LP token
    function getPricePerShare() public view override returns (uint256 pricePerShare) {
        if (totalSupply == 0) {
            pricePerShare = 1 ether;
        } else {
            pricePerShare = liabilities.divWadDown(totalSupply);
        }
    }

    function getAssets() public view override returns (uint256 _assets) {
        return assets + protocolFees;
    }

    function getLiabilities() public view override returns (uint256 _liabilities) {
        return liabilities + protocolFees;
    }

    function getCollateralizationRatio() public view override returns (uint256 collateralizationRatio) {
        if (liabilities == 0) {
            collateralizationRatio = 1 ether;
        } else {
            collateralizationRatio = (getAssets()).divWadDown(getLiabilities());
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

    function getDepositFee(uint256 amount) public view override returns (uint256 fee) {
        if (liabilities == 0) {
            return 0;
        }

        if (getCollateralizationRatio() <= 1 ether) {
            fee = 0;
        } else {
            fee = _getDepositFee(amount);
        }
    }

    function _getDepositFee(uint256 amount) internal view returns (uint256 fee) {
        uint256 currentCollateralizationRatio = getCollateralizationRatio();
        uint256 gCurrent = getG(currentCollateralizationRatio);
        uint256 _assets = getAssets();
        uint256 _liabilities = getLiabilities();
        uint256 afterCollateralizationRatio = _calcCollatalizationRatio(_assets + amount, _liabilities + amount);
        uint256 gAfter = getG(afterCollateralizationRatio);
        fee = (_liabilities + amount).mulWadUp(gAfter) - _liabilities.mulWadDown(gCurrent);
    }

    function getWithdrawFee(uint256 amount) public view override returns (uint256 fee) {
        if (getCollateralizationRatio() >= 1 ether) {
            fee = 0;
        } else {
            fee = _getWithdrawFee(amount);
        }
    }

    function _getWithdrawFee(uint256 amount) internal view returns (uint256 fee) {
        uint256 currentCollateralizationRatio = getCollateralizationRatio();
        uint256 gCurrent = getG(currentCollateralizationRatio);
        uint256 _assets = getAssets();
        uint256 _liabilities = getLiabilities();
        uint256 afterCollateralizationRatio = _calcCollatalizationRatio(_assets - amount, _liabilities - amount);
        uint256 gAfter = getG(afterCollateralizationRatio);
        fee = gAfter.mulWadUp(_liabilities - amount) + getG(1 ether).mulWadUp(amount) - gCurrent.mulWadDown(_liabilities);
    }

    function getSlippageIn(uint256 amount) public view override returns (uint256 slippageIn) {
        uint256 currentCollateralizationRatio = getCollateralizationRatio();
        uint256 gCurrent = getG(currentCollateralizationRatio);
        uint256 afterCollateralizationRatio = _calcCollatalizationRatio(getAssets()  + amount, getLiabilities());
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
        if (amount >= assets + protocolFees) {
            return amount;
        }

        uint256 currentCollateralizationRatio = getCollateralizationRatio();
        uint256 afterCollateralizationRatio = _calcCollatalizationRatio(getAssets() - amount, getLiabilities());
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

    ///
    ///                     0.00002
    ///     g = -------------------------------
    ///          (collateralization ratio) ^ 7
    ///
    function getG(uint256 collateralizationRatio) public pure override returns (uint256 g) {
        uint256 numerator = 0.00002 ether;
        uint256 denominator = collateralizationRatio.rpow(7, 1 ether);
        g = numerator.divWadUp(denominator);
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

    function getTradingFees(uint256 amount) public view override returns (uint256 totalFee, uint256 protocolFee, uint256 lpFee) {
        uint256 tradingFeeRate = getTradingFeeRate();
        if (tradingFeeRate == type(uint256).max) {
            return (type(uint256).max, type(uint256).max, type(uint256).max);
        }
        totalFee = amount.mulWadUp(tradingFeeRate);
        protocolFee = totalFee * 55 / 100;
        lpFee = totalFee - protocolFee;
    }

    function deposit(uint256 amount, address to) external override onlyRouter notPaused nonReentrant returns (uint256 mintAmount) {
        require(amount != 0, "SingularityPool: AMOUNT_IS_0");
        require(amount + liabilities <= depositCap, "SingularityPool: DEPOSIT_EXCEEDS_CAP");
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        uint depositFee;
        if (liabilities == 0) {
            mintAmount = amount;
        } else {
            mintAmount = amount.divWadDown(getPricePerShare());
        }
        depositFee = getDepositFee(mintAmount);
        
        protocolFees += depositFee;
        mintAmount -= depositFee;
        assets += mintAmount;
        liabilities += mintAmount;
        _mint(to, mintAmount);
        emit Deposit(msg.sender, amount, mintAmount, to);
    }

    function withdraw(uint256 amount, address to) external override onlyRouter notPaused nonReentrant returns (uint256 withdrawAmount) {
        require(amount != 0, "SingularityPool: AMOUNT_IS_0");
        uint256 pricePerShare = getPricePerShare();
        _burn(msg.sender, amount);
        uint256 liquidityValue = amount.mulWadDown(pricePerShare);
        uint256 withdrawFee = getWithdrawFee(liquidityValue);
        assets -= liquidityValue;
        liabilities -= liquidityValue;
        protocolFees += withdrawFee;
        withdrawAmount = liquidityValue - withdrawFee;
        IERC20(token).safeTransfer(to, withdrawAmount);
        emit Withdraw(msg.sender, amount, withdrawAmount, to);
    }

    function swapIn(uint256 amountIn) external override onlyRouter notPaused nonReentrant returns (uint256 amountOut) {
        require(amountIn != 0, "SingularityPool: AMOUNT_IS_0");
        IERC20(token).safeTransferFrom(msg.sender, address(this), amountIn);

        // Apply slippage (+)
        uint256 slippage = getSlippageIn(amountIn);
        assets += amountIn;
        amountIn += slippage;

        // Apply trading fees
        (uint256 totalFee, uint256 protocolFee, uint256 lpFee) = getTradingFees(amountIn);
        require(totalFee != type(uint256).max, "SingularityPool: STALE_ORACLE");
        protocolFees += protocolFee;
        liabilities += lpFee;
        amountIn -= totalFee;
        amountOut = getAmountToUSD(amountIn);

        emit SwapIn(msg.sender, amountIn, amountOut);
    }

    function swapOut(uint256 amountIn, address to) external override onlyRouter notPaused nonReentrant returns (uint256 amountOut) {
        require(amountIn != 0, "SingularityPool: AMOUNT_IS_0");
        amountOut = getUSDToAmount(amountIn);

        // Apply slippage (-)
        uint256 slippage = getSlippageOut(amountOut);
        amountOut -= slippage;

        // Apply trading fees
        (uint256 totalFee, uint256 protocolFee, uint256 lpFee) = getTradingFees(amountOut);
        require(totalFee != type(uint256).max, "SingularityPool: STALE_ORACLE");
        protocolFees += protocolFee;
        liabilities += lpFee;
        amountOut -= totalFee;
        assets -= amountOut;
        IERC20(token).safeTransfer(to, amountOut);

        emit SwapOut(msg.sender, amountIn, amountOut, to);
    }

    function _calcCollatalizationRatio(uint256 _assets, uint256 _liabilities) internal pure returns (uint256 afterCollateralizationRatio) {
        if (_liabilities == 0) {
            afterCollateralizationRatio = 1 ether;
        } else {
            afterCollateralizationRatio = (_assets).divWadDown(_liabilities);
        }
    }

    /* ========== FACTORY FUNCTIONS ========== */

    function collectFees() external override onlyFactory {
        if (protocolFees != 0) {
            address feeTo = ISingularityFactory(factory).feeTo();
            IERC20(token).safeTransfer(feeTo, protocolFees);
            protocolFees = 0;
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