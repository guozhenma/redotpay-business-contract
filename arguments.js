const { config } = require("dotenv");

config({ path: "./.env_arb" });

const signers = process.env.SIGNER_ADDRESSES.split(",");
const usdcAddress = process.env.USDC_ADDRESS;
const oneInchAggregatorAddress = process.env._1INCH_AGGREGATOR_ADDRESS;

module.exports = [signers, usdcAddress, oneInchAggregatorAddress];
