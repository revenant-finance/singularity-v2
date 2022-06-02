const hre = require("hardhat");

async function main() {
  const Router = await hre.ethers.getContractFactory("SingularityRouter");
  const factoryAddress = "0xc27579d5Ad9e3f59b6deF2F2dA559d2F9d7e3a19";
  const wftmAddress = "0x21be370d5312f44cb42ce377bc9b8a0cef1a4c83";
  const router = await Router.deploy(factoryAddress, wftmAddress);
  await router.deployed();

  console.log(`Router deployed to: ${router.address}`);

  const Factory = await hre.ethers.getContractFactory("SingularityFactory");
  const factory = Factory.attach(factoryAddress);
  await factory.setRouter(router.address);

  await run("verify:verify", {
    address: router.address,
    constructorArguments: [factoryAddress, wftmAddress],
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
