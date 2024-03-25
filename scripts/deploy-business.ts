import { ethers, upgrades } from "hardhat";
import { config } from "dotenv";

async function main() {
  config({ path: "./.env_arb" });
  const Business = await ethers.getContractFactory("Business");
  console.log("Deploying Business to ARB...");

  const owner = process.env.DEPLOYER_PRIVATE_KEY!;
  const signers = process.env.SIGNER_ADDRESSES!.split(",");
  const usdcAddress = process.env.USDC_ADDRESS!;
  const oneInchAggregatorAddress = process.env._1INCH_AGGREGATOR_ADDRESS!;

  console.log("owner: ", owner);
  console.log("signers: ", signers);
  console.log("usdcAddress: ", usdcAddress);
  console.log("oneInchAggregatorAddress: ", oneInchAggregatorAddress);

  const business = await Business.deploy(signers,usdcAddress,oneInchAggregatorAddress);

  business
    .waitForDeployment()
    .then(() => {
      console.log("Business deployed to:", business.target);
    })
    .catch((error: any) => {
      console.error("Error occurred: ", error);
    });
}

main();
