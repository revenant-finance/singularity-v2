const hre = require("hardhat");

async function main() {
	const ERC20 = await hre.ethers.getContractFactory("ERC20");
	const name = "";
	const symbol = "";
	const decimals = 18;
	const erc20 = await ERC20.deploy(name, symbol, decimals);
	await erc20.deployed();

	console.log(`${symbol} ERC20 deployed to: ${erc20.address}`); //

	await run("verify:verify", {
		address: erc20.address,
		constructorArguments: [name, symbol, decimals],
	});
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
