const hre = require("hardhat");

async function main() {
  const [ deployer ] = await ethers.getSigners();
  console.log(`Deployer address: ${deployer.address}`);
  const deployerBalance = await deployer.getBalance();
  console.log(`Deployer balance: ${deployerBalance}`);

  const provider = deployer.provider;
  const network = await provider.getNetwork();
  console.log(`Network: ${network.name} with chainId ${network.chainId}`);
  const Factory = await hre.ethers.getContractFactory("SingularityFactory");
  const oracleAddress = "0xf0d2b2694C64996939716f144dA271dd16cF1bC4";
  const factory = await Factory.deploy(deployer.address, oracleAddress);

  await factory.deployed();

  console.log("Factory deployed to:", factory.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
