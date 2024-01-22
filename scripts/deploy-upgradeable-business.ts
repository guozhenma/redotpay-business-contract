import { ethers, upgrades } from "hardhat";

async function main() {
  const signers = await ethers.getSigners();
  const signer = signers[0];
  signer;
  // =============================== test-end ===============================

  const Business = await ethers.getContractFactory("Business");
  console.log("Deploying Business...");
  const business = await upgrades.deployProxy(
    Business,
    [["SIGNER1_ADDRESS", "SIGNER2_ADDRESS", "SIGNER3_ADDRESS"], "USDC_ADDRESS"],
    {
      initialOwner: "OWNER_ADDRESS",
    }
  );
  await business.waitForDeployment();
  console.log("Business deployed to:", business.target);
}

main();
