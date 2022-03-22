const hre = require("hardhat");

async function main() {
	const [deployer] = await ethers.getSigners();
	const Oracle = await hre.ethers.getContractFactory("SingularityOracle");
	const adminAddress = deployer.address;
	const oracle = await Oracle.deploy(adminAddress);
	await oracle.deployed();

	console.log(`Oracle deployed to: ${oracle.address}`);
	
	await run("verify:verify", {
		address: oracle.address,
		constructorArguments: [adminAddress],
	});
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
