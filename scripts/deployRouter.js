const hre = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(`Deployer address: ${deployer.address}`);
  const deployerBalance = await deployer.getBalance();
  console.log(`Deployer balance: ${deployerBalance}`);

  const provider = deployer.provider;
  const network = await provider.getNetwork();
  console.log(`Network: ${network.name} with chainId ${network.chainId}`);
  const Router = await hre.ethers.getContractFactory("SingularityRouter");
  const factoryAddress = "0x9748ED62f418aF1c076D51693980d216E4f9D33A";
  const wrappedNativeAddress = "0x21be370d5312f44cb42ce377bc9b8a0cef1a4c83";
  const router = await Router.deploy(factoryAddress, wrappedNativeAddress);

  await router.deployed();

  console.log("Router deployed to:", router.address); // 0x3D81d4f9f03D73Cd697D3cC309E8676b8C14e0FA
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
