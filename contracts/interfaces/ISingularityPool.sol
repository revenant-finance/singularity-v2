// SPDX-License-Identifier: No License

pragma solidity ^0.8.15;

import "./ISingularityPoolToken.sol";

interface ISingularityPool is ISingularityPoolToken {
    event Deposit(address indexed sender, uint256 indexed amountDeposited, uint256 mintAmount, address indexed to);
    event Withdraw(address indexed sender, uint256 indexed amountBurned, uint256 withdrawalAmount, address indexed to);
    event SwapIn(address indexed sender, uint256 amountIn, uint256 amountOut);
    event SwapOut(address indexed sender, uint256 amountIn, uint256 amountOut, address indexed to);
    event CollectFees(uint256 protocolFees);
    event SetDepositCap(uint256 oldValue, uint256 newValue);
    event SetBaseFee(uint256 oldValue, uint256 newValue);
    event SetPaused(bool oldState, bool newState);

    function paused() external view returns (bool);

    function isStablecoin() external view returns (bool);

    function factory() external view returns (address);

    function token() external view returns (address);

    function depositCap() external view returns (uint256);

    function assets() external view returns (uint256);

    function liabilities() external view returns (uint256);

    function protocolFees() external view returns (uint256);

    function baseFee() external view returns (uint256);

    function deposit(uint256 amount, address to) external returns (uint256);

    function withdraw(uint256 lpAmount, address to) external returns (uint256);

    function swapIn(uint256 amountIn) external returns (uint256);

    function swapOut(uint256 amountIn, address to) external returns (uint256);

    function getPricePerShare() external view returns (uint256);

    function getCollateralizationRatio() external view returns (uint256);

    function getOracleData() external view returns (uint256, uint256);

    function getAmountToUSD(uint256 amount) external view returns (uint256);

    function getUSDToAmount(uint256 value) external view returns (uint256);

    function getDepositFee(uint256 amount) external view returns (uint256);

    function getWithdrawalFee(uint256 amount) external view returns (uint256);

    function getSlippageIn(uint256 amount) external view returns (uint256);

    function getSlippageOut(uint256 amount) external view returns (uint256);

    function getTradingFeeRate() external view returns (uint256 tradingFeeRate);

    function getTradingFees(uint256 amount)
        external
        view
        returns (
            uint256,
            uint256,
            uint256
        );

    function collectFees(address feeTo) external;

    function setDepositCap(uint256 newDepositCap) external;

    function setBaseFee(uint256 newBaseFee) external;

    function setPaused(bool state) external;
}
