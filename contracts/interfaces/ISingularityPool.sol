// SPDX-License-Identifier: No License

pragma solidity ^0.8.13;

import "./ISingularityPoolToken.sol";

interface ISingularityPool is ISingularityPoolToken {
    event Deposit(address indexed sender, uint256 indexed amountDeposited, uint256 mintAmount, address indexed to);
    event Withdraw(address indexed sender, uint256 indexed amountBurned, uint256 withdrawAmount, address indexed to);
    event SwapIn(
        address indexed sender,
        uint256 indexed amountIn,
        uint256 amountOut
    );
    event SwapOut(
        address indexed sender,
        uint256 indexed amountIn,
        uint256 amountOut,
        address indexed to
    );

    function paused() external view returns (bool);
    function isStablecoin() external view returns (bool);

    function factory() external view returns (address);
    function token() external view returns (address);

    function depositCap() external view returns (uint256);
    function assets() external view returns (uint256);
    function liabilities() external view returns (uint256);
    function adminFees() external view returns (uint256);
    function lockedFees() external view returns (uint256);
    function baseFee() external view returns (uint256);

    function getCollateralizationRatio() external view returns (uint256);
    function getPricePerShare() external view returns (uint256);
    function getOracleData() external view returns (uint256, uint256);
    function getAmountToUSD(uint256 amount) external view returns (uint256);
    function getUSDToAmount(uint256 value) external view returns (uint256);
    
    function getLpFeeRate(uint256 collateralizationRatio) external pure returns (uint256);
    function getDepositFee(uint256 amount) external view returns (uint256);
    function getWithdrawFee(uint256 amount) external view returns (uint256);
    function getSlippageIn(uint256 amount) external view returns (uint256 slippageIn);
    function getSlippageOut(uint256 amount) external view returns (uint256 slippageOut);
    function getTradingFeeRate() external view returns (uint256 tradingFeeRate);
    function getTradingFees(uint256 amount) external view returns (uint256, uint256, uint256, uint256);

    function deposit(uint256 amount, address to) external returns (uint256);
    function withdraw(uint256 amount, address to) external returns (uint256);
    function swapIn(uint256 amountIn) external returns (uint256);
    function swapOut(uint256 amountIn, address to) external returns (uint256);

    function collectFees() external;
    function setDepositCap(uint256 newDepositCap) external;
    function setBaseFee(uint256 newBaseFee) external;
    function setPaused(bool state) external;
}
