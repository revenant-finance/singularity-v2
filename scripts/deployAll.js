const hre = require("hardhat");

async function main() {
  const [ deployer ] = await ethers.getSigners();
  console.log(`Deployer address: ${deployer.address}`);
  const deployerBalance = await deployer.getBalance();
  console.log(`Deployer balance: ${deployerBalance}`);

  const provider = deployer.provider;
  const network = await provider.getNetwork();
  console.log(`Network: ${network.name} with chainId ${network.chainId}`);

  // const Factory = await hre.ethers.getContractFactory("SingularityFactory");
  // const oracleAddress = "0xf0d2b2694C64996939716f144dA271dd16cF1bC4";
  // const factory = await Factory.deploy(deployer.address, oracleAddress);

  // await factory.deployed();

  // console.log("Factory deployed to:", factory.address); // 0xe2F032004C5b9ea73c0eE3d367885084D04dafb3
  // const usdc = "0x5ad30B0F48Dba425bD66FC0952FcD69f5adE12eb";
  // const dai = "0x3DaCd6a17898ac7303aa25764Fb362A81A8F9411";
  // await factory.createPair(usdc, dai, 1500, ethers.utils.parseEther("0.0005"))

  const Router = await hre.ethers.getContractFactory("SingularityRouter");
  const wrappedNativeAddress = "0x21be370d5312f44cb42ce377bc9b8a0cef1a4c83";
  const router = await Router.deploy("0xe2F032004C5b9ea73c0eE3d367885084D04dafb3", wrappedNativeAddress);

  await router.deployed();

  console.log("Router deployed to:", router.address); // 0xC1fF6b2D653954eFF10578C36a926B8C125b918C
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
