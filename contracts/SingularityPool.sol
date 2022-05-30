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
        require(!paused, "SingularityPool: PAUSED");
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
        (token, isStablecoin, baseFee) = ISingularityFactory(factory).poolParams();
        string memory tranche = ISingularityFactory(factory).tranche();
        string memory tokenSymbol = IERC20(token).symbol();
        name = string(
            abi.encodePacked(
                "Singularity Pool Token-", tokenSymbol, " (", tranche, ")"
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

    function deposit(uint256 amount, address to) external override notPaused nonReentrant returns (uint256 mintAmount) {
        require(amount != 0, "SingularityPool: AMOUNT_IS_0");
        require(amount + liabilities <= depositCap, "SingularityPool: DEPOSIT_EXCEEDS_CAP");

        // Transfer token from sender
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        if (liabilities == 0) {
            mintAmount = amount;

            // Mint LP tokens to `to`
            _mint(to, mintAmount);

            // Update assets and liabilities
            assets += amount;
            liabilities += amount;
        } else {            
            // Apply deposit fee
            uint depositFee = getDepositFee(amount);
            protocolFees += depositFee;
            uint amountPostFee = amount - depositFee;

            // Calculate amount of LP tokens to mint
            mintAmount = amountPostFee.divWadDown(getPricePerShare());

            // Mint LP tokens to `to`
            _mint(to, mintAmount);

            // Update assets and liabilities
            assets += amount;
            liabilities += amountPostFee;
        }
        
        emit Deposit(msg.sender, amount, mintAmount, to);
    }

    function withdraw(uint256 lpAmount, address to) external override notPaused nonReentrant returns (uint256 withdrawAmount) {
        require(lpAmount != 0, "SingularityPool: AMOUNT_IS_0");

        // Store current price-per-share
        uint256 pricePerShare = getPricePerShare();

        // Burn LP tokens
        _burn(msg.sender, lpAmount);

        // Calculate amount of underlying tokens to redeem
        uint256 amount = lpAmount.mulWadDown(pricePerShare);

        // Apply withdrawal fee
        uint256 withdrawalFee = getWithdrawalFee(amount);
        protocolFees += withdrawalFee;
        withdrawAmount = amount - withdrawalFee;

        // Transfer tokens to `to`
        IERC20(token).safeTransfer(to, withdrawAmount);

        // Update assets and liabilities
        assets -= withdrawAmount;
        liabilities -= amount;

        emit Withdraw(msg.sender, lpAmount, withdrawAmount, to);
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

        // Calculate amount out
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

        // Transfer tokens out
        IERC20(token).safeTransfer(to, amountOut);

        // Update assets
        assets -= amountOut;

        emit SwapOut(msg.sender, amountIn, amountOut, to);
    }

    /// @notice Calculates the price-per-share (PPS)
    /// @dev PPS = 1 when pool is empty
    /// @dev PPS is strictly increasing >= 1
    /// @return pricePerShare The PPS of 1 LP token
    function getPricePerShare() public view override returns (uint256 pricePerShare) {
        if (totalSupply == 0) {
            pricePerShare = 1 ether;
        } else {
            pricePerShare = liabilities.divWadDown(totalSupply);
        }
    }

    /// @notice Get pool's assets and liabilities
    /// @dev Includes protocol fees only in liabilities since they are already included in assets
    /// @return _assets The assets of the pool
    /// @return _liabilities The liabilities of the pool
    function getAssetsAndLiabilities() public view override returns (uint256 _assets, uint256 _liabilities) {
        return (assets, liabilities + protocolFees);
    }

    /// @notice Get pool's collateralization ratio
    /// @dev Collateralization ratio is 1 if pool not seeded
    /// @return collateralizationRatio The collateralization ratio of the pool
    function getCollateralizationRatio() public view override returns (uint256 collateralizationRatio) {
        if (liabilities == 0) {
            collateralizationRatio = 1 ether;
        } else {
            (uint256 _assets, uint256 _liabilities) = getAssetsAndLiabilities();
            collateralizationRatio = _assets.divWadDown(_liabilities);
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

    /// @notice Calculates the fee charged for deposit
    /// @dev Deposit fee is 0 when pool is empty
    /// @param amount The amount of tokens being deposited
    /// @return fee The fee charged for deposit
    function getDepositFee(uint256 amount) public view override returns (uint256 fee) {
        if (amount == 0 || liabilities == 0) return 0;

        uint256 currentCollateralizationRatio = getCollateralizationRatio();
        uint256 gCurrent = _getG(currentCollateralizationRatio);
        (uint256 _assets, uint256 _liabilities) = getAssetsAndLiabilities();
        uint256 afterCollateralizationRatio = _calcCollatalizationRatio(_assets + amount, _liabilities + amount);
        uint256 gAfter = _getG(afterCollateralizationRatio);

        if (currentCollateralizationRatio <= 1 ether) {
            fee = gCurrent.mulWadUp(_liabilities) + _getG(1 ether).mulWadUp(amount) - gAfter.mulWadDown(_liabilities + amount);
        } else {
            fee = gAfter.mulWadUp(_liabilities + amount) - gCurrent.mulWadDown(_liabilities);
        }
    }

    /// @notice Calculates the fee charged for withdraw
    /// @param amount The amount of tokens being withdrawn
    /// @return fee The fee charged for withdraw
    function getWithdrawalFee(uint256 amount) public view override returns (uint256 fee) {
        if (amount == 0) return 0;

        uint256 currentCollateralizationRatio = getCollateralizationRatio();
        uint256 gCurrent = _getG(currentCollateralizationRatio);
        (uint256 _assets, uint256 _liabilities) = getAssetsAndLiabilities();
        uint256 afterCollateralizationRatio = _calcCollatalizationRatio(_assets - amount, _liabilities - amount);
        uint256 gAfter = _getG(afterCollateralizationRatio);

        if (currentCollateralizationRatio >= 1 ether) {
            fee = gCurrent.mulWadDown(_liabilities) - gAfter.mulWadUp(_liabilities - amount);
        } else {
            fee = gAfter.mulWadUp(_liabilities - amount) + _getG(1 ether).mulWadUp(amount) - gCurrent.mulWadDown(_liabilities);
        }
    }

    function getSlippageIn(uint256 amount) public view override returns (uint256 slippageIn) {
        if (amount == 0) return 0;

        uint256 currentCollateralizationRatio = getCollateralizationRatio();
        (uint256 _assets, uint256 _liabilities) = getAssetsAndLiabilities();
        uint256 afterCollateralizationRatio = _calcCollatalizationRatio(_assets + amount, _liabilities);
        if (currentCollateralizationRatio == afterCollateralizationRatio) {
            return 0; 
        }

        // Calculate G'
        uint256 gCurrent = _getG(currentCollateralizationRatio);
        uint256 gAfter = _getG(afterCollateralizationRatio);
        uint256 gDiff = gCurrent - gAfter;
        
        // Calculate slippage
        slippageIn = amount.mulWadDown(gDiff.divWadDown(afterCollateralizationRatio - currentCollateralizationRatio));
    }

    function getSlippageOut(uint256 amount) public view override returns (uint256 slippageOut) {
        if (amount == 0) return 0;
        if (amount >= assets) return amount;

        uint256 currentCollateralizationRatio = getCollateralizationRatio();
        (uint256 _assets, uint256 _liabilities) = getAssetsAndLiabilities();
        uint256 afterCollateralizationRatio = _calcCollatalizationRatio(_assets - amount, _liabilities);
        if (currentCollateralizationRatio == afterCollateralizationRatio) {
            return 0; 
        }

        // Calculate G'
        uint256 gCurrent = _getG(currentCollateralizationRatio);
        uint256 gAfter = _getG(afterCollateralizationRatio);
        uint256 gDiff = gAfter - gCurrent;

        // Calculate slippage
        slippageOut = amount.mulWadUp(gDiff.divWadUp(currentCollateralizationRatio - afterCollateralizationRatio));
    }

    function getTradingFeeRate() public view override returns (uint256 tradingFeeRate) {
        if (isStablecoin) {
            tradingFeeRate = baseFee;
        } else {
            (, uint256 updatedAt) = getOracleData();
            uint256 oracleSens = ISingularityFactory(factory).oracleSens();
            uint256 timeSinceUpdate = block.timestamp - updatedAt;
            if (timeSinceUpdate * 10 > oracleSens * 11) {
                tradingFeeRate = type(uint256).max; // Revert later to allow viewability
            } else if (timeSinceUpdate >= oracleSens) {
                tradingFeeRate = baseFee * 2;
            } else {
                tradingFeeRate = baseFee + baseFee * timeSinceUpdate / oracleSens;
            }
        }
    }

    function getTradingFees(uint256 amount) public view override returns (uint256 totalFee, uint256 protocolFee, uint256 lpFee) {
        if (amount == 0) return (0, 0, 0);

        uint256 tradingFeeRate = getTradingFeeRate();
        if (tradingFeeRate == type(uint256).max) {
            return (type(uint256).max, type(uint256).max, type(uint256).max);
        }
        totalFee = amount.mulWadUp(tradingFeeRate);
        uint256 protocolFeeShare = ISingularityFactory(factory).protocolFeeShare();
        protocolFee = totalFee * protocolFeeShare / 100;
        lpFee = totalFee - protocolFee;
    }

    /* ========== INTERNAL/PURE FUNCTIONS ========== */

    ///
    ///                     0.00002
    ///     g = -------------------------------
    ///          (collateralization ratio) ^ 7
    ///
    function _getG(uint256 collateralizationRatio) internal pure returns (uint256 g) {
        uint256 numerator = 0.00002 ether;
        uint256 denominator = collateralizationRatio.rpow(7, 1 ether);
        g = numerator.divWadUp(denominator);
    }

    function _calcCollatalizationRatio(uint256 _assets, uint256 _liabilities) internal pure returns (uint256 afterCollateralizationRatio) {
        if (_liabilities == 0) {
            afterCollateralizationRatio = 1 ether;
        } else {
            afterCollateralizationRatio = _assets.divWadDown(_liabilities);
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