// SPDX-License-Identifier: bsl-1.1

pragma solidity ^0.8.10;

import "./SingularityERC20.sol";
import "./interfaces/ISingularityPool.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/ISingularityFactory.sol";
import "./interfaces/IOracle.sol";
import "./utils/SafeERC20.sol";

contract SingularityPool is ISingularityPool, SingularityERC20 {
    using SafeERC20 for IERC20;

    bool public override paused;

    address public immutable override factory;
    address public override token;


    uint public override deposits;
    uint public override debts;
    uint public override fees;
    uint public override depositCap;
    
    uint private constant MULTIPLIER = 10**18;
    uint private locked = 1;

    modifier lock() {
        require(locked == 1, "REENTRANCY");
        locked = 2;
        _;
        locked = 1;
    }

    modifier notPaused() {
        require(paused == false, "PAUSED");
        _;
    }

    modifier onlyFactory() {
        require(msg.sender == factory, "SingularityPair: FORBIDDEN");
        _;
    }

    constructor() {
        factory = msg.sender;
    }

    function initialize(address _token, string calldata _name, string calldata _symbol) external override onlyFactory {
        token = _token;
        name = _name;
        symbol = _symbol;
        decimals = IERC20(_token).decimals();
    }

    function getTokenPrice() public view override returns (uint tokenPrice) {
        tokenPrice = IOracle(ISingularityFactory(factory).oracle()).getPriceUSD(token);
        require(tokenPrice != 0, "SingularityPair: INVALID_ORACLE_PRICE");
    }

    function getPricePerShare() public view override returns (uint pricePerShare) {
        if (totalSupply == 0) {
            pricePerShare = MULTIPLIER;
        } else {
            pricePerShare = MULTIPLIER * deposits / totalSupply;
        }
    }
    
    function getPercentDebt() public view override returns (uint percentDebt) {
        if (deposits == 0) {
            percentDebt = 0;
        } else {
            percentDebt = MULTIPLIER * debts / deposits;
        }
    }

    function mint(uint amount, address to) external override notPaused lock returns (uint amountToMint) {
        require(amount != 0, "SingularityPair: AMOUNT_IS_0");
        require(amount + deposits <= depositCap, "SingularityPair: MINT_EXCEEDS_CAP");
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        deposits += amount;
        if (deposits == 0) {
            amountToMint = amount;
        } else {
            amountToMint = amount * MULTIPLIER / getPricePerShare();
        }
        _mint(to, amountToMint);
        emit Mint(msg.sender, amount, amountToMint, to);
    }

    function calculatePenalty(uint amount) public view returns (uint penalty) {
        uint percentDebt = getPercentDebt();
        uint penaltyRate;
        if (percentDebt == 0) {
            penaltyRate = 0;
        } else if (percentDebt <= 0.025 ether) {
            penaltyRate = 0.01 ether;
        } else if (percentDebt <= 0.05 ether) {
            penaltyRate = 0.02 ether;
        } else if (percentDebt <= 0.1 ether) {
            penaltyRate = 0.03 ether;
        } else if (percentDebt <= 0.15 ether) {
            penaltyRate = 0.05 ether;
        } else if (percentDebt <= 0.2 ether) {
            penaltyRate = 0.1 ether;
        } else if (percentDebt <= 0.25 ether) {
            penaltyRate = 0.25 ether;
        } else {
            penaltyRate = 0.5 ether;
        }
        penalty = amount * penaltyRate / MULTIPLIER;
    }

    function burn(uint amount, address to) external override notPaused lock returns (uint amountWithdrawn) {
        require(amount != 0, "SingularityPair: AMOUNT_IS_0");
        _burn(msg.sender, amount);
        uint liquidityValue = amount * getPricePerShare() / MULTIPLIER;
        uint penalty = calculatePenalty(liquidityValue);
        amountWithdrawn = liquidityValue - penalty;
        IERC20(token).safeTransfer(to, amountWithdrawn);
        deposits -= amountWithdrawn;
        emit Burn(msg.sender, amount, amountWithdrawn, to);
    }

    function swap(address to) external override notPaused lock {
       
        emit Swap(msg.sender, to);
    }

    function collectFees() external override onlyFactory {
        address feeTo = ISingularityFactory(factory).feeTo();
        IERC20(token).safeTransfer(feeTo, fees);
        fees = 0;
    }

    function setDepositCap(uint newDepositCap) external override onlyFactory {
        depositCap = newDepositCap;
    }

    function setPaused(bool _paused) external override onlyFactory {
        paused = _paused;
    }
}