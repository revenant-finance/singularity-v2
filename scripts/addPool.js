const hre = require("hardhat");

async function main() {
	const Factory = await hre.ethers.getContractFactory("SingularityFactory");
	const factoryAddress = "0x4A762D217a88955ed29e330F90b7D155d7C7cd56";
	const factory = Factory.attach(factoryAddress);

	const tokens = [
		// {
		// 	name: "testUSDC",
		// 	address: "0x69bbAcD89dB2588e8213Be96D4f88888b3D74B0c",
		// 	fee: 0.0002,
		// 	isStable: true,
		// 	cap: numToBN(5000000, 6),
		// },
		// {
		// 	name: "testBTC",
		// 	address: "0xfe95A6188E2C6FF991600bC43f1B119BC11EE5f6",
		// 	fee: 0.00075,
		// 	isStable: false,
		// 	cap: numToBN(100, 8),
		// },
		{
			name: "testETH",
			address: "0x512D083d9f03d424ae4FCe15255588C246Beb28B",
			fee: 0.00075,
			isStable: false,
			cap: numToBN(1000),
		},
	];
	for (let i = 0; i < tokens.length; i++) {
		const tokenAddress = tokens[i].address;
		const isStablecoin = tokens[i].isStable;
		const baseFee = numToBN(tokens[i].fee);
		let tx = await factory.createPool(tokenAddress, isStablecoin, baseFee);
		await tx.wait(10);
		const poolAddress = await factory.getPool(tokenAddress);
		console.log(`${tokenAddress} pool deployed to: ${poolAddress}`);
	}

	// await factory.setDepositCaps(
	// 	[tokens[0].address, tokens[1].address, tokens[2].address],
	// 	[tokens[0].cap, tokens[1].cap, tokens[2].cap]
	// );
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
