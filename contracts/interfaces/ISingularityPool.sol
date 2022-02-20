// SPDX-License-Identifier: No License

pragma solidity ^0.8.11;

import "./ISingularityPoolToken.sol";

interface ISingularityPool is ISingularityPoolToken {
    event Deposit(address indexed sender, uint indexed amountDeposited, uint amountMinted, address indexed to);
    event Withdraw(address indexed sender, uint indexed amountBurned, uint amountWithdrawn, address indexed to);
    event SwapIn(
        address indexed sender,
        uint indexed amountIn,
        uint amountOut
    );
    event SwapOut(
        address indexed sender,
        uint indexed amountIn,
        uint amountOut,
        address indexed to
    );

    function paused() external view returns (bool);
    function factory() external view returns (address);
    function token() external view returns (address);
    function isStablecoin() external view returns (bool);

    function depositCap() external view returns (uint);
    function assets() external view returns (uint);
    function liabilities() external view returns (uint);
    function adminFees() external view returns (uint);
    function lockedFees() external view returns (uint);
    function baseFee() external view returns (uint);

    function getAssetsAndLiabilities() external view returns (uint, uint);
    function getCollateralizationRatio() external view returns (uint);
    function getPricePerShare() external view returns (uint);
    function getOracleData() external view returns (uint, uint);
    function getAmountToUSD(uint amount) external view returns (uint);
    function getUSDToAmount(uint value) external view returns (uint);
    
    function getDepositFee(uint amount) external view returns (uint);
    function getWithdrawFee(uint amount) external view returns (uint);
    function getSlippage(uint amount, uint newAssets, uint newLiabilities) external view returns (uint);
    function getTradingFees(uint amount) external view returns (uint, uint, uint);

    function deposit(uint amount, address to) external returns (uint);
    function withdraw(uint amount, address to) external returns (uint);
    function swapIn(uint amountIn) external returns (uint);
    function swapOut(uint amountIn, address to) external returns (uint);

    function collectFees() external;
    function setDepositCap(uint newDepositCap) external;
    function setBaseFee(uint newBaseFee) external;
    function setPaused(bool paused) external;

    function initialize(
        address token, 
        bool isStablecoin, 
        uint baseFee
    ) external;
}
