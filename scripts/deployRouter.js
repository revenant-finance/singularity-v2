const hre = require("hardhat");

async function main() {
  const Router = await hre.ethers.getContractFactory("SingularityRouter");
  const factoryAddress = "0xD33CFb4E53CF6EdBeDAc8bB5fe7327a1Da25f746";
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
