// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import './interfaces/IOracle.sol';
import './interfaces/IChainlinkOracle.sol';

contract Oracle is IOracle {
	struct PriceData {
		uint256 price;
		uint256 updateTime;
		uint256 nonce;
	}
	address admin;
	mapping(address => bool) public pushers;
	mapping(address => PriceData[]) public allPrices;

	constructor() {
		admin = msg.sender;
		pushers[msg.sender] = true;
	}

	function getPriceUSD(address token_) external view override returns (uint256 price) {
		PriceData[] memory prices = allPrices[token_];
		return prices[prices.length - 1].price;
	}

	function pushPrices(address[] calldata tokens, uint256[] calldata prices) external {
		require(tokens.length == prices.length, "!same length");
		for(uint i; i < tokens.length; i++) {
			pushPrice(tokens[i], prices[i]);
		}
	}

	function pushPrice(address token_, uint256 price_) public {
		require(pushers[msg.sender], '!pusher');
		PriceData[] storage prices = allPrices[token_];
		prices.push(PriceData({ price: price_, updateTime: block.timestamp, nonce: prices.length }));
	}

	function setAdmin(address admin_) external {
		require(msg.sender == admin, "!admin");
		admin = admin_;
	}

	function setPusher(address pusher_, bool allowed_) external {
		require(msg.sender == admin, "!admin");
		pushers[pusher_] = allowed_;
	}
}
