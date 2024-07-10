import { ethers, upgrades } from "hardhat";
import { config } from "dotenv";

async function main() {
  const result = configEnv(process.env.NETWORK!);
  if (!result) {
    throw new Error(`不支持的网络：${process.env.NETWORK}`);
  }

  const BusinessV2 = await ethers.getContractFactory("BusinessV2");
  console.log("Deploying Business...");

  const ownerAddress = process.env.OWNER_ADDRESS!;
  const signers = process.env.SIGNER_ADDRESSES!.split(",");
  const usdcAddress = process.env.USDC_ADDRESS!;
  const oneInchAggregatorAddress = process.env._1INCH_AGGREGATOR_ADDRESS!;

  console.log("owner: ", ownerAddress);
  console.log("signers: ", signers);
  console.log("usdcAddress: ", usdcAddress);
  console.log("oneInchAggregatorAddress: ", oneInchAggregatorAddress);

  const proxy = await upgrades.deployProxy(
    BusinessV2,
    [ownerAddress, signers, usdcAddress, oneInchAggregatorAddress],
    {
      initializer: "initialize(address,address[],address,address)",
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

function configEnv(network: string) {
  let result = true;
  switch (network) {
    case "arb":
      config({ path: "./.env_arb" });
      break;
    case "base":
      config({ path: "./.env_base" });
      break;
    case "bsc":
      config({ path: "./.env_bsc" });
      break;
    case "ethereum":
      config({ path: "./.env_ethereum" });
      break;
    case "op":
      config({ path: "./.env_op" });
      break;
    case "polygon":
      config({ path: "./.env_polygon" });
      break;
    default:
      result = false;
      break;
  }
  return result;
}

main();
