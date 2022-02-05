const hre = require("hardhat");

async function main() {
	const [deployer] = await ethers.getSigners();
	console.log(`Deployer address: ${deployer.address}`);
	const deployerBalance = await deployer.getBalance();
	console.log(`Deployer balance: ${deployerBalance}`);

	const provider = deployer.provider;
	const network = await provider.getNetwork();
	console.log(`Network: ${network.name} with chainId ${network.chainId}`);
	const Oracle = await hre.ethers.getContractFactory("Oracle");
	const oracle = await Oracle.deploy();

	await oracle.deployed();

	console.log("OracleV2 deployed to:", oracle.address); //

	await run("verify:verify", {
		address: oracle.address,
		constructorArguments: [],
	});
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
