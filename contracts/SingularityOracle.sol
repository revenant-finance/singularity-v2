// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "./interfaces/ISingularityOracle.sol";
import "./interfaces/IChainlinkFeed.sol";

/**
 * @title Singularity Oracle
 * @author 0xEntropy
 */
contract SingularityOracle is ISingularityOracle {
    struct PriceData {
        uint256 price;
        uint256 updatedAt;
    }

    bool public onlyUseChainlink;
    address public admin;
    uint256 public maxPriceTolerance = 0.015 ether; // 1.5%

    mapping(address => bool) public pushers;
    mapping(address => PriceData) public allPrices;
    mapping(address => address) public chainlinkFeeds;

    constructor(address _admin) {
        require(_admin != address(0), "SingularityOracle: ADMIN_IS_0");
        admin = _admin;
    }

    /// @dev Validates price is within bounds of reported Chainlink price
    function getLatestRound(address token) public view override returns (uint256 price, uint256 updatedAt) {
        (uint256 chainlinkPrice, uint256 _updatedAt) = _getChainlinkData(token);
        require(chainlinkPrice != 0, "SingularityOracle: CHAINLINK_PRICE_IS_0");
        if (onlyUseChainlink) {
            return (chainlinkPrice, _updatedAt);
        }

        PriceData memory priceData = allPrices[token];
        price = priceData.price;
        updatedAt = priceData.updatedAt;
        uint256 priceDiff = price > chainlinkPrice ? price - chainlinkPrice : chainlinkPrice - price;
        uint256 percentDiff = (priceDiff * 1 ether) / price;
        require(percentDiff <= maxPriceTolerance, "SingularityOracle: PRICE_DIFF_EXCEEDS_TOLERANCE");
    }

    function getLatestRounds(address[] calldata tokens)
        external
        view
        override
        returns (uint256[] memory prices, uint256[] memory updatedAts)
    {
        prices = new uint256[](tokens.length);
        updatedAts = new uint256[](tokens.length);
        for (uint256 i; i < tokens.length; ) {
            (uint256 price, uint256 updatedAt) = getLatestRound(tokens[i]);
            prices[i] = price;
            updatedAts[i] = updatedAt;
            unchecked {
                ++i;
            }
        }
    }

    function pushPrice(address _token, uint256 _price, uint256 _timestamp) public {
        require(pushers[msg.sender], "SingularityOracle: NOT_PUSHER");
        require(_price != 0, "SingularityOracle: PRICE_IS_0");
        allPrices[_token] = PriceData({price: _price, updatedAt: _timestamp});
    }

    function pushPrices(address[] calldata tokens, uint256[] calldata prices, uint256[] calldata timestamps) external {
        require(tokens.length == prices.length, "SingularityOracle: NOT_SAME_LENGTH");
        for (uint256 i; i < tokens.length; ) {
            pushPrice(tokens[i], prices[i], timestamps[i]);
            unchecked {
                ++i;
            }
        }
    }

    function setOnlyUseChainlink(bool _onlyUseChainlink) external {
        require(msg.sender == admin, "SingularityOracle: NOT_ADMIN");
        onlyUseChainlink = _onlyUseChainlink;
    }

    function setMaxPriceTolerance(uint256 _maxPriceTolerance) external {
        require(msg.sender == admin, "SingularityOracle: NOT_ADMIN");
        require(_maxPriceTolerance != 0 && maxPriceTolerance <= 0.05 ether, "SingularityOracle: OUT_OF_BOUNDS");
        maxPriceTolerance = _maxPriceTolerance;
    }

    function setChainlinkFeed(address token, address feed) public {
        require(msg.sender == admin, "SingularityOracle: NOT_ADMIN");
        require(feed != address(0), "SingularityOracle: CHAINLINK_FEED_IS_0");
        chainlinkFeeds[token] = feed;
    }

    function setChainlinkFeeds(address[] calldata tokens, address[] calldata feeds) external {
        require(tokens.length == feeds.length, "SingularityOracle: NOT_SAME_LENGTH");
        for (uint256 i; i < tokens.length; ) {
            setChainlinkFeed(tokens[i], feeds[i]);
            unchecked {
                ++i;
            }
        }
    }

    function setAdmin(address _admin) external {
        require(msg.sender == admin, "SingularityOracle: NOT_ADMIN");
        require(_admin != address(0), "SingularityOracle: ADMIN_IS_0");
        admin = _admin;
    }

    function setPusher(address _pusher, bool _allowed) external {
        require(msg.sender == admin, "SingularityOracle: NOT_ADMIN");
        pushers[_pusher] = _allowed;
    }

    function _getChainlinkData(address token) internal view returns (uint256, uint256) {
        require(chainlinkFeeds[token] != address(0), "SingularityOracle: CHAINLINK_FEED_IS_0");
        (, int256 answer, , uint256 updatedAt, ) = IChainlinkFeed(chainlinkFeeds[token]).latestRoundData();
        uint256 rawLatestAnswer = uint256(answer);
        uint8 decimals = IChainlinkFeed(chainlinkFeeds[token]).decimals();
        uint256 price;
        if (decimals <= 18) {
            price = rawLatestAnswer * 10**(18 - decimals);
        } else {
            price = rawLatestAnswer / 10**(decimals - 18);
        }

        return (price, updatedAt);
    }
}
