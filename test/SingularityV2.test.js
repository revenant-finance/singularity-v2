const { expect } = require("chai");
const { ethers } = require("hardhat");
const { expectRevert } = require("@openzeppelin/test-helpers");

describe("SingularityV2", () => {
	let ownerAccount, ownerAddress, otherAccount, otherAddress;
	let Factory, Router, Oracle, ERC20, Pool;
	let factory,
		router,
		oracle,
		eth,
		usdc,
		dai,
		ethPoolAddress,
		ethPool,
		usdcPoolAddress,
		usdcPool,
		daiPoolAddress,
		daiPool;
	const name = "Tranche A";
	const MAX = ethers.constants.MaxUint256;
	const ETH = { name: "Ethereum", symbol: "ETH", decimals: 18, price: 2000, balance: 1000 };
	const USDC = { name: "USD Coin", symbol: "USDC", decimals: 6, price: 1, balance: 1000000 };
	const DAI = { name: "Dai Stablecoin", symbol: "DAI", decimals: 18, price: 1, balance: 1000000 };

	function numToBN(number, decimals = 18) {
		return ethers.utils.parseUnits(number.toString(), decimals);
	}

	before(async () => {
		const accounts = await ethers.getSigners();
		[ownerAccount, otherAccount] = accounts;
		ownerAddress = await ownerAccount.getAddress();
		otherAddress = await otherAccount.getAddress();
		Factory = await ethers.getContractFactory("SingularityFactory");
		Router = await ethers.getContractFactory("SingularityRouter");
		ERC20 = await ethers.getContractFactory("ERC20");
		Oracle = await ethers.getContractFactory("Oracle");
		Pool = await ethers.getContractFactory("SingularityPool");
	});

	beforeEach(async () => {
		// deploy erc20 dummy tokens
		eth = await ERC20.deploy(ETH.name, ETH.symbol, ETH.decimals);
		await eth.deployed();
		await eth.mint(ownerAddress, numToBN(ETH.balance, ETH.decimals));

		usdc = await ERC20.deploy(USDC.name, USDC.symbol, USDC.decimals);
		await usdc.deployed();
		await usdc.mint(ownerAddress, numToBN(USDC.balance, USDC.decimals));

		dai = await ERC20.deploy(DAI.name, DAI.symbol, DAI.decimals);
		await dai.deployed();
		await dai.mint(ownerAddress, numToBN(DAI.balance, DAI.decimals));

		// deploy oracle
		oracle = await Oracle.deploy();
		await oracle.deployed();
		// set oracle prices
		await oracle.pushPrices(
			[eth.address, usdc.address, dai.address],
			[numToBN(ETH.price), numToBN(USDC.price), numToBN(DAI.price)]
		);

		// deploy factory
		factory = await Factory.deploy(name, ownerAddress, oracle.address);
		await factory.deployed();

		// deploy router
		router = await Router.deploy(factory.address, eth.address);
		await router.deployed();
		await factory.setRouter(router.address);

		// setup pools
		await factory.createPool(eth.address, "Singularity ETH Pool", "SLP ETH", numToBN(0.0015));
		ethPoolAddress = await factory.getPool(eth.address);
		ethPool = await Pool.attach(ethPoolAddress);
		await factory.createPool(usdc.address, "Singularity USDC Pool", "SLP USDC", numToBN(0.0015));
		usdcPoolAddress = await factory.getPool(usdc.address);
		usdcPool = await Pool.attach(usdcPoolAddress);
		await factory.createPool(dai.address, "Singularity DAI Pool", "SLP DAI", numToBN(0.0015));
		daiPoolAddress = await factory.getPool(dai.address);
		daiPool = await Pool.attach(daiPoolAddress);

		// set deposit caps (already tested)
		await factory.setDepositCaps([ethPoolAddress], [MAX]);
		await factory.setDepositCaps([usdcPoolAddress], [MAX]);
		await factory.setDepositCaps([daiPoolAddress], [MAX]);

		// approvals
		await eth.approve(ethPoolAddress, MAX);
		await usdc.approve(usdcPoolAddress, MAX);
		await dai.approve(daiPoolAddress, MAX);
		await eth.approve(router.address, MAX);
		await usdc.approve(router.address, MAX);
		await dai.approve(router.address, MAX);
		await ethPool.approve(router.address, MAX);
		await usdcPool.approve(router.address, MAX);
		await daiPool.approve(router.address, MAX);
	});

	it("Should have correct initial state values", async () => {
		expect(await factory.name()).to.equal(name);
		expect(await factory.admin()).to.equal(ownerAddress);
		expect(await factory.oracle()).to.equal(oracle.address);
	});

	it("Should create a pool for USDC", async () => {
		const usdcPool = await Pool.attach(usdcPoolAddress);
		expect(await usdcPool.token()).to.equal(usdc.address);
		expect(await usdcPool.name()).to.equal("Singularity USDC Pool");
		expect(await usdcPool.symbol()).to.equal("SLP USDC");
		expect(await usdcPool.decimals()).to.equal(USDC.decimals);
		expect(await usdcPool.paused()).to.equal(false);
		expect(await usdcPool.factory()).to.equal(factory.address);
	});

	it("Should mint via pool and router", async () => {
		const mintAmount = 100;
		await expect(ethPool.mint(0, ownerAddress)).to.be.revertedWith("SingularityPool: AMOUNT_IS_0");
		// mint via pool
		await ethPool.mint(numToBN(mintAmount, ETH.decimals), ownerAddress);

		expect(await eth.balanceOf(ownerAddress)).to.equal(
			numToBN(ETH.balance - mintAmount, ETH.decimals)
		);
		expect(await eth.balanceOf(ethPoolAddress)).to.equal(numToBN(mintAmount, ETH.decimals));
		expect(await ethPool.balanceOf(ownerAddress)).to.equal(numToBN(mintAmount, ETH.decimals));
		expect(await ethPool.liabilities()).to.equal(numToBN(mintAmount, ETH.decimals));
		expect(await ethPool.assets()).to.equal(numToBN(mintAmount, ETH.decimals));

		// mint via router
		await router.addLiquidity(usdc.address, numToBN(mintAmount, 6), ownerAddress, MAX);
		expect(await usdc.balanceOf(ownerAddress)).to.equal(
			numToBN(USDC.balance - mintAmount, USDC.decimals)
		);
		expect(await usdc.balanceOf(usdcPoolAddress)).to.equal(numToBN(mintAmount, USDC.decimals));
		expect(await usdcPool.balanceOf(ownerAddress)).to.equal(numToBN(mintAmount, USDC.decimals));
		expect(await usdcPool.liabilities()).to.equal(numToBN(mintAmount, USDC.decimals));
		expect(await usdcPool.assets()).to.equal(numToBN(mintAmount, USDC.decimals));
	});

	it("Should burn via pool and router", async () => {
		const mintAmount = 100;
		await ethPool.mint(numToBN(mintAmount, ETH.decimals), ownerAddress);
		// burn via pool
		await ethPool.burn(numToBN(mintAmount, ETH.decimals), ownerAddress);

		expect(await eth.balanceOf(ownerAddress)).to.equal(numToBN(ETH.balance, ETH.decimals));
		expect(await eth.balanceOf(ethPoolAddress)).to.equal(0);
		expect(await ethPool.balanceOf(ownerAddress)).to.equal(0);
		expect(await ethPool.liabilities()).to.equal(0);

		await usdcPool.mint(numToBN(mintAmount, USDC.decimals), ownerAddress);
		// burn via router
		await router.removeLiquidity(
			usdc.address,
			numToBN(mintAmount, USDC.decimals),
			0,
			ownerAddress,
			MAX
		);
		expect(await usdc.balanceOf(ownerAddress)).to.equal(numToBN(USDC.balance, USDC.decimals));
		expect(await usdc.balanceOf(usdcPoolAddress)).to.equal(0);
		expect(await usdcPool.balanceOf(ownerAddress)).to.equal(0);
		expect(await usdcPool.liabilities()).to.equal(0);
	});

	it("Should swap", async () => {
		await ethPool.mint(numToBN(1, ETH.decimals), ownerAddress);
		await usdcPool.mint(numToBN(2000, USDC.decimals), ownerAddress);

		await router.swapExactTokensForTokens(
			[eth.address, usdc.address],
			numToBN(0.1),
			0,
			ownerAddress,
			MAX
		);
	});
});
