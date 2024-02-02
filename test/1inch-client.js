const axios = require("axios");
// 测试合约地址： https://polygonscan.com/address/0xEbc7b189caB8382Ac5b237060B0a2efE83f8e746
// test data
const swapParams = {
  fromTokenAddress: "0xc2132D05D31c914a87C6611C10748AEb04B58e8F", // USDT合约地址
  toTokenAddress: "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174", // USDC合约地址
  amount: "1517199", // USDT金额，精度为6
  fromAddress: "0xEbc7b189caB8382Ac5b237060B0a2efE83f8e746", // 资金池合约地址
  destReceiver: "0xEbc7b189caB8382Ac5b237060B0a2efE83f8e746", // 资金池合约地址
  slippage: 1, // 滑点
  disableEstimate: true,
};
const chainId = 137;
async function oneInchSwap(chainId, swapParams) {
  // const url = `https://api.1inch.dev/swap/v5.2/${chainId}/swap?src=${swapParams.fromTokenAddress}&dst=${swapParams.toTokenAddress}&amount=${swapParams.amount}&from=${swapParams.fromAddress}&receiver=${swapParams.destReceiver}&slippage=${swapParams.slippage}&disableEstimate=${swapParams.disableEstimate}&compatibility=true`;
  const url = `https://api.1inch.dev/swap/v5.2/${chainId}/swap`;
  console.log("swap url", url);
  let response = await axios.get(url, {
    headers: {
      Authorization: "mKijlbCA6RhRhxu2eKJO1m0pXk4KRv8l",
      Accept: "application/json",
    },
    params: {
      src: swapParams.fromTokenAddress,
      dst: swapParams.toTokenAddress,
      amount: swapParams.amount,
      from: swapParams.fromAddress,
      receiver: swapParams.destReceiver,
      slippage: swapParams.slippage,
      disableEstimate: swapParams.disableEstimate,
      compatibility: true,
    },
  });
  console.log("response: ", response.data);
  return response.data.tx.data;
}

oneInchSwap(chainId, swapParams);
