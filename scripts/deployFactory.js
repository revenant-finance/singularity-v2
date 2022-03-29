const hre = require("hardhat");

async function main() {
	const [deployer] = await ethers.getSigners();
	const Factory = await hre.ethers.getContractFactory("SingularityFactory");
	const trancheName = "Test Tranche v4";
	const adminAddress = deployer.address;
	const oracleAddress = "0xC659b3879eD5B3079D5B7Fb89801143E6C1fD8Fa";
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
