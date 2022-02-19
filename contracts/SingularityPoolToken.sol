// SPDX-License-Identifier: No License

pragma solidity ^0.8.11;

/**
 * @title Singularity Pool Token
 * @author Revenant Labs
 * @author Modified from Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC20.sol)
 */
abstract contract SingularityPoolToken {
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    // name, symbol, decimals initialized in SingularityPool.initialize(...)
    // and are unchangeable after initialization
    string public name;
    string public symbol;
    uint8 public decimals;

    uint  public totalSupply;

    mapping(address => uint) public balanceOf;
    mapping(address => mapping(address => uint)) public allowance;

    uint256 internal immutable INITIAL_CHAIN_ID;
    bytes32 internal immutable INITIAL_DOMAIN_SEPARATOR;

    mapping(address => uint) public nonces;

    constructor() {
        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();
    }

    function approve(address spender, uint value) public virtual returns (bool) {
        allowance[msg.sender][spender] = value;

        emit Approval(msg.sender, spender, value);

        return true;
    }

    function transfer(address to, uint value) public virtual returns (bool) {
        balanceOf[msg.sender] -= value;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += value;
        }

        emit Transfer(msg.sender, to, value);

        return true;
    }

    function transferFrom(address from, address to, uint value) public virtual returns (bool) {
        uint allowed = allowance[from][msg.sender]; // Saves gas for limited approvals.

        if (allowed != type(uint).max) allowance[from][msg.sender] = allowed - value;

        balanceOf[from] -= value;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += value;
        }

        emit Transfer(from, to, value);

        return true;
    }

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) public virtual {
        require(deadline >= block.timestamp, "SingularityPoolToken: EXPIRED");

        // Unchecked because the only math done is incrementing
        // the owner's nonce which cannot realistically overflow.
        unchecked {
            bytes32 digest = keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            keccak256(
                                "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                            ),
                            owner,
                            spender,
                            value,
                            nonces[owner]++,
                            deadline
                        )
                    )
                )
            );

            address recoveredAddress = ecrecover(digest, v, r, s);

            require(recoveredAddress != address(0) && recoveredAddress == owner, "SingularityPoolToken: INVALID_SIGNER");

            allowance[recoveredAddress][spender] = value;
        }

        emit Approval(owner, spender, value);
    }

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : computeDomainSeparator();
    }

    function computeDomainSeparator() internal view virtual returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                    keccak256(bytes(name)),
                    keccak256("1"),
                    block.chainid,
                    address(this)
                )
            );
    }

    function _mint(address to, uint value) internal {
        totalSupply += value;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += value;
        }

        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint value) internal {
        balanceOf[from] -= value;

        // Cannot underflow because a user's balance
        // will never be larger than the total supply.
        unchecked {
            totalSupply -= value;
        }

        emit Transfer(from, address(0), value);
    }
}