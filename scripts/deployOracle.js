const hre = require("hardhat");

async function main() {
	const [deployer] = await ethers.getSigners();
	const Oracle = await hre.ethers.getContractFactory("SingularityOracle");
	const adminAddress = deployer.address;
	const oracle = await Oracle.deploy(adminAddress);
	await oracle.deployed();

	console.log(`Oracle deployed to: ${oracle.address}`);

	await new Promise((resolve) => setTimeout(resolve, 5000));
	await run("verify:verify", {
		address: oracle.address,
		constructorArguments: [adminAddress],
	});

	let tx = await oracle.setOnlyUseChainlink(true);
	await tx.wait(10);

	const usdc = "0x69bbAcD89dB2588e8213Be96D4f88888b3D74B0c";
	const btc = "0xfe95A6188E2C6FF991600bC43f1B119BC11EE5f6";
	const eth = "0x512D083d9f03d424ae4FCe15255588C246Beb28B";

	const usdcFeed = "0x2553f4eeb82d5A26427b8d1106C51499CBa5D99c";
	const btcFeed = "0x8e94C22142F4A64b99022ccDd994f4e9EC86E4B4";
	const ethFeed = "0x11DdD3d147E5b83D01cee7070027092397d63658";
	tx = await oracle.setChainlinkFeeds([usdc, btc, eth], [usdcFeed, btcFeed, ethFeed]);
	await tx.wait(10);
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
