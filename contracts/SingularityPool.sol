// SPDX-License-Identifier: bsl-1.1

pragma solidity ^0.8.10;

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

    uint public override liabilities;
    uint public override assets;

    uint public override adminFees;
    uint public override lockedFees;

    uint public override baseFee;
    
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

    // ALWAYS RETURNS PRICE IN 18 DECIMALS
    function getTokenPrice() public view override returns (uint tokenPrice) {
        (tokenPrice, ) = IOracle(ISingularityFactory(factory).oracle()).getPriceUSD(token);
        require(tokenPrice != 0, "SingularityPool: INVALID_ORACLE_PRICE");
    }

    function getFees(uint amount) public view override returns (uint lockedFee, uint adminFee, uint lpFee) {
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

    function getPricePerShare() public view override returns (uint pricePerShare) {
        if (totalSupply == 0) {
            pricePerShare = MULTIPLIER;
        } else {
            pricePerShare = MULTIPLIER * (liabilities - lockedFees) / totalSupply;
        }
    }

    function mint(uint amount, address to) external override notPaused lock returns (uint amountToMint) {
        require(amount != 0, "SingularityPool: AMOUNT_IS_0");
        require(amount + liabilities <= depositCap, "SingularityPool: MINT_EXCEEDS_CAP");
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        liabilities += amount;
        assets += amount;
        if (liabilities == 0) {
            amountToMint = amount;
        } else {
            amountToMint = amount * MULTIPLIER / getPricePerShare();
        }
        _mint(to, amountToMint);
        emit Mint(msg.sender, amount, amountToMint, to);
    }

    function getCollatalizationRatio() public view override returns (uint collateralizationRatio) {
        if (liabilities == 0) {
            collateralizationRatio = type(uint).max;
        } else {
            collateralizationRatio = MULTIPLIER * assets / liabilities;
        }
    }

    function getNewCollateralizationRatio(uint newAssets, uint newLiabilities) internal view returns (uint newCollateralizationRatio) {
        if (liabilities == 0) {
            newCollateralizationRatio = type(uint).max;
        } else {
            newCollateralizationRatio = MULTIPLIER * newAssets / newLiabilities;
        }
    }

    function calculatePenalty(uint amount, uint newAssets, uint newLiabilities) public view returns (uint penalty) {
        uint collateralizationRatio = getNewCollateralizationRatio(newAssets, newLiabilities);
        uint penaltyRate;
        if (collateralizationRatio >= 1 ether) {
            penaltyRate = 0;
        } else if (collateralizationRatio >= 0.95 ether) {
            penaltyRate = 0.01 ether;
        } else if (collateralizationRatio >= 0.85 ether) {
            penaltyRate = 0.02 ether;
        } else if (collateralizationRatio >= 0.8 ether) {
            penaltyRate = 0.05 ether;
        } else if (collateralizationRatio >= 0.75 ether) {
            penaltyRate = 0.1 ether;
        } else if (collateralizationRatio >= 0.7 ether) {
            penaltyRate = 0.25 ether;
        } else if (collateralizationRatio >= 0.6 ether) {
            penaltyRate = 0.5 ether;
        } else {
            penaltyRate = 0.9 ether;
        }
        penalty = amount * penaltyRate / MULTIPLIER;
    }

    function burn(uint amount, address to) external override notPaused lock returns (uint amountWithdrawn) {
        require(amount != 0, "SingularityPool: AMOUNT_IS_0");
        _burn(msg.sender, amount);
        uint liquidityValue = amount * getPricePerShare() / MULTIPLIER;
        uint penalty = calculatePenalty(liquidityValue, assets - amountWithdrawn, liabilities - amountWithdrawn);
        amountWithdrawn = liquidityValue - penalty;
        IERC20(token).safeTransfer(to, amountWithdrawn);
        liabilities -= amountWithdrawn;
        assets -= amountWithdrawn;
        adminFees += penalty;
        emit Burn(msg.sender, amount, amountWithdrawn, to);
    }

    function swapIn(uint256 amountIn) external override notPaused lock returns (uint amountOut) {
        require(msg.sender == ISingularityFactory(factory).router(), "SingularityPool: NOT_ROUTER");
        require(amountIn != 0, "SingularityPool: AMOUNT_IS_0");
        IERC20(token).safeTransferFrom(msg.sender, address(this), amountIn);
        assets += amountIn;
        amountOut = amountIn * 10**(18 - decimals) * getTokenPrice() / MULTIPLIER;
        emit SwapIn(msg.sender, amountIn, amountOut);
    }

    function swapOut(uint256 amountIn, address to) external override notPaused lock returns (uint amountOut) {
        require(msg.sender == ISingularityFactory(factory).router(), "SingularityPool: NOT_ROUTER");
        require(amountIn != 0, "SingularityPool: AMOUNT_IS_0");
        amountOut = amountIn * MULTIPLIER / (getTokenPrice() * 10**(18 - decimals));
        // Calculate penalties
        uint penalty = calculatePenalty(amountOut, assets - amountOut, liabilities);
        amountOut -= penalty;

        // Apply fees
        (uint lockedFee, uint adminFee, uint lpFee) = getFees(amountOut);
        adminFees += adminFee;
        lockedFees += lockedFee;
        liabilities += lpFee;
        amountOut -= lockedFee + adminFee + lpFee;

        assets -= amountOut;
        IERC20(token).safeTransfer(to, amountOut);
        emit SwapOut(msg.sender, amountIn, amountOut, to);
    }

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