import { HardhatUserConfig } from "hardhat/config";
import "@openzeppelin/hardhat-upgrades";
import "@nomicfoundation/hardhat-toolbox";
// import "@nomiclabs/hardhat-etherscan";
import env from "dotenv";

env.config({ path: "./.env" });

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.20",
    // settings: {
    //   optimizer: {
    //     enabled: true,
    //     runs: 200,
    //   },
    // },
  },
  networks: {
    arb: {
      chainId: 42161,
      url: `https://arbitrum-mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: [process.env.DEPLOYER_PRIVATE_KEY!],
    },
    op: {
      chainId: 10,
      url: `https://optimism-mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: [process.env.DEPLOYER_PRIVATE_KEY!],
    },
  },
  etherscan: {
    apiKey: {
      arbitrumOne: "KIBMZW2ZJPCGU2ZY4MQK77ZHU5M7U1TJAW",
      optimisticEthereum: "9FP66Q9WHQ38QH1SRG81ZWPQSQVIU4BAV2",
    },
  },
  sourcify: {
    enabled: true,
  },
};

export default config;
