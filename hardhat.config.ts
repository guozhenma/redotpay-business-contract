import { HardhatUserConfig } from "hardhat/config";
import "@openzeppelin/hardhat-upgrades";
import "@nomicfoundation/hardhat-toolbox";

// import "@nomiclabs/hardhat-truffle5";

const config: HardhatUserConfig = {
  solidity: "0.8.20",
};

export default config;
