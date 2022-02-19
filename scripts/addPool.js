const hre = require("hardhat");

async function main() {
	const Factory = await hre.ethers.getContractFactory("SingularityFactory");
	const factoryAddress = "";
	const factory = await Factory.attach(factoryAddress);

	const tokenAddress = "";
	const isStablecoin = false;
	const baseFee = numToBN(0.0015);
	const tx = await factory.createPool(tokenAddress, isStablecoin, baseFee);
	await tx.wait(7);
	const poolAddress = await factory.getPool(tokenAddress);
	console.log(`${tokenAddress} pool deployed to: ${poolAddress}`);
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
