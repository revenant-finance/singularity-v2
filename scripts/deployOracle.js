const hre = require("hardhat");

async function main() {
	const [deployer] = await ethers.getSigners();
	const Oracle = await hre.ethers.getContractFactory("Oracle");
	const adminAddress = deployer.address;
	const pushers = [deployer.address];
	const oracle = await Oracle.deploy(adminAddress, pushers);
	await oracle.deployed();

	console.log(`Oracle deployed to: ${oracle.address}`); //

	await run("verify:verify", {
		address: oracle.address,
		constructorArguments: [adminAddress, pushers],
	});
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
