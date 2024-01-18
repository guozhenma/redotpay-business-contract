import { ethers, upgrades } from "hardhat";

async function main() {
  const BusinessV2 = await ethers.getContractFactory("BusinessV2");
  console.log("Upgrading Business...");
  await upgrades.upgradeProxy(
    "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512",
    BusinessV2
  );
  console.log("Business upgraded");
}

main();
