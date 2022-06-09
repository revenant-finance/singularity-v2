const hre = require("hardhat");

async function main() {
  const Factory = await hre.ethers.getContractFactory("SingularityFactory");
  const factoryAddress = "0xC335358995dc9dF377D425C32DC15Fc2DcC1Cc42";
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
      cap: numToBN(100000),
    },
    {
      name: "wFTM",
      address: "0x21be370d5312f44cb42ce377bc9b8a0cef1a4c83",
      fee: 0.002,
      isStable: false,
      cap: numToBN(300000),
    },
  ];
  for (let i = 0; i < tokens.length; i++) {
    const tokenAddress = tokens[i].address;
    const isStablecoin = tokens[i].isStable;
    const baseFee = numToBN(tokens[i].fee);
    let tx = await factory.createPool(tokenAddress, isStablecoin, baseFee);
    await tx.wait(5);
    const poolAddress = await factory.getPool(tokenAddress);
    console.log(`${tokenAddress} pool deployed to: ${poolAddress}`);
    await run("verify:verify", {
      address: poolAddress,
      constructorArguments: [],
    });
  }

  await factory.setDepositCaps(
    [tokens[0].address, tokens[1].address, tokens[2].address, tokens[3].address],
    [tokens[0].cap, tokens[1].cap, tokens[2].cap, tokens[3].cap]
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
