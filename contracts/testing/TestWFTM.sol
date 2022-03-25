// SPDX-License-Identifier: No License

pragma solidity ^0.8.13;

import "./TestERC20.sol";

contract WFTM is TestERC20 {
    // Error Code: No error.
    uint256 public constant ERR_NO_ERROR = 0x0;

    // Error Code: Non-zero value expected to perform the function.
    uint256 public constant ERR_INVALID_ZERO_VALUE = 0x01;

    // create instance of the wFTM token
    constructor () TestERC20("Wrapped FTM", "WFTM", 18) {
    }

    // deposit wraps received FTM tokens as wFTM in 1:1 ratio by minting
    // the received amount of FTMs in wFTM on the sender's address.
    function deposit() public payable returns (uint256) {
        // there has to be some value to be converted
        if (msg.value == 0) {
            return ERR_INVALID_ZERO_VALUE;
        }

        // we already received FTMs, mint the appropriate amount of wFTM
        TestERC20(address(this)).mint(msg.sender, msg.value);

        // all went well here
        return ERR_NO_ERROR;
    }

    // withdraw unwraps FTM tokens by burning specified amount
    // of wFTM from the caller address and sending the same amount
    // of FTMs back in exchange.
    function withdraw(uint256 amount) public returns (uint256) {
        // there has to be some value to be converted
        if (amount == 0) {
            return ERR_INVALID_ZERO_VALUE;
        }

        // burn wFTM from the sender first to prevent re-entrance issue
        TestERC20(address(this)).burn(msg.sender, amount);

        // if wFTM were burned, transfer native tokens back to the sender
        payable(msg.sender).transfer(amount);

        // all went well here
        return ERR_NO_ERROR;
    }
}