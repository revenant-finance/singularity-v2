const hre = require("hardhat");

async function main() {
  const ERC20 = await hre.ethers.getContractFactory("TestERC20");
  const name = "Test Bitcoin";
  const symbol = "testBTC";
  const decimals = 8;
  const erc20 = await ERC20.deploy(name, symbol, decimals);
  await erc20.deployed();

  console.log(`${symbol} ERC20 deployed to: ${erc20.address}`);

  await run("verify:verify", {
    address: erc20.address,
    constructorArguments: [name, symbol, decimals],
    contract: "contracts/testing/TestERC20.sol:TestERC20",
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
