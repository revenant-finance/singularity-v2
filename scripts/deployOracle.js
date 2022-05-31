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
  await tx.wait(5);

  const usdc = "0x04068da6c83afcfa0e13ba15a6696662335d5b75";
  const usdt = "0x049d68029688eabf473097a2fc38ef61633a3c7a";
  const dai = "0x8d11ec38a3eb5e956b052f67da8bdc9bef8abf3e";
  const wftm = "0x21be370d5312f44cb42ce377bc9b8a0cef1a4c83";

  const usdcFeed = "0x2553f4eeb82d5A26427b8d1106C51499CBa5D99c";
  const usdtFeed = "0xF64b636c5dFe1d3555A847341cDC449f612307d0";
  const daiFeed = "0x91d5DEFAFfE2854C7D02F50c80FA1fdc8A721e52";
  const wftmFeed = "0xf4766552D15AE4d256Ad41B6cf2933482B0680dc";
  tx = await oracle.setChainlinkFeeds(
    [usdc, usdt, dai, wftm],
    [usdcFeed, usdtFeed, daiFeed, wftmFeed]
  );
  await tx.wait(5);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
