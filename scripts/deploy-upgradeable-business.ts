import { ethers, upgrades } from "hardhat";
import { config } from "dotenv";

async function main() {
  config({ path: "./.env_arb" });
  const Business = await ethers.getContractFactory("Business");
  console.log("Deploying Business to ARB...");

  const deployerPrivateKey = process.env.DEPLOYER_PRIVATE_KEY!;
  const ownerAddress = process.env.OWNER_ADDRESS!;
  const signers = process.env.SIGNER_ADDRESSES!.split(",");
  const usdcAddress = process.env.USDC_ADDRESS!;
  const oneInchAggregatorAddress = process.env._1INCH_AGGREGATOR_ADDRESS!;

  console.log("owner: ", ownerAddress);
  console.log("signers: ", signers);
  console.log("usdcAddress: ", usdcAddress);
  console.log("oneInchAggregatorAddress: ", oneInchAggregatorAddress);

  const proxy = await upgrades.deployProxy(
    Business,
    [ownerAddress,signers, usdcAddress, oneInchAggregatorAddress],
    {
      initialOwner: deployerPrivateKey,
      initializer:'initialize(address,address[],address,address)'
    }
  );

  proxy
    .waitForDeployment()
    .then(() => {
      console.log("Business deployed to:", proxy.target);
    })
    .catch((error: any) => {
      console.error("Error occurred: ", error);
    });
}

main();
