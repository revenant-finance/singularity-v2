const hre = require("hardhat");

async function main() {
  const [ deployer ] = await ethers.getSigners();
  console.log(`Deployer address: ${deployer.address}`);
  const deployerBalance = await deployer.getBalance();
  console.log(`Deployer balance: ${deployerBalance}`);

  const provider = deployer.provider;
  const network = await provider.getNetwork();
  console.log(`Network: ${network.name} with chainId ${network.chainId}`);
  const ERC20 = await hre.ethers.getContractFactory("ERC20");
  const erc20 = await ERC20.deploy("Dai Stablecoin", "DAI", 18);

  await erc20.deployed();

  console.log("ERC20 deployed to:", erc20.address); 
  // ETH: 0x5A8f1a7b43771fe64E8f663c59C16f09cD08C88E
  // USDC: 0x5ad30B0F48Dba425bD66FC0952FcD69f5adE12eb
  // DAI: 0x3DaCd6a17898ac7303aa25764Fb362A81A8F9411
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
