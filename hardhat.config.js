require("dotenv").config();

require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-waffle");
require("hardhat-gas-reporter");
require("solidity-coverage");

module.exports = {
	solidity: {
		version: "0.8.11",
		settings: {
			optimizer: {
				enabled: true,
				runs: 200,
			},
		},
	},
	optimizer: {
		enabled: true,
		runs: 200,
	},
	networks: {
		hardhat: {
			initialBaseFeePerGas: 0, // workaround from https://github.com/sc-forks/solidity-coverage/issues/652#issuecomment-896330136 . Remove when that issue is closed.
		},
		ropsten: {
			url: process.env.ROPSTEN_URL || "",
			accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
		},
		ftm: {
			url: "https://rpc.ftm.tools",
			accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
		},
	},
	gasReporter: {
		enabled: true,
		currency: "USD",
		token: "FTM",
		coinmarketcap: "cba8a113-8f85-4dd7-838d-f50a59231e28",
		excludeContracts: ["testing/"],
		gasPriceApi: "https://api.ftmscan.com/api?module=proxy&action=eth_gasPrice",
	},
	etherscan: {
		apiKey: process.env.ETHERSCAN_API_KEY,
	},
};
