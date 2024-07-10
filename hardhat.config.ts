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
    eth: {
      chainId: 1,
      url: `https://mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: [process.env.DEPLOYER_PRIVATE_KEY!],
    },
    op: {
      chainId: 10,
      url: `https://optimism-mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: [process.env.DEPLOYER_PRIVATE_KEY!],
    },
    bsc: {
      chainId: 56,
      url: "https://quaint-evocative-bird.bsc.quiknode.pro/e2b4caf64050bcd8a749f90e22c2e0523c04968f/",
      accounts: [process.env.DEPLOYER_PRIVATE_KEY!],
    },
    polygon: {
      chainId: 137,
      url: `https://polygon-mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: [process.env.DEPLOYER_PRIVATE_KEY!],
    },
    base: {
      chainId: 8453,
      url: `https://arbitrum-mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: [process.env.DEPLOYER_PRIVATE_KEY!],
    },
    arb: {
      chainId: 42161,
      url: `https://arbitrum-mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: [process.env.DEPLOYER_PRIVATE_KEY!],
    },
  },
  etherscan: {
    apiKey: {
      ethereum: "7YS3G4MVD7RNVMCQYBCRT38H835M9FQMJ9",
      optimisticEthereum: "9FP66Q9WHQ38QH1SRG81ZWPQSQVIU4BAV2",
      bsc: "6D225IUDVVVADDATQBY98RS5QZAN1K5FDI",
      polygon: "1Z4NZXZR9DSN3Z12GH8NTVTCJ2PZVXMDK6",
      arbitrumOne: "KIBMZW2ZJPCGU2ZY4MQK77ZHU5M7U1TJAW",
    },
  },
  sourcify: {
    enabled: true,
  },
};

export default config;
