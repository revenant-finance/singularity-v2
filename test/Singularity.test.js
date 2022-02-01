const { expect } = require("chai");
const { ethers } = require("hardhat");
const { expectRevert } = require("@openzeppelin/test-helpers");

describe("Singularity", () => {
	let ownerAccount, ownerAddress, otherAccount, otherAddress;
	let Factory, Router, Oracle, ERC20, Pair;
	let factory, router, oracle, eth, usdc, dai;
	const ONE = ethers.utils.parseEther("1");
	const TEN = ethers.utils.parseEther("10");
	const MAX = ethers.constants.MaxUint256;

	before(async () => {
		const accounts = await ethers.getSigners();
		[ownerAccount, otherAccount] = accounts;
		ownerAddress = await ownerAccount.getAddress();
		otherAddress = await otherAccount.getAddress();
		Factory = await ethers.getContractFactory("SingularityFactory");
		Router = await ethers.getContractFactory("SingularityRouter");
		ERC20 = await ethers.getContractFactory("ERC20");
		Oracle = await ethers.getContractFactory("TestOracle");
		Pair = await ethers.getContractFactory("SingularityPair");
	});

	beforeEach(async () => {
		// deploy erc20 dummy tokens
		eth = await ERC20.deploy("Ethereum", "ETH", 18);
		await eth.deployed();
		await eth.mint(ownerAddress, ethers.utils.parseEther("100000000"));
		usdc = await ERC20.deploy("USDC", "USDC", 6);
		await usdc.deployed();
		await usdc.mint(ownerAddress, ethers.utils.parseUnits("100000000", 6));
		dai = await ERC20.deploy("DAI", "DAI", 18);
		await dai.deployed();
		await dai.mint(ownerAddress, ethers.utils.parseEther("100000000"));
		// deploy oracle
		oracle = await Oracle.deploy();
		await oracle.deployed();
		// set oracle prices
		await oracle.setOracle(eth.address, ethers.utils.parseUnits("4000", 8));
		await oracle.setOracle(usdc.address, ethers.utils.parseUnits("1", 8));
		await oracle.setOracle(dai.address, ethers.utils.parseUnits("1", 8));

		// deploy factory
		factory = await Factory.deploy(ownerAddress, oracle.address);
		await factory.deployed();

		// deploy router
		router = await Router.deploy(factory.address, eth.address);
		await router.deployed();
	});

	it("Should have correct initial state values", async () => {
		expect(await factory.admin()).to.equal(ownerAddress);
		expect(await factory.oracle()).to.equal(oracle.address);
	});

	it("Should create a pair", async () => {
		await factory.createPair(eth.address, usdc.address, 50, 0);
		const pairAddress = await factory.getPair(eth.address, usdc.address);
		const pair = await Pair.attach(pairAddress);
		expect(await pair.amplitude()).to.equal(50);
		const tokens =
			eth.address < usdc.address ? [eth.address, usdc.address] : [usdc.address, eth.address];
		expect(await pair.token0()).to.equal(tokens[0]);
		expect(await pair.token1()).to.equal(tokens[1]);
		const decimals = eth.address < usdc.address ? [10 ** 12, 1] : [1, 10 ** 12];
		expect(await pair.decimals0()).to.equal(decimals[0]);
		expect(await pair.decimals1()).to.equal(decimals[1]);
	});

	it("Should add liquidity", async () => {
		await factory.createPair(eth.address, usdc.address, 50, 0);
		await eth.approve(router.address, MAX);
		await usdc.approve(router.address, MAX);
		await router.addLiquidity(
			eth.address,
			usdc.address,
			TEN,
			ethers.utils.parseUnits("40000", 6),
			0,
			ownerAddress,
			MAX
		);
		const pairAddress = await factory.getPair(eth.address, usdc.address);
		const pair = await Pair.attach(pairAddress);
		const reserves = await pair.getReserves();
		expect(reserves._reserve0).to.equal(ethers.utils.parseUnits("40000", 6));
		expect(reserves._reserve1).to.equal(TEN);
		expect(await pair.balanceOf(ownerAddress)).to.gt("0");
		await router.addLiquidity(
			eth.address,
			usdc.address,
			TEN,
			ethers.utils.parseUnits("40000", 6),
			0,
			ownerAddress,
			MAX
		);
		await router.addLiquidity(
			eth.address,
			usdc.address,
			TEN,
			ethers.utils.parseUnits("0", 6),
			0,
			ownerAddress,
			MAX
		);
		await router.addLiquidity(
			eth.address,
			usdc.address,
			0,
			ethers.utils.parseUnits("40000", 6),
			0,
			ownerAddress,
			MAX
		);
	});

	it("Should add liquidity multiple times", async () => {
		await factory.createPair(eth.address, usdc.address, 50, 0);
		await eth.approve(router.address, MAX);
		await usdc.approve(router.address, MAX);
		const pairAddress = await factory.getPair(eth.address, usdc.address);
		const pair = await Pair.attach(pairAddress);
		await router.addLiquidity(
			eth.address,
			usdc.address,
			TEN,
			ethers.utils.parseUnits("40000", 6),
			0,
			ownerAddress,
			MAX
		);
		const lpBal1 = ethers.utils.formatUnits(await pair.balanceOf(ownerAddress), 6);
		await router.addLiquidity(
			eth.address,
			usdc.address,
			ONE,
			ethers.utils.parseUnits("4000", 6),
			0,
			ownerAddress,
			MAX
		);
		const lpBal2 = ethers.utils.formatUnits(await pair.balanceOf(ownerAddress), 6) - lpBal1;
		expect((lpBal2 / lpBal1).toFixed(1)).to.equal("0.1");
	});

	it("Should remove liquidity", async () => {
		await factory.createPair(eth.address, usdc.address, 50, 0);
		await eth.approve(router.address, MAX);
		await usdc.approve(router.address, MAX);
		await router.addLiquidity(
			eth.address,
			usdc.address,
			TEN,
			ethers.utils.parseUnits("40000", 6),
			0,
			ownerAddress,
			MAX
		);
		const pairAddress = await factory.getPair(eth.address, usdc.address);
		const pair = await Pair.attach(pairAddress);
		expect(await pair.balanceOf(ownerAddress)).to.gt("0");
		await pair.approve(router.address, MAX);
		const liquidity = await pair.balanceOf(ownerAddress);
		await router.removeLiquidity(eth.address, usdc.address, liquidity, 0, 0, ownerAddress, MAX);
		expect(await pair.balanceOf(ownerAddress)).to.equal("0");
		expect(await eth.balanceOf(ownerAddress)).to.gt(ethers.utils.parseEther("999000"));
		expect(await usdc.balanceOf(ownerAddress)).to.gt(ethers.utils.parseUnits("999000", 6));
	});

	it("Should return amount in and amount out (and calculate fee)", async () => {
		const fee = 0.1;
		await factory.createPair(
			eth.address,
			usdc.address,
			50,
			ethers.utils.parseEther(fee.toString())
		);
		await eth.approve(router.address, MAX);
		await usdc.approve(router.address, MAX);
		await router.addLiquidity(
			eth.address,
			usdc.address,
			TEN,
			ethers.utils.parseUnits("40000", 6),
			0,
			ownerAddress,
			MAX
		);
		const path = [eth.address, usdc.address];
		const amountOut = (await router.getAmountsOut(ONE, path))[1];
		expect(parseFloat(ethers.utils.formatUnits(amountOut, 6))).to.gt(3948 * (1 - fee));
		const amountIn = (await router.getAmountsIn(ethers.utils.parseUnits("3948", 6), path))[0];
		expect(parseFloat(ethers.utils.formatUnits(amountIn, 18))).to.gt(0.99 / (1 - fee));
	});

	it("Should swap exact ETH for USDC", async () => {
		await factory.createPair(eth.address, usdc.address, 50, 0);
		await eth.approve(router.address, MAX);
		await usdc.approve(router.address, MAX);
		await router.addLiquidity(
			eth.address,
			usdc.address,
			TEN,
			ethers.utils.parseUnits("40000", 6),
			0,
			ownerAddress,
			MAX
		);
		const balanceBefore = await usdc.balanceOf(ownerAddress);
		await router.swapExactTokensForTokens(
			[eth.address, usdc.address],
			ONE,
			ethers.utils.parseUnits("3948", 6),
			ownerAddress,
			MAX
		);
		const amountReceived = (await usdc.balanceOf(ownerAddress)).sub(balanceBefore);
		expect(parseFloat(ethers.utils.formatUnits(amountReceived, 6))).to.gt(3948);
	});

	it("Should swap exact USDC for ETH", async () => {
		await factory.createPair(eth.address, usdc.address, 50, 0);
		await eth.approve(router.address, MAX);
		await usdc.approve(router.address, MAX);
		await router.addLiquidity(
			eth.address,
			usdc.address,
			TEN,
			ethers.utils.parseUnits("40000", 6),
			0,
			ownerAddress,
			MAX
		);
		const balanceBefore = await eth.balanceOf(ownerAddress);
		await router.swapExactTokensForTokens(
			[usdc.address, eth.address],
			ethers.utils.parseUnits("4000", 6),
			ethers.utils.parseEther("0.98"),
			ownerAddress,
			MAX
		);
		const amountReceived = (await eth.balanceOf(ownerAddress)).sub(balanceBefore);
		expect(parseFloat(ethers.utils.formatUnits(amountReceived, 6))).to.gt(0.98);
	});

	it("Should swap exact ETH for USDC, accumulate admin fees, and collect fees", async () => {
		await factory.setFeeTo(otherAddress);
		await factory.createPair(eth.address, usdc.address, 50, ethers.utils.parseEther("0.1"));
		await eth.approve(router.address, MAX);
		await usdc.approve(router.address, MAX);
		await router.addLiquidity(
			eth.address,
			usdc.address,
			TEN,
			ethers.utils.parseUnits("40000", 6),
			0,
			ownerAddress,
			MAX
		);
		await router.swapExactTokensForTokens([eth.address, usdc.address], ONE, 0, ownerAddress, MAX);
		const pairAddress = await factory.getPair(eth.address, usdc.address);
		const pair = await Pair.attach(pairAddress);
		const token0Fees = parseFloat(ethers.utils.formatEther(await pair.token0Fees()));
		const token1Fees = parseFloat(ethers.utils.formatEther(await pair.token1Fees(), 6));
		await factory.collectFees([pairAddress]);
		const postToken0Fees = parseFloat(ethers.utils.formatEther(await pair.token0Fees()));
		const postToken1Fees = parseFloat(ethers.utils.formatEther(await pair.token1Fees(), 6));
		expect(postToken0Fees).to.equal(0);
		expect(postToken1Fees).to.equal(0);
		const collectedToken0Fees = await eth.balanceOf(otherAddress);
		const collectedToken1Fees = await usdc.balanceOf(otherAddress);
		expect(parseFloat(ethers.utils.formatEther(collectedToken0Fees))).to.equal((1 * 0.1) / 6);
		expect(parseFloat(ethers.utils.formatEther(collectedToken1Fees, 6))).to.equal(0);
	});

	// it("Should test random values for swap exact", async () => {
	// 	await factory.createPair(dai.address, usdc.address, 1000, 0);
	// 	await dai.approve(router.address, MAX);
	// 	await usdc.approve(router.address, MAX);
	// 	await router.addLiquidity(
	// 		dai.address,
	// 		usdc.address,
	// 		ethers.utils.parseEther("75000000"),
	// 		ethers.utils.parseUnits("75000000", 6),
	// 		0,
	// 		ownerAddress,
	// 		MAX
	// 	);
	// 	for await (i of Array.from(Array(100).keys())) {
	// 		const rand1 = (Math.random() * 500000 + 1).toFixed();
	// 		const rand2 = (Math.random() * 500000 + 1).toFixed();
	// 		console.log(`run: ${i}, rand1: ${rand1}, rand2: ${rand2}`);
	// 		const amt = ethers.utils.parseUnits(rand1, 6);
	// 		await router.swapExactTokensForTokens([usdc.address, dai.address], amt, 0, ownerAddress, MAX);
	// 		await router.swapExactTokensForTokens(
	// 			[dai.address, usdc.address],
	// 			ethers.utils.parseUnits(rand2, 18),
	// 			0,
	// 			ownerAddress,
	// 			MAX
	// 		);
	// 	}
	// });

	// it("Should test random values for swap to exact", async () => {
	// 	await factory.createPair(dai.address, usdc.address, 1000, 0);
	// 	await dai.approve(router.address, MAX);
	// 	await usdc.approve(router.address, MAX);
	// 	await router.addLiquidity(
	// 		dai.address,
	// 		usdc.address,
	// 		ethers.utils.parseEther("75000000"),
	// 		ethers.utils.parseUnits("75000000", 6),
	// 		0,
	// 		ownerAddress,
	// 		MAX
	// 	);
	// 	for await (i of Array.from(Array(100).keys())) {
	// 		const rand1 = (Math.random() * 500000 + 1).toFixed();
	// 		const rand2 = (Math.random() * 500000 + 1).toFixed();
	// 		console.log(`run: ${i}, rand1: ${rand1}, rand2: ${rand2}`);
	// 		const amt = ethers.utils.parseUnits(rand1, 18);
	// 		await router.swapTokensForExactTokens(
	// 			[usdc.address, dai.address],
	// 			amt,
	// 			MAX,
	// 			ownerAddress,
	// 			MAX
	// 		);
	// 		await router.swapTokensForExactTokens(
	// 			[dai.address, usdc.address],
	// 			ethers.utils.parseUnits(rand2, 6),
	// 			MAX,
	// 			ownerAddress,
	// 			MAX
	// 		);
	// 	}
	// });
});
