const hre = require("hardhat");

async function main() {
	const [deployer] = await ethers.getSigners();
	const Factory = await hre.ethers.getContractFactory("SingularityFactory");
	const trancheName = "Test Tranche";
	const adminAddress = deployer.address;
	const oracleAddress = "0xE34EeD58d8e042868f83e3e0075B48CeFC097B75";
	const feeToAddress = deployer.address;
	const factory = await Factory.deploy(trancheName, adminAddress, oracleAddress, feeToAddress);

	await factory.deployed();

	console.log(`Factory deployed to: ${factory.address}`);

	await new Promise(resolve => setTimeout(resolve, 10000));

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
