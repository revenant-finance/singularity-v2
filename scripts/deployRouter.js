const hre = require("hardhat");

async function main() {
	const Router = await hre.ethers.getContractFactory("SingularityRouter");
	const factoryAddress = "0xf029d2a894B749436BD6105676185B09B27e255D";
	const wftmAddress = "0x21be370d5312f44cb42ce377bc9b8a0cef1a4c83";
	const router = await Router.deploy(factoryAddress, wftmAddress);
	await router.deployed();

	console.log(`Router deployed to: ${router.address}`);

	await new Promise((resolve) => setTimeout(resolve, 5000));
	await run("verify:verify", {
		address: router.address,
		constructorArguments: [factoryAddress, wftmAddress],
	});
	
	const Factory = await hre.ethers.getContractFactory("SingularityFactory");
	const factory = Factory.attach(factoryAddress);
	await factory.setRouter(router.address);
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
