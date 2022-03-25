// SPDX-License-Identifier: No License

pragma solidity ^0.8.13;

import "./utils/ERC20.sol";

/**
 * @title Singularity DAO Token
 * @author Revenant Labs
 */

 contract SingularityToken is ERC20 {
    address admin;
    mapping(address => bool) public minters;

    constructor(address _admin) ERC20("Singularity Swap", "VOID", 18) {
        admin = _admin;
    }

    function mint(address to, uint256 amount) external {
        require(minters[msg.sender], "SingularityToken: !minter");
        _mint(to, amount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
    
    function setMinter(address minter, bool allowed) external {
        require(msg.sender == admin, "SingularityToken: !admin");
        minters[minter] = allowed;
    }

    function setAdmin(address _admin) external {
        require(msg.sender == admin, "SingularityToken: !admin");
        admin = _admin;
    }
 }