const hre = require("hardhat");

async function main() {
	const Router = await hre.ethers.getContractFactory("SingularityRouter");
	const factoryAddress = "0x7461dd01E68B11A6082A44FdE9c85a63cca134A2";
	const wftmAddress = "0x21be370d5312f44cb42ce377bc9b8a0cef1a4c83";
	const router = await Router.deploy(factoryAddress, wftmAddress);
	await router.deployed();

	console.log(`Router deployed to: ${router.address}`);

	await new Promise((resolve) => setTimeout(resolve, 5000));
	await run("verify:verify", {
		address: router.address,
		constructorArguments: [factoryAddress, wftmAddress],
	});
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
