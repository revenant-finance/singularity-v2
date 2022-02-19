const hre = require("hardhat");

async function main() {
	const [deployer] = await ethers.getSigners();
	const Factory = await hre.ethers.getContractFactory("SingularityFactory");
	const trancheName = "Safe";
	const adminAddress = deployer.address;
	const oracleAddress = "0x853C46D6DCaafBb7b52248736700db375592C521";
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
