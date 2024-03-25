import { HardhatUserConfig } from "hardhat/config";
import "@openzeppelin/hardhat-upgrades";
import "@nomicfoundation/hardhat-toolbox";
// import "@nomiclabs/hardhat-etherscan";
import env from "dotenv";

env.config({ path: "./.env_arb" });

const config: HardhatUserConfig = {
  solidity: "0.8.20",
  networks: {
    arb: {
      chainId: 42161,
      url: `https://arbitrum-mainnet.infura.io/v3/2b3efdf6a38147d3b6ac46639e9dba16`,
      accounts: [process.env.DEPLOYER_PRIVATE_KEY!],
    },
  },
  etherscan: {
    apiKey: {
      arbitrumOne: 'KIBMZW2ZJPCGU2ZY4MQK77ZHU5M7U1TJAW'
    }
  },
  sourcify: {
    enabled: true
  }
  
};

export default config;
