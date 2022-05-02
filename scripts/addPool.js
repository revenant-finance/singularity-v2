const hre = require("hardhat");

async function main() {
	const Factory = await hre.ethers.getContractFactory("SingularityFactory");
	const factoryAddress = "0x58db5a7Ea19fC170c7CD7847434Cc02a462f9D39";
	const factory = Factory.attach(factoryAddress);

	const tokens = [
		{
			name: "USDC",
			address: "0x04068da6c83afcfa0e13ba15a6696662335d5b75",
			fee: 0.0002,
			isStable: true,
			cap: numToBN(100000, 6),
		},
		{
			name: "fUSDT",
			address: "0x049d68029688eabf473097a2fc38ef61633a3c7a",
			fee: 0.0002,
			isStable: true,
			cap: numToBN(100000, 6),
		},
		{
			name: "DAI",
			address: "0x8d11ec38a3eb5e956b052f67da8bdc9bef8abf3e",
			fee: 0.0002,
			isStable: true,
			cap: numToBN(100000, 18),
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

	await factory.setDepositCaps(
		[tokens[0].address, tokens[1].address, tokens[2].address],
		[tokens[0].cap, tokens[1].cap, tokens[2].cap]
	);
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
