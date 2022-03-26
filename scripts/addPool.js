const hre = require("hardhat");

async function main() {
	const Factory = await hre.ethers.getContractFactory("SingularityFactory");
	const factoryAddress = "0x03bfA93B0582D38FC8E453cDaA5C718e4301842C";
	const factory = Factory.attach(factoryAddress);

	const tokens = [
		{
			name: "testUSDC",
			address: "0x69bbAcD89dB2588e8213Be96D4f88888b3D74B0c",
			fee: 0.0004,
		},
		{
			name: "testBTC",
			address: "0xfe95A6188E2C6FF991600bC43f1B119BC11EE5f6",
			fee: 0.0015,
		},
		{
			name: "testETH",
			address: "0x512D083d9f03d424ae4FCe15255588C246Beb28B",
			fee: 0.0015,
		},
	];
	for (let i = 0; i < tokens.length; i++) {
		const tokenAddress = tokens[i].address;
		const isStablecoin = false;
		const baseFee = numToBN(tokens[i].fee);
		const tx = await factory.createPool(tokenAddress, isStablecoin, baseFee);
		await tx.wait(10);
		const poolAddress = await factory.getPool(tokenAddress);
		console.log(`${tokenAddress} pool deployed to: ${poolAddress}`);
	}
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
