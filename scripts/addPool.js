const hre = require("hardhat");

async function main() {
	const Factory = await hre.ethers.getContractFactory("SingularityFactory");
	const factoryAddress = "0x7461dd01E68B11A6082A44FdE9c85a63cca134A2";
	const factory = Factory.attach(factoryAddress);

	const tokenAddress = "0x512D083d9f03d424ae4FCe15255588C246Beb28B";
	const isStablecoin = false;
	const baseFee = numToBN(0.0015);
	const tx = await factory.createPool(tokenAddress, isStablecoin, baseFee);
	await tx.wait(7);
	const poolAddress = await factory.getPool(tokenAddress);
	console.log(`${tokenAddress} pool deployed to: ${poolAddress}`);
	// await run("verify:verify", {
	// 	address: poolAddress,
	// });
}

function numToBN(number, decimals = 18) {
	return ethers.utils.parseUnits(number.toString(), decimals);
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
