const hre = require("hardhat");

async function main() {
	const [deployer] = await ethers.getSigners();
	const Oracle = await hre.ethers.getContractFactory("SingularityOracle");
	const adminAddress = deployer.address;
	const oracle = await Oracle.deploy(adminAddress);
	await oracle.deployed();

	console.log(`Oracle deployed to: ${oracle.address}`); // 0x6BecC50C02dEF1B4f5b0c758eCdD4449f1695a1B

	await new Promise(resolve => setTimeout(resolve, 10000));

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
