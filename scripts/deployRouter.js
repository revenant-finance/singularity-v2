const hre = require("hardhat");

async function main() {
	const Router = await hre.ethers.getContractFactory("SingularityRouter");
	const factoryAddress = "0xD6c11141Dfcc8128c0523e3837a6053CF6229b58";
	const wethAddress = "0x21be370d5312f44cb42ce377bc9b8a0cef1a4c83";
	const router = await Router.deploy(factoryAddress, wethAddress);
	await router.deployed();

	console.log(`Router deployed to: ${router.address}`);

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
