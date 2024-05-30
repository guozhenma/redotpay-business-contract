import { ethers, upgrades } from "hardhat";

async function main() {
  const proxyAddress = "0x01f2F14808f11B91f5643ae83358fF891eEB76a3";

  // const Business = await ethers.getContractFactory("Business");
  // await upgrades.forceImport(proxyAddress, Business);

  const BusinessV2 = await ethers.getContractFactory("BusinessV2");
  console.log("Upgrading Business...");
  const implContract = await upgrades.prepareUpgrade(proxyAddress, BusinessV2);
  await upgrades.upgradeProxy(proxyAddress, BusinessV2);
  console.log("Business upgraded", implContract.toString());
}

main();
