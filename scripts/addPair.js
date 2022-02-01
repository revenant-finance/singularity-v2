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
  const factory = await Factory.attach("0x52a97FC5bC2754cb08B7376214d3CB7E187182C7");
  await factory.createPair("0x5ad30B0F48Dba425bD66FC0952FcD69f5adE12eb", "0x3DaCd6a17898ac7303aa25764Fb362A81A8F9411", 1000, ethers.utils.parseEther("0.0005"))
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
