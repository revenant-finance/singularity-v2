const { expect } = require("chai");
const { ethers } = require("hardhat");
const ethjs = require("ethereumjs-util");

describe("Singularity Swap", () => {
  let ownerAccount, ownerAddress, otherAccount, otherAddress;
  let Factory, Router, Oracle, ChainlinkFeed, ERC20, Pool, Wftm;
  let factory, router, oracle, wftm, eth, usdc, dai;
  let wftmFeed, ethFeed, usdcFeed, daiFeed;

  const PERMIT_TYPEHASH = ethers.utils.keccak256(
    ethers.utils.toUtf8Bytes(
      "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
    )
  );
  const chainId = 31337;
  const trancheName = "Tranche A";
  const MAX = ethers.constants.MaxUint256;
  const ZERO_ADDR = ethers.constants.AddressZero;
  const WFTM = {
    address: "",
    name: "Wrapped FTM",
    symbol: "wFTM",
    decimals: 18,
    price: 2,
    balance: 100000,
    isStablecoin: false,
    baseFee: 0.0015,
    poolAddress: "",
    pool: "",
  };
  const ETH = {
    address: "",
    name: "Ethereum",
    symbol: "ETH",
    decimals: 18,
    price: 2000,
    balance: 100000,
    isStablecoin: false,
    baseFee: 0.0015,
    poolAddress: "",
    pool: "",
  };
  const USDC = {
    address: "",
    name: "USD Coin",
    symbol: "USDC",
    decimals: 6,
    price: 1,
    balance: 100000,
    isStablecoin: true,
    baseFee: 0.0004,
    poolAddress: "",
    pool: "",
  };
  const DAI = {
    address: "",
    name: "Dai Stablecoin",
    symbol: "DAI",
    decimals: 18,
    price: 1,
    balance: 100000,
    isStablecoin: true,
    baseFee: 0.0004,
    poolAddress: "",
    pool: "",
  };
  const amountToSwap = 0.5;
  const amountToMint = 100;

  function numToBN(number, decimals = 18) {
    return ethers.utils.parseUnits(number.toString(), decimals);
  }

  function bnToNum(bn, decimals = 18) {
    return ethers.utils.formatUnits(bn, decimals);
  }

  function advanceTime(seconds) {
    ethers.provider.send("evm_increaseTime", [seconds]);
    ethers.provider.send("evm_mine");
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
    await factory.createPool(asset.address, asset.isStablecoin, numToBN(asset.baseFee));
    asset.poolAddress = await factory.getPool(asset.address);
    asset.pool = await Pool.attach(asset.poolAddress);
  }

  async function updatePrices() {
    await oracle.pushPrices(
      [wftm.address, eth.address, usdc.address, dai.address],
      [numToBN(WFTM.price), numToBN(ETH.price), numToBN(USDC.price), numToBN(DAI.price)]
    );

    wftmFeed = await ChainlinkFeed.deploy(numToBN(WFTM.price, 8));
    await wftmFeed.deployed();
    await oracle.setChainlinkFeed(wftm.address, wftmFeed.address);

    ethFeed = await ChainlinkFeed.deploy(numToBN(ETH.price, 8));
    await ethFeed.deployed();
    await oracle.setChainlinkFeed(eth.address, ethFeed.address);

    usdcFeed = await ChainlinkFeed.deploy(numToBN(USDC.price, 8));
    await usdcFeed.deployed();
    await oracle.setChainlinkFeed(usdc.address, usdcFeed.address);

    daiFeed = await ChainlinkFeed.deploy(numToBN(DAI.price, 8));
    await daiFeed.deployed();
    await oracle.setChainlinkFeed(dai.address, daiFeed.address);
  }

  async function getFtmBalance() {
    return await ethers.provider.getBalance(ownerAddress);
  }

  async function addLiquidity(asset, amount) {
    await router.addLiquidity(asset.address, numToBN(amount, asset.decimals), 0, ownerAddress, MAX);
  }

  function getDomainSeparator(name, tokenAddress) {
    return ethers.utils.keccak256(
      ethers.utils.defaultAbiCoder.encode(
        ["bytes32", "bytes32", "bytes32", "uint256", "address"],
        [
          ethers.utils.keccak256(
            ethers.utils.toUtf8Bytes(
              "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
            )
          ),
          ethers.utils.keccak256(ethers.utils.toUtf8Bytes(name)),
          ethers.utils.keccak256(ethers.utils.toUtf8Bytes("1")),
          chainId,
          tokenAddress,
        ]
      )
    );
  }

  function getApprovalDigest(token, approve, nonce, deadline) {
    const DOMAIN_SEPARATOR = getDomainSeparator(token.name, token.address);
    return ethers.utils.keccak256(
      ethers.utils.solidityPack(
        ["bytes1", "bytes1", "bytes32", "bytes32"],
        [
          "0x19",
          "0x01",
          DOMAIN_SEPARATOR,
          ethers.utils.keccak256(
            ethers.utils.defaultAbiCoder.encode(
              ["bytes32", "address", "address", "uint256", "uint256", "uint256"],
              [PERMIT_TYPEHASH, approve.owner, approve.spender, approve.value, nonce, deadline]
            )
          ),
        ]
      )
    );
  }

  before(async () => {
    const accounts = await ethers.getSigners();
    [ownerAccount, otherAccount] = accounts;
    ownerAddress = await ownerAccount.getAddress();
    otherAddress = await otherAccount.getAddress();
    Factory = await ethers.getContractFactory("SingularityFactory");
    Router = await ethers.getContractFactory("SingularityRouter");
    Oracle = await ethers.getContractFactory("SingularityOracle");
    ChainlinkFeed = await ethers.getContractFactory("TestChainlinkFeed");
    Pool = await ethers.getContractFactory("SingularityPool");
    ERC20 = await ethers.getContractFactory("TestERC20");
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
    factory = await Factory.deploy(trancheName, ownerAddress, oracle.address, otherAddress);
    await factory.deployed();

    // deploy router
    router = await Router.deploy(factory.address, WFTM.address);
    await router.deployed();
    await factory.setRouter(router.address);

    await createPool(WFTM);
    await createPool(ETH);
    await createPool(USDC);

    // set deposit caps
    await factory.setDepositCaps([WFTM.address, ETH.address, USDC.address], [MAX, MAX, MAX]);

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

  it("Should have correct view return values", async () => {
    // Factory
    expect(await factory.tranche()).to.equal(trancheName);
    expect(await factory.admin()).to.equal(ownerAddress);
    expect(await factory.oracle()).to.equal(oracle.address);
    expect(await factory.feeTo()).to.equal(otherAddress);
    expect(await factory.router()).to.equal(router.address);
    expect(await factory.allPoolsLength()).to.equal(3);

    // Router
    expect(await router.factory()).to.equal(factory.address);
    expect(await router.WETH()).to.equal(WFTM.address);

    expect(await router.poolCodeHash()).to.equal(await factory.poolCodeHash());
    expect(await router.poolFor(wftm.address)).to.equal(await factory.getPool(wftm.address));
  });

  it("createPool", async () => {
    await expect(
      factory.createPool(ZERO_ADDR, DAI.isStablecoin, numToBN(DAI.baseFee))
    ).to.be.revertedWith("SingularityFactory: ZERO_ADDRESS");
    await expect(
      factory.createPool(WFTM.address, DAI.isStablecoin, numToBN(WFTM.baseFee))
    ).to.be.revertedWith("SingularityFactory: POOL_EXISTS");
    await expect(factory.createPool(DAI.address, DAI.isStablecoin, 0)).to.be.revertedWith(
      "SingularityFactory: FEE_IS_0"
    );
    await factory.createPool(DAI.address, DAI.isStablecoin, numToBN(DAI.baseFee));
    DAI.poolAddress = await factory.getPool(DAI.address);
    DAI.pool = await Pool.attach(DAI.poolAddress);

    expect(await DAI.pool.paused()).to.equal(false);
    expect(await DAI.pool.factory()).to.equal(factory.address);
    expect(await DAI.pool.token()).to.equal(DAI.address);
    expect(await DAI.pool.isStablecoin()).to.equal(DAI.isStablecoin);
    expect(await DAI.pool.depositCap()).to.equal(0);
    expect(await DAI.pool.assets()).to.equal(0);
    expect(await DAI.pool.liabilities()).to.equal(0);
    expect(await DAI.pool.baseFee()).to.equal(numToBN(DAI.baseFee));
    expect(await DAI.pool.protocolFees()).to.equal(0);
    expect(await DAI.pool.name()).to.equal(`Singularity Pool Token-${DAI.symbol} (${trancheName})`);
    expect(await DAI.pool.symbol()).to.equal(`SPT-${DAI.symbol} (${trancheName})`);
    expect(await DAI.pool.decimals()).to.equal(DAI.decimals);
    expect(await DAI.pool.totalSupply()).to.equal(0);
    expect(await DAI.pool.balanceOf(ownerAddress)).to.equal(0);
    expect(await DAI.pool.nonces(ownerAddress)).to.equal(0);
    expect(await DAI.pool.DOMAIN_SEPARATOR()).to.equal(
      getDomainSeparator(`Singularity Pool Token-${DAI.symbol} (${trancheName})`, DAI.poolAddress)
    );
    expect(await DAI.pool.getPricePerShare()).to.equal(numToBN(1));
    expect((await DAI.pool.getAssetsAndLiabilities())[0]).to.equal(0);
    expect((await DAI.pool.getAssetsAndLiabilities())[1]).to.equal(0);
    expect(await DAI.pool.getCollateralizationRatio()).to.equal(numToBN(1));
    await oracle.pushPrices([DAI.address], [numToBN(0.01)]);
    await expect(DAI.pool.getOracleData()).to.be.revertedWith(
      "SingularityOracle: PRICE_DIFF_EXCEEDS_TOLERANCE"
    );
    await oracle.pushPrices([DAI.address], [numToBN(DAI.price)]);
    expect((await DAI.pool.getOracleData())[0]).to.equal(numToBN(DAI.price));
    expect(await DAI.pool.getAmountToUSD(numToBN(1, DAI.decimals))).to.equal(numToBN(DAI.price));
    expect(await DAI.pool.getUSDToAmount(numToBN(DAI.price))).to.equal(numToBN(1, DAI.decimals));
  });

  it("addLiquidity", async () => {
    await factory.setPausedForAll(true);
    await expect(
      router.addLiquidity(usdc.address, numToBN(amountToMint, 6), 0, ownerAddress, MAX)
    ).to.be.revertedWith("SingularityPool: PAUSED");
    await factory.setPausedForAll(false);
    await expect(router.addLiquidity(usdc.address, 0, 0, ownerAddress, MAX)).to.be.revertedWith(
      "SingularityPool: AMOUNT_IS_0"
    );
    await expect(
      router.addLiquidity(
        usdc.address,
        numToBN(amountToMint, 6),
        numToBN(amountToMint + 1, 6),
        ownerAddress,
        MAX
      )
    ).to.be.revertedWith("SingularityRouter: INSUFFICIENT_LIQUIDITY_AMOUNT");
    await factory.setDepositCaps([USDC.address], [numToBN(50, USDC.decimals)]);
    await expect(
      router.addLiquidity(usdc.address, numToBN(amountToMint, 6), 0, ownerAddress, MAX)
    ).to.be.revertedWith("SingularityPool: DEPOSIT_EXCEEDS_CAP");
    await factory.setDepositCaps([USDC.address], [MAX]);

    expect(await USDC.pool.getDepositFee(numToBN(amountToMint, USDC.decimals))).to.equal(0);
    const expectedLpBal = await router.getAddLiquidityAmount(
      USDC.address,
      numToBN(amountToMint, 6)
    );
    await addLiquidity(USDC, amountToMint);
    const lpBal = await USDC.pool.balanceOf(ownerAddress);
    expect(expectedLpBal).to.equal(lpBal);
    expect(await usdc.balanceOf(ownerAddress)).to.equal(
      numToBN(USDC.balance - amountToMint, USDC.decimals)
    );
    expect(await usdc.balanceOf(USDC.poolAddress)).to.equal(numToBN(amountToMint, USDC.decimals));
    expect(await USDC.pool.balanceOf(ownerAddress)).to.equal(numToBN(amountToMint, USDC.decimals));
    expect(await USDC.pool.liabilities()).to.equal(numToBN(amountToMint, USDC.decimals));
    expect(await USDC.pool.assets()).to.equal(numToBN(amountToMint, USDC.decimals));
    const expectedLpBal2 = await router.getAddLiquidityAmount(
      usdc.address,
      numToBN(amountToMint, 6)
    );
    await addLiquidity(USDC, amountToMint);
    const lpBal2 = await USDC.pool.balanceOf(ownerAddress);
    expect(expectedLpBal.add(expectedLpBal2)).to.equal(lpBal2);

    expect(await usdc.balanceOf(USDC.poolAddress)).to.equal(
      numToBN(amountToMint * 2, USDC.decimals)
    );
    expect(await USDC.pool.balanceOf(ownerAddress)).to.equal(
      numToBN(amountToMint * 2, USDC.decimals)
    );
    expect(await USDC.pool.liabilities()).to.equal(numToBN(amountToMint * 2, USDC.decimals));
    expect(await USDC.pool.assets()).to.equal(numToBN(amountToMint * 2, USDC.decimals));

    // Test pool token functionality
    await USDC.pool.transfer(otherAddress, numToBN(1, USDC.decimals));
    await expect(
      USDC.pool.transferFrom(ownerAddress, otherAddress, numToBN(1, USDC.decimals))
    ).to.be.revertedWith("");

    const name = await USDC.pool.name();
    const nonce = await USDC.pool.nonces(ownerAddress);
    const digest = getApprovalDigest(
      { name: name, address: USDC.poolAddress },
      { owner: ownerAddress, spender: otherAddress, value: MAX },
      nonce,
      0
    );
    const { v, r, s } = ethjs.ecsign(
      Buffer.from(digest.slice(2), "hex"),
      Buffer.from(
        "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80".slice(2),
        "hex"
      )
    );
    await expect(
      USDC.pool.permit(ownerAddress, otherAddress, MAX, nonce, v, r, s)
    ).to.be.revertedWith("SingularityPoolToken: EXPIRED");
  });

  it("addLiquidityETH", async () => {
    const ftmBal = await getFtmBalance();
    await router.addLiquidityETH(0, ownerAddress, MAX, {
      value: numToBN(amountToMint),
    });
    const ftmBalDiff = ftmBal.sub(await getFtmBalance());
    expect(ftmBalDiff).to.be.closeTo(numToBN(amountToMint), numToBN(1, 16));
  });

  it("removeLiquidity", async () => {
    await addLiquidity(USDC, amountToMint);
    await expect(router.removeLiquidity(usdc.address, 0, 0, ownerAddress, MAX)).to.be.revertedWith(
      "SingularityPool: AMOUNT_IS_0"
    );

    await expect(
      router.removeLiquidity(
        usdc.address,
        numToBN(amountToMint / 2, USDC.decimals),
        numToBN(amountToMint + 1, USDC.decimals),
        ownerAddress,
        MAX
      )
    ).to.be.revertedWith("SingularityRouter: INSUFFICIENT_TOKEN_AMOUNT");
    await factory.setPausedForAll(true);
    await expect(
      router.removeLiquidity(
        usdc.address,
        numToBN(amountToMint, USDC.decimals),
        0,
        ownerAddress,
        MAX
      )
    ).to.be.revertedWith("SingularityPool: PAUSED");
    await factory.setPausedForAll(false);
    const lpBal = await USDC.pool.balanceOf(ownerAddress);
    const firstHalf = lpBal.div(2);
    const secondHalf = lpBal.sub(firstHalf);
    const expectedBal = await router.getRemoveLiquidityAmount(
      usdc.address,
      numToBN(amountToMint / 2, USDC.decimals)
    );
    const balBefore = await usdc.balanceOf(ownerAddress);
    await router.removeLiquidity(usdc.address, firstHalf, 0, ownerAddress, MAX);
    const balAfter = await usdc.balanceOf(ownerAddress);
    expect(expectedBal).to.equal(balAfter.sub(balBefore));
    await router.removeLiquidity(usdc.address, secondHalf, 0, ownerAddress, MAX);
    const protocolFees = await USDC.pool.protocolFees();
    const [_assets, _liabilities] = await USDC.pool.getAssetsAndLiabilities();
    const usdcPoolBal = await usdc.balanceOf(USDC.poolAddress);
    expect(await usdc.balanceOf(ownerAddress)).to.be.equal(
      numToBN(USDC.balance, USDC.decimals) - protocolFees
    );
    expect(usdcPoolBal).to.equal(protocolFees);
    expect(await USDC.pool.balanceOf(ownerAddress)).to.equal(0);
    expect(await USDC.pool.assets()).to.equal(usdcPoolBal.sub(protocolFees));
    expect(_liabilities).to.equal(0);
    expect(await USDC.pool.liabilities()).to.equal(0);
  });

  it("removeLiquidityETH", async () => {
    await router.addLiquidityETH(0, ownerAddress, MAX, {
      value: numToBN(amountToMint),
    });
    const ftmBal = await getFtmBalance();
    await router.removeLiquidityETH(numToBN(amountToMint), 0, ownerAddress, MAX);
    const ftmBalDiff = (await getFtmBalance()).sub(ftmBal);
    expect(ftmBalDiff).to.be.closeTo(numToBN(amountToMint), numToBN(1, 16));
  });

  it("removeLiquidityWithPermit", async () => {
    await addLiquidity(USDC, amountToMint);
    const name = await USDC.pool.name();
    const nonce = await USDC.pool.nonces(ownerAddress);
    const digest = getApprovalDigest(
      { name: name, address: USDC.poolAddress },
      { owner: ownerAddress, spender: router.address, value: MAX },
      nonce,
      MAX
    );
    const { v, r, s } = ethjs.ecsign(
      Buffer.from(digest.slice(2), "hex"),
      Buffer.from(
        "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80".slice(2),
        "hex"
      )
    );
    await router.removeLiquidityWithPermit(
      usdc.address,
      numToBN(amountToMint, USDC.decimals),
      0,
      ownerAddress,
      MAX,
      true,
      v,
      r,
      s
    );
  });

  it("removeLiquidityETHWithPermit", async () => {
    await router.addLiquidityETH(0, ownerAddress, MAX, {
      value: numToBN(amountToMint),
    });
    const name = await WFTM.pool.name();
    const nonce = await WFTM.pool.nonces(ownerAddress);
    const digest = getApprovalDigest(
      { name: name, address: WFTM.poolAddress },
      { owner: ownerAddress, spender: router.address, value: MAX },
      nonce,
      MAX
    );
    const { v, r, s } = ethjs.ecsign(
      Buffer.from(digest.slice(2), "hex"),
      Buffer.from(
        "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80".slice(2),
        "hex"
      )
    );
    await router.removeLiquidityETHWithPermit(
      numToBN(amountToMint),
      0,
      ownerAddress,
      MAX,
      true,
      v,
      r,
      s
    );
  });

  it("getSlippageIn & getSlippageOut", async () => {
    await addLiquidity(ETH, 10);
    await addLiquidity(USDC, 20000);
    expect(await USDC.pool.getSlippageIn(0)).to.equal(0);
    await expect(USDC.pool.getSlippageOut(numToBN(25000, 6))).to.be.revertedWith(
      "SingularityPool: AMOUNT_EXCEEDS_ASSETS"
    );
    expect(await USDC.pool.getSlippageOut(0)).to.equal(0);
  });

  it("swapExactTokensForTokens", async () => {
    await addLiquidity(ETH, 10);
    await addLiquidity(USDC, 20000);
    await router.swapExactTokensForTokens(
      usdc.address,
      eth.address,
      numToBN(amountToSwap, USDC.decimals),
      0,
      ownerAddress,
      MAX
    );
    const ethBal = await eth.balanceOf(ownerAddress);
    const usdcBal = await usdc.balanceOf(ownerAddress);
    const expectedOut = await router.getAmountOut(
      numToBN(amountToSwap, ETH.decimals),
      eth.address,
      usdc.address
    );
    expect(expectedOut).to.be.gt(0);
    await expect(
      router.swapExactTokensForTokens(eth.address, usdc.address, 0, 0, ownerAddress, MAX)
    ).to.be.revertedWith("SingularityPool: AMOUNT_IS_0");

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

  it("swapExactETHForTokens", async () => {
    await wftm.deposit({ value: numToBN(1000) });
    await addLiquidity(WFTM, 1000);
    await addLiquidity(USDC, 20000);

    await expect(
      router.swapExactETHForTokens(usdc.address, usdc.address, 0, ownerAddress, MAX, {
        value: numToBN(amountToSwap, WFTM.decimals),
      })
    ).to.be.revertedWith("SingularityRouter: INVALID_IN_TOKEN");

    const ftmBal = await getFtmBalance();
    const usdcBal = await usdc.balanceOf(ownerAddress);
    const expectedOut = await router.getAmountOut(
      numToBN(amountToSwap, WFTM.decimals),
      wftm.address,
      usdc.address
    );
    expect(expectedOut).to.be.gt(0);
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

  it("swapExactTokensForETH", async () => {
    await wftm.deposit({ value: numToBN(1000) });
    await addLiquidity(WFTM, 1000);
    await addLiquidity(USDC, 20000);

    await expect(
      router.swapExactTokensForETH(
        usdc.address,
        usdc.address,
        numToBN(amountToSwap, USDC.decimals),
        0,
        ownerAddress,
        MAX
      )
    ).to.be.revertedWith("SingularityRouter: INVALID_OUT_TOKEN");

    const ftmBal = await getFtmBalance();
    const usdcBal = await usdc.balanceOf(ownerAddress);
    const expectedOut = await router.getAmountOut(
      numToBN(amountToSwap, USDC.decimals),
      usdc.address,
      wftm.address
    );
    expect(expectedOut).to.be.gt(0);
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

  it("getTradingFees", async () => {
    expect(await USDC.pool.getTradingFeeRate()).to.equal(numToBN(USDC.baseFee));
    await updatePrices();
    const { totalFee, protocolFee, lpFee } = await USDC.pool.getTradingFees(
      numToBN(amountToSwap, USDC.decimals)
    );
    const expectedTotal = numToBN(amountToSwap * USDC.baseFee, 6);
    expect(totalFee).to.equal(expectedTotal);
    expect(protocolFee).to.equal(expectedTotal.mul(55).div(100));
    expect(lpFee).to.equal(expectedTotal.sub(protocolFee), 6);

    expect(await WFTM.pool.getTradingFeeRate()).to.be.gt(numToBN(WFTM.baseFee));
    advanceTime(55); // tests >= 60 seconds condition
    expect(await WFTM.pool.getTradingFeeRate()).to.equal(numToBN(WFTM.baseFee * 2));
    advanceTime(100); // tests >= 70 seconds condition
    expect(await WFTM.pool.getTradingFeeRate()).to.equal(MAX);
  });

  // Factory specific

  it("collectFees", async () => {
    await expect(factory.connect(otherAccount).collectFees()).to.be.revertedWith(
      "SingularityFactory: NOT_ADMIN"
    );
    await addLiquidity(ETH, 10);
    await addLiquidity(USDC, 20000);
    await router.swapExactTokensForTokens(
      eth.address,
      usdc.address,
      numToBN(0.2, ETH.decimals),
      0,
      ownerAddress,
      MAX
    );
    await factory.collectFees();
    expect(await ETH.pool.protocolFees()).to.equal(0);
    expect(await USDC.pool.protocolFees()).to.equal(0);
    expect(await eth.balanceOf(otherAddress)).to.be.gt(0);
    expect(await usdc.balanceOf(otherAddress)).to.be.gt(0);
    expect(await ETH.pool.assets()).to.equal(await eth.balanceOf(ETH.poolAddress));
    expect(await USDC.pool.assets()).to.equal(await usdc.balanceOf(USDC.poolAddress));
  });

  it("setBaseFee", async () => {
    await expect(
      factory.connect(otherAccount).setBaseFees([WFTM.address], [numToBN(0.01)])
    ).to.be.revertedWith("SingularityFactory: NOT_ADMIN");
    await expect(
      factory.setBaseFees([WFTM.address], [numToBN(0.01), numToBN(0.01)])
    ).to.be.revertedWith("SingularityFactory: NOT_SAME_LENGTH");
    await expect(factory.setBaseFees([WFTM.address], [0])).to.be.revertedWith(
      "SingularityFactory: BASE_FEE_IS_0"
    );
    await factory.setBaseFees([WFTM.address], [numToBN(0.01)]);
    expect(await WFTM.pool.baseFee()).to.equal(numToBN(0.01));
  });

  it("setAdmin", async () => {
    await expect(factory.setAdmin(ZERO_ADDR)).to.be.revertedWith(
      "SingularityFactory: ZERO_ADDRESS"
    );
    await factory.setAdmin(otherAddress);
    expect(await factory.admin()).to.equal(otherAddress);
  });

  it("setOracle", async () => {
    await expect(factory.setOracle(ZERO_ADDR)).to.be.revertedWith(
      "SingularityFactory: ZERO_ADDRESS"
    );
    await factory.setOracle(otherAddress);
    expect(await factory.oracle()).to.equal(otherAddress);
  });

  it("setFeeTo", async () => {
    await expect(factory.setFeeTo(ZERO_ADDR)).to.be.revertedWith(
      "SingularityFactory: ZERO_ADDRESS"
    );
    await factory.setFeeTo(otherAddress);
    expect(await factory.feeTo()).to.equal(otherAddress);
  });

  it("setPaused", async () => {
    await factory.setPaused([USDC.address], [true]);
    expect(await USDC.pool.paused()).to.equal(true);
  });

  // Oracle specific

  it("getLatestRound(s)", async () => {
    const [price] = await oracle.getLatestRound(USDC.address);
    expect(price).to.equal(numToBN(USDC.price));

    const [prices] = await oracle.getLatestRounds([USDC.address, ETH.address]);
    expect(prices[0]).to.equal(numToBN(USDC.price));
    expect(prices[1]).to.equal(numToBN(ETH.price));
  });

  it("run simulations", async () => {
    async function doCheck() {
      let [
        usdcPPS,
        ethPPS,
        usdcFees,
        ethFees,
        usdcAssets,
        ethAssets,
        usdcLiabilities,
        ethLiabilities,
      ] = await Promise.all([
        USDC.pool.getPricePerShare(),
        ETH.pool.getPricePerShare(),
        USDC.pool.protocolFees(),
        ETH.pool.protocolFees(),
        USDC.pool.assets(),
        ETH.pool.assets(),
        USDC.pool.liabilities(),
        ETH.pool.liabilities(),
      ]);
      console.log(
        `USDC | PPS: ${bnToNum(usdcPPS)} | Fees: ${bnToNum(usdcFees, 6)} | Assets: ${bnToNum(
          usdcAssets,
          6
        )} | Liabilities: ${bnToNum(usdcLiabilities, 6)}`
      );
      console.log(
        `ETH | PPS: ${bnToNum(ethPPS)} | Fees: ${bnToNum(ethFees)} | Assets: ${bnToNum(
          ethAssets
        )} | Liabilities: ${bnToNum(ethLiabilities)}`
      );
      console.log("=====================================================================");
      expect(await USDC.pool.assets()).to.equal(
        (await usdc.balanceOf(USDC.poolAddress)).sub(usdcFees)
      );
      expect(await ETH.pool.assets()).to.equal((await eth.balanceOf(ETH.poolAddress)).sub(ethFees));
    }

    await addLiquidity(ETH, 10);
    await addLiquidity(USDC, 20000);
    await doCheck();
    await router.removeLiquidity(usdc.address, numToBN(20000, USDC.decimals), 0, ownerAddress, MAX);
    await addLiquidity(USDC, 20000);
    await doCheck();
    await router.swapExactTokensForTokens(
      usdc.address,
      eth.address,
      numToBN(2000, USDC.decimals),
      0,
      ownerAddress,
      MAX
    );
    await doCheck();
    await router.removeLiquidity(usdc.address, numToBN(1000, USDC.decimals), 0, ownerAddress, MAX);
    await doCheck();
    await router.removeLiquidity(eth.address, numToBN(1, ETH.decimals), 0, ownerAddress, MAX);
    await doCheck();
    await router.swapExactTokensForTokens(
      eth.address,
      usdc.address,
      numToBN(1, ETH.decimals),
      0,
      ownerAddress,
      MAX
    );
    await doCheck();
    await addLiquidity(USDC, 20000);
    await addLiquidity(ETH, 10);
    await doCheck();
    const usdcLpBal = await USDC.pool.balanceOf(ownerAddress);
    await USDC.pool.withdraw(usdcLpBal.div(2), ownerAddress);
    await doCheck();
    const ethLpBal = await ETH.pool.balanceOf(ownerAddress);
    await ETH.pool.withdraw(ethLpBal.div(2), ownerAddress);
    await doCheck();
    await factory.collectFees();
    await doCheck();
  });

  it("run price impact simulations", async () => {
    function calculatePriceImpact(amountIn, amountOut) {
      return (1 - amountOut / amountIn) * 100;
    }
    async function setUpDaiPool() {
      await factory.createPool(DAI.address, DAI.isStablecoin, numToBN(DAI.baseFee));
      DAI.poolAddress = await factory.getPool(DAI.address);
      DAI.pool = await Pool.attach(DAI.poolAddress);
      await oracle.pushPrices([DAI.address], [numToBN(DAI.price)]);
      await factory.setDepositCaps([DAI.address], [MAX]);
    }

    await setUpDaiPool();
    await addLiquidity(USDC, 100000);
    await addLiquidity(DAI, 100000);
    for (let i = 5000; i < 75000; i += 5000) {
      const rawOut = await router.getAmountOut(numToBN(i, DAI.decimals), DAI.address, USDC.address);
      const amountOut = bnToNum(rawOut, USDC.decimals);
      console.log(
        `Price Impact Swapping ${i} DAI => ${amountOut} USDC: ${calculatePriceImpact(
          i,
          amountOut
        )}%`
      );
    }
  });
});
