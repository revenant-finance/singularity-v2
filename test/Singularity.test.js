const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Singularity Swap", () => {
	let ownerAccount, ownerAddress, otherAccount, otherAddress;
	let Factory, Router, Oracle, ERC20, Pool, Wftm;
	let factory, router, oracle, wftm, eth, usdc, dai;
	const trancheName = "Tranche A";
	const MAX = ethers.constants.MaxUint256;
	const ZERO_ADDR = ethers.constants.AddressZero;
	const WFTM = {
		address: "",
		name: "Wrapped FTM",
		symbol: "wFTM",
		decimals: 18,
		price: 2,
		baseFee: numToBN(0.0015),
		poolAddress: "",
		pool: "",
	};
	const ETH = {
		address: "",
		name: "Ethereum",
		symbol: "ETH",
		decimals: 18,
		price: 2000,
		balance: 1000,
		baseFee: numToBN(0.0015),
		poolAddress: "",
		pool: "",
	};
	const USDC = {
		address: "",
		name: "USD Coin",
		symbol: "USDC",
		decimals: 6,
		price: 1,
		balance: 1000000,
		baseFee: numToBN(0.0015),
		poolAddress: "",
		pool: "",
	};
	const DAI = {
		address: "",
		name: "Dai Stablecoin",
		symbol: "DAI",
		decimals: 21,
		price: 1,
		balance: 1000000,
		baseFee: numToBN(0.0015),
		poolAddress: "",
		pool: "",
	};
	const amountToSwap = 1;

	function numToBN(number, decimals = 18) {
		return ethers.utils.parseUnits(number.toString(), decimals);
	}

	async function deployTestTokens() {
		// deploy wFTM
		wftm = await Wftm.deploy();
		await wftm.deployed();
		WFTM.address = wftm.address;

		// deploy erc20 dummy tokens
		eth = await ERC20.deploy(ETH.name, ETH.symbol, ETH.decimals);
		await eth.deployed();
		ETH.address = eth.address;
		await eth.mint(ownerAddress, numToBN(ETH.balance, ETH.decimals));

		usdc = await ERC20.deploy(USDC.name, USDC.symbol, USDC.decimals);
		await usdc.deployed();
		USDC.address = usdc.address;
		await usdc.mint(ownerAddress, numToBN(USDC.balance, USDC.decimals));

		dai = await ERC20.deploy(DAI.name, DAI.symbol, DAI.decimals);
		await dai.deployed();
		DAI.address = dai.address;
		await dai.mint(ownerAddress, numToBN(DAI.balance, DAI.decimals));
	}

	async function createPool(asset) {
		await factory.createPool(asset.address, false, asset.baseFee);
		asset.poolAddress = await factory.getPool(asset.address);
		asset.pool = await Pool.attach(asset.poolAddress);
	}

	async function updatePrices() {
		await oracle.pushPrices(
			[wftm.address, eth.address, usdc.address, dai.address],
			[numToBN(WFTM.price), numToBN(ETH.price), numToBN(USDC.price), numToBN(DAI.price)]
		);
	}

	async function getFtmBalance() {
		return await ethers.provider.getBalance(ownerAddress);
	}

	async function addLiquidity(asset, amount) {
		await router.addLiquidity(asset.address, numToBN(amount, asset.decimals), 0, ownerAddress, MAX);
	}

	before(async () => {
		const accounts = await ethers.getSigners();
		[ownerAccount, otherAccount] = accounts;
		ownerAddress = await ownerAccount.getAddress();
		otherAddress = await otherAccount.getAddress();
		Factory = await ethers.getContractFactory("SingularityFactory");
		Router = await ethers.getContractFactory("SingularityRouter");
		Oracle = await ethers.getContractFactory("SingularityOracle");
		Pool = await ethers.getContractFactory("SingularityPool");
		ERC20 = await ethers.getContractFactory("ERC20");
		Wftm = await ethers.getContractFactory("WFTM");
	});

	beforeEach(async () => {
		await deployTestTokens();

		// deploy oracle
		oracle = await Oracle.deploy(ownerAddress);
		await oracle.deployed();
		await oracle.setPusher(ownerAddress, true);

		// set oracle prices
		await updatePrices();

		// deploy factory
		factory = await Factory.deploy(trancheName, ownerAddress, oracle.address, ownerAddress);
		await factory.deployed();

		// deploy router
		router = await Router.deploy(factory.address, WFTM.address);
		await router.deployed();
		await factory.setRouter(router.address);

		await createPool(WFTM);
		await createPool(ETH);
		await createPool(USDC);

		// set deposit caps
		await factory.setDepositCaps(
			[WFTM.poolAddress, ETH.poolAddress, USDC.poolAddress],
			[MAX, MAX, MAX]
		);

		// Approve pools
		await wftm.approve(WFTM.poolAddress, MAX);
		await eth.approve(ETH.poolAddress, MAX);
		await usdc.approve(USDC.poolAddress, MAX);
		// Approve router
		await wftm.approve(router.address, MAX);
		await eth.approve(router.address, MAX);
		await usdc.approve(router.address, MAX);
		await dai.approve(router.address, MAX);
		await WFTM.pool.approve(router.address, MAX);
		await ETH.pool.approve(router.address, MAX);
		await USDC.pool.approve(router.address, MAX);
	});

	it("Should have correct initial state values", async () => {
		// Factory
		expect(await factory.tranche()).to.equal(trancheName);
		expect(await factory.admin()).to.equal(ownerAddress);
		expect(await factory.oracle()).to.equal(oracle.address);
		expect(await factory.feeTo()).to.equal(ownerAddress);
		expect(await factory.router()).to.equal(router.address);

		// Router
		expect(await router.factory()).to.equal(factory.address);
		expect(await router.WETH()).to.equal(WFTM.address);
	});

	it("Should create pool correct pool values", async () => {
		await expect(factory.createPool(ZERO_ADDR, true, DAI.baseFee)).to.be.revertedWith(
			"SingularityFactory: ZERO_ADDRESS"
		);
		await expect(factory.createPool(WFTM.address, true, WFTM.baseFee)).to.be.revertedWith(
			"SingularityFactory: POOL_EXISTS"
		);
		await expect(factory.createPool(DAI.address, true, 0)).to.be.revertedWith(
			"SingularityFactory: FEE_IS_0"
		);
		await factory.createPool(DAI.address, true, DAI.baseFee);
		DAI.poolAddress = await factory.getPool(DAI.address);
		DAI.pool = await Pool.attach(DAI.poolAddress);

		expect(await DAI.pool.paused()).to.equal(false);
		expect(await DAI.pool.factory()).to.equal(factory.address);
		expect(await DAI.pool.token()).to.equal(DAI.address);
		expect(await DAI.pool.isStablecoin()).to.equal(true);
		expect(await DAI.pool.depositCap()).to.equal(0);
		expect(await DAI.pool.assets()).to.equal(0);
		expect(await DAI.pool.liabilities()).to.equal(0);
		expect(await DAI.pool.baseFee()).to.equal(DAI.baseFee);
		expect(await DAI.pool.adminFees()).to.equal(0);
		expect(await DAI.pool.lockedFees()).to.equal(0);
		expect(await DAI.pool.name()).to.equal(`Singularity ${DAI.symbol} Pool (${trancheName})`);
		expect(await DAI.pool.symbol()).to.equal(`SPT-${DAI.symbol} (${trancheName})`);
		expect(await DAI.pool.decimals()).to.equal(DAI.decimals);
		expect(await DAI.pool.getCollateralizationRatio()).to.equal(MAX);
		expect(await DAI.pool.getPricePerShare()).to.equal(numToBN(1));
		expect((await DAI.pool.getOracleData())[0]).to.equal(numToBN(DAI.price));
		expect(await DAI.pool.getAmountToUSD(numToBN(1, DAI.decimals))).to.equal(numToBN(DAI.price));
		expect(await DAI.pool.getUSDToAmount(numToBN(DAI.price))).to.equal(numToBN(1, DAI.decimals));
	});

	it("Should add liquidity", async () => {
		const mintAmount = 100;
		await expect(
			USDC.pool.deposit(numToBN(mintAmount, USDC.decimals), ownerAddress)
		).to.be.revertedWith("SingularityPool: NOT_ROUTER");
		await expect(
			router.addLiquidity(
				usdc.address,
				numToBN(mintAmount, 6),
				numToBN(mintAmount + 1, 6),
				ownerAddress,
				MAX
			)
		).to.be.revertedWith("SingularityRouter: INSUFFICIENT_LIQUIDITY_AMOUNT");
		await factory.setDepositCaps([USDC.poolAddress], [numToBN(50, USDC.decimals)]);
		await expect(
			router.addLiquidity(usdc.address, numToBN(mintAmount, 6), 0, ownerAddress, MAX)
		).to.be.revertedWith("SingularityPool: DEPOSIT_EXCEEDS_CAP");
		await factory.setDepositCaps([USDC.poolAddress], [MAX]);

		await addLiquidity(USDC, mintAmount);
		expect(await usdc.balanceOf(ownerAddress)).to.equal(
			numToBN(USDC.balance - mintAmount, USDC.decimals)
		);
		expect(await usdc.balanceOf(USDC.poolAddress)).to.equal(numToBN(mintAmount, USDC.decimals));
		expect(await USDC.pool.balanceOf(ownerAddress)).to.equal(numToBN(mintAmount, USDC.decimals));
		expect(await USDC.pool.liabilities()).to.equal(numToBN(mintAmount, USDC.decimals));
		expect(await USDC.pool.assets()).to.equal(numToBN(mintAmount, USDC.decimals));
		expect(await USDC.pool.getCollateralizationRatio()).to.equal(numToBN(1));

		const ftmBal = await getFtmBalance();
		await router.addLiquidityETH(0, ownerAddress, MAX, { value: numToBN(mintAmount) });
		const ftmBalDiff = ftmBal.sub(await getFtmBalance());
		expect(ftmBalDiff).to.be.closeTo(numToBN(mintAmount), numToBN(1, 16));
	});

	it("Should remove liquidity", async () => {
		const mintAmount = 100;
		await addLiquidity(USDC, mintAmount);
		await expect(router.removeLiquidity(usdc.address, 0, 0, ownerAddress, MAX)).to.be.revertedWith(
			"SingularityPool: AMOUNT_IS_0"
		);
		await expect(
			router.removeLiquidity(
				usdc.address,
				numToBN(mintAmount, USDC.decimals),
				numToBN(mintAmount + 1, USDC.decimals),
				ownerAddress,
				MAX
			)
		).to.be.revertedWith("SingularityRouter: INSUFFICIENT_TOKEN_AMOUNT");
		await router.removeLiquidity(
			usdc.address,
			numToBN(mintAmount, USDC.decimals),
			0,
			ownerAddress,
			MAX
		);
		expect(await usdc.balanceOf(ownerAddress)).to.equal(numToBN(USDC.balance, USDC.decimals));
		expect(await usdc.balanceOf(USDC.poolAddress)).to.equal(0);
		expect(await USDC.pool.balanceOf(ownerAddress)).to.equal(0);
		expect(await USDC.pool.liabilities()).to.equal(0);

		await router.addLiquidityETH(0, ownerAddress, MAX, { value: numToBN(mintAmount) });
		const ftmBal = await getFtmBalance();
		await router.removeLiquidityETH(numToBN(mintAmount), 0, ownerAddress, MAX);
		const ftmBalDiff = (await getFtmBalance()).sub(ftmBal);
		expect(ftmBalDiff).to.be.closeTo(numToBN(mintAmount), numToBN(1, 16));
	});

	it("Should swapExactTokensForTokens", async () => {
		await addLiquidity(ETH, 100);
		await addLiquidity(USDC, 2000);

		const ethBal = await eth.balanceOf(ownerAddress);
		const usdcBal = await usdc.balanceOf(ownerAddress);
		const expectedOut = await router.getAmountOut(
			numToBN(amountToSwap, ETH.decimals),
			eth.address,
			usdc.address
		);
		await router.swapExactTokensForTokens(
			eth.address,
			usdc.address,
			numToBN(amountToSwap, ETH.decimals),
			0,
			ownerAddress,
			MAX
		);
		const ethBalAfter = await eth.balanceOf(ownerAddress);
		const usdcBalAfter = await usdc.balanceOf(ownerAddress);
		const usdcBought = usdcBalAfter.sub(usdcBal);
		const ethSpent = ethBal.sub(ethBalAfter);
		expect(usdcBought).to.be.closeTo(expectedOut, numToBN(1, USDC.decimals));
		expect(ethSpent).to.equal(numToBN(amountToSwap, ETH.decimals));
		expect(await ETH.pool.getPricePerShare()).to.be.gt(numToBN(1));
		expect(await USDC.pool.getPricePerShare()).to.be.gt(numToBN(1));
	});

	it("Should swapExactETHForTokens", async () => {
		await wftm.deposit({ value: numToBN(1000) });
		await addLiquidity(WFTM, 1000);
		await addLiquidity(USDC, 2000);

		const ftmBal = await getFtmBalance();
		const usdcBal = await usdc.balanceOf(ownerAddress);
		const expectedOut = await router.getAmountOut(
			numToBN(amountToSwap, WFTM.decimals),
			wftm.address,
			usdc.address
		);
		await router.swapExactETHForTokens(wftm.address, usdc.address, 0, ownerAddress, MAX, {
			value: numToBN(amountToSwap, WFTM.decimals),
		});
		const ftmBalAfter = await getFtmBalance();
		const usdcBalAfter = await usdc.balanceOf(ownerAddress);
		const ftmSpent = ftmBal.sub(ftmBalAfter);
		const usdcBought = usdcBalAfter.sub(usdcBal);
		expect(usdcBought).to.be.closeTo(expectedOut, numToBN(1, USDC.decimals));
		expect(ftmSpent).to.be.closeTo(numToBN(amountToSwap, WFTM.decimals), numToBN(1, 16)); // account for gas cost
	});

	it("Should swapExactTokensForETH", async () => {
		await wftm.deposit({ value: numToBN(1000) });
		await addLiquidity(WFTM, 1000);
		await addLiquidity(USDC, 2000);

		const ftmBal = await getFtmBalance();
		const usdcBal = await usdc.balanceOf(ownerAddress);
		const expectedOut = await router.getAmountOut(
			numToBN(amountToSwap, USDC.decimals),
			usdc.address,
			wftm.address
		);
		await router.swapExactTokensForETH(
			usdc.address,
			wftm.address,
			numToBN(amountToSwap, USDC.decimals),
			0,
			ownerAddress,
			MAX
		);
		const ftmBalAfter = await getFtmBalance();
		const usdcBalAfter = await usdc.balanceOf(ownerAddress);
		const usdcSpent = usdcBal.sub(usdcBalAfter);
		const ftmBought = ftmBalAfter.sub(ftmBal);
		expect(usdcSpent).to.equal(numToBN(amountToSwap, USDC.decimals));
		expect(ftmBought).to.be.closeTo(expectedOut, numToBN(1, 16)); // account for gas cost
	});
});
