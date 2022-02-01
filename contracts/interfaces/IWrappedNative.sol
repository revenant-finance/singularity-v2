pragma solidity ^0.8.10;

interface IWrappedNative {
    function deposit() external payable;
    function withdraw(uint) external;
}