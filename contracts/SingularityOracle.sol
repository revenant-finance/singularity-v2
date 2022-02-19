// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import './interfaces/IOracle.sol';

/**
 * @title Singularity Oracle
 * @author Revenant Labs
 */
contract Oracle is IOracle {
	struct PriceData {
		uint256 price;
		uint256 updateTime;
		uint256 nonce;
	}
	address admin;
	mapping(address => bool) public pushers;
	mapping(address => PriceData[]) public allPrices;

	constructor(address _admin, address[] memory _pushers) {
		require(_admin != address(0), "SingularityOracle: ADMIN_IS_0");
		admin = _admin;
		for (uint i; i < _pushers.length; i++) {
			pushers[_pushers[i]] = true;
		}
	}

	function getPriceUSD(address _token) external view override returns (uint256 price, uint256 updateTime) {
		PriceData[] memory prices = allPrices[_token];
		price = prices[prices.length - 1].price;
		updateTime = prices[prices.length - 1].updateTime;
		require(price > 0, "SingularityOracle: INVALID_PRICE");
		require(updateTime > 0, "SingularityOracle: INVALID_ORACLE");
	}

	function pushPrices(address[] calldata tokens, uint256[] calldata prices) external {
		require(tokens.length == prices.length, "SingularityOracle: NOT_SAME_LENGTH");
		for(uint i; i < tokens.length; i++) {
			pushPrice(tokens[i], prices[i]);
		}
	}

	function pushPrice(address _token, uint256 _price) public {
		require(pushers[msg.sender], "SingularityOracle: NOT_PUSHER");
		PriceData[] storage prices = allPrices[_token];
		prices.push(PriceData({ price: _price, updateTime: block.timestamp, nonce: prices.length }));
	}

	function setAdmin(address _admin) external {
		require(msg.sender == admin, "SingularityOracle: NOT_ADMIN");
		require(_admin != address(0), "0");
		admin = _admin;
	}

	function setPusher(address _pusher, bool _allowed) external {
		require(msg.sender == admin, "SingularityOracle: NOT_ADMIN");
		pushers[_pusher] = _allowed;
	}
}
