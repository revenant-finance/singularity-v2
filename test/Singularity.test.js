const { expect } = require("chai");
const { ethers } = require("hardhat");
const { expectRevert } = require("@openzeppelin/test-helpers");

describe("SingularityV2", () => {
	let ownerAccount, ownerAddress, otherAccount, otherAddress;
	let Factory, Oracle, ERC20, Pool;
	let factory, oracle, eth, usdc;
	const MAX = ethers.constants.MaxUint256;
	const ETH = { name: "Ethereum", symbol: "ETH", decimals: 18 };
	const USDC = { name: "USD Coin", symbol: "USDC", decimals: 6 };

	function numToBN(number, decimals = 18) {
		return ethers.utils.parseUnits(number.toString(), decimals);
	}

	before(async () => {
		const accounts = await ethers.getSigners();
		[ownerAccount, otherAccount] = accounts;
		ownerAddress = await ownerAccount.getAddress();
		otherAddress = await otherAccount.getAddress();
		Factory = await ethers.getContractFactory("SingularityFactory");
		ERC20 = await ethers.getContractFactory("ERC20");
		Oracle = await ethers.getContractFactory("Oracle");
		Pool = await ethers.getContractFactory("SingularityPool");
	});

	beforeEach(async () => {
		// deploy erc20 dummy tokens
		eth = await ERC20.deploy(ETH.name, ETH.symbol, ETH.decimals);
		await eth.deployed();
		await eth.mint(ownerAddress, ethers.utils.parseEther("1000"));

		usdc = await ERC20.deploy(USDC.name, USDC.symbol, USDC.decimals);
		await usdc.deployed();
		await usdc.mint(ownerAddress, ethers.utils.parseUnits("1000", 6));
		// deploy oracle
		oracle = await Oracle.deploy();
		await oracle.deployed();
		// set oracle prices
		await oracle.pushPrices([eth.address, usdc.address], [numToBN(2000), numToBN(1)]);

		// deploy factory
		factory = await Factory.deploy(ownerAddress, oracle.address);
		await factory.deployed();
	});

	it("Should have correct initial state values", async () => {
		expect(await factory.admin()).to.equal(ownerAddress);
		expect(await factory.oracle()).to.equal(oracle.address);
	});

	it("Should create a pool for ETH and USDC", async () => {
		await factory.createPool(usdc.address, "Singularity USDC Pool", "SLP USDC");
		const usdcPoolAddress = await factory.getPool(usdc.address);
		const usdcPool = await Pool.attach(usdcPoolAddress);
		expect(await usdcPool.token()).to.equal(usdc.address);
		expect(await usdcPool.name()).to.equal("Singularity USDC Pool");
		expect(await usdcPool.symbol()).to.equal("SLP USDC");
		expect(await usdcPool.decimals()).to.equal(USDC.decimals);
		expect(await usdcPool.paused()).to.equal(false);
		expect(await usdcPool.factory()).to.equal(factory.address);
	});

	it("Should mint for ETH and USDC", async () => {
		await factory.createPool(eth.address, "Singularity ETH Pool", "SLP ETH");
		const ethPoolAddress = await factory.getPool(eth.address);
		const ethPool = await Pool.attach(ethPoolAddress);
		await expect(ethPool.mint(numToBN(100, ETH.decimals), ownerAddress)).to.be.revertedWith(
			"SingularityPair: MINT_EXCEEDS_CAP"
		);
		await factory.setDepositCaps([ethPoolAddress], [MAX]);
		await eth.approve(ethPoolAddress, MAX);
		await expect(ethPool.mint(0, ownerAddress)).to.be.revertedWith("SingularityPair: AMOUNT_IS_0");
		await ethPool.mint(numToBN(100, ETH.decimals), ownerAddress);

		expect(await eth.balanceOf(ownerAddress)).to.equal(numToBN(900, ETH.decimals));
		expect(await eth.balanceOf(ethPoolAddress)).to.equal(numToBN(100, ETH.decimals));
		expect(await ethPool.balanceOf(ownerAddress)).to.equal(numToBN(100, ETH.decimals));
		expect(await ethPool.deposits()).to.equal(numToBN(100, ETH.decimals));
		expect(await ethPool.debts()).to.equal(0);

		await factory.createPool(usdc.address, "Singularity USDC Pool", "SLP USDC");
		const usdcPoolAddress = await factory.getPool(usdc.address);
		const usdcPool = await Pool.attach(usdcPoolAddress);
		await factory.setDepositCaps([usdcPoolAddress], [MAX]);
		await usdc.approve(usdcPoolAddress, MAX);
		await usdcPool.mint(numToBN(100, 6), ownerAddress);

		expect(await usdc.balanceOf(ownerAddress)).to.equal(numToBN(900, USDC.decimals));
		expect(await usdc.balanceOf(usdcPoolAddress)).to.equal(numToBN(100, USDC.decimals));
		expect(await usdcPool.balanceOf(ownerAddress)).to.equal(numToBN(100, USDC.decimals));
		expect(await usdcPool.deposits()).to.equal(numToBN(100, USDC.decimals));
		expect(await usdcPool.debts()).to.equal(0);
	});

	it("Should burn LP for ETH and USDC", async () => {
		await factory.createPool(eth.address, "Singularity ETH Pool", "SLP ETH");
		const ethPoolAddress = await factory.getPool(eth.address);
		const ethPool = await Pool.attach(ethPoolAddress);
		await factory.setDepositCaps([ethPoolAddress], [MAX]);
		await eth.approve(ethPoolAddress, MAX);
		await ethPool.mint(numToBN(100, ETH.decimals), ownerAddress);
		await ethPool.burn(numToBN(100, ETH.decimals), ownerAddress);

		expect(await eth.balanceOf(ownerAddress)).to.equal(numToBN(1000, ETH.decimals));
		expect(await eth.balanceOf(ethPoolAddress)).to.equal(0);
		expect(await ethPool.balanceOf(ownerAddress)).to.equal(0);
		expect(await ethPool.deposits()).to.equal(0);

		await factory.createPool(usdc.address, "Singularity USDC Pool", "SLP USDC");
		const usdcPoolAddress = await factory.getPool(usdc.address);
		const usdcPool = await Pool.attach(usdcPoolAddress);
		await factory.setDepositCaps([usdcPoolAddress], [MAX]);
		await usdc.approve(usdcPoolAddress, MAX);
		await usdcPool.mint(numToBN(100, USDC.decimals), ownerAddress);
		await usdcPool.burn(numToBN(100, USDC.decimals), ownerAddress);

		expect(await usdc.balanceOf(ownerAddress)).to.equal(numToBN(1000, USDC.decimals));
		expect(await usdc.balanceOf(usdcPoolAddress)).to.equal(0);
		expect(await usdcPool.balanceOf(ownerAddress)).to.equal(0);
		expect(await usdcPool.deposits()).to.equal(0);
	});
});
