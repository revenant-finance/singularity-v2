const hre = require("hardhat");

async function main() {
	const Router = await hre.ethers.getContractFactory("SingularityRouter");
	const factoryAddress = "";
	const wethAddress = "";
	const router = await Router.deploy(factoryAddress, wethAddress);
	await router.deployed();

	console.log(`Router deployed to: ${router.address}`); //

	await run("verify:verify", {
		address: router.address,
		constructorArguments: [factoryAddress, wethAddress],
	});
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
