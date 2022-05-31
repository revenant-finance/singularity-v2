const hre = require("hardhat");

async function main() {
	const [deployer] = await ethers.getSigners();
	const Factory = await hre.ethers.getContractFactory("SingularityFactory");
	const trancheName = "Beta v1";
	const adminAddress = deployer.address;
	const oracleAddress = "0xCf096f83D49A08F6E6c66E61E45F749e9231c22a";
	const feeToAddress = deployer.address;
	const factory = await Factory.deploy(trancheName, adminAddress, oracleAddress, feeToAddress);

	await factory.deployed();

	console.log(`Factory deployed to: ${factory.address}`);
	
	await new Promise((resolve) => setTimeout(resolve, 5000));
	await run("verify:verify", {
		address: factory.address,
		constructorArguments: [trancheName, adminAddress, oracleAddress, feeToAddress],
	});
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
