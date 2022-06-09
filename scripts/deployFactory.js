const hre = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  const Factory = await hre.ethers.getContractFactory("SingularityFactory");
  const trancheName = "Beta v4";
  const adminAddress = deployer.address;
  const oracleAddress = "0xd9EFff5076764c3FD58C91D4FEE8AA45a71b1dB4";
  const feeToAddress = deployer.address;
  const factory = await Factory.deploy(trancheName, adminAddress, oracleAddress, feeToAddress);

  await factory.deployed();

  console.log(`Factory deployed to: ${factory.address}`);

  await new Promise((resolve) => setTimeout(resolve, 5000));
  await run("verify:verify", {
    address: factory.address,
    constructorArguments: [trancheName, adminAddress, oracleAddress, feeToAddress],
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
