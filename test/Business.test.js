// test/Business.test.js
// Load dependencies
const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

// Start test block
describe("Business", function () {
  let MY_TOEKN_CONTRACT;
  let BUSINESS_CONTRACT_PROXY;
  let OWNER;
  const ORDER_ID = "111111";
  const CHAIN_ID = 31337;
  const USERS = [];
  const SIGNERS = [];

  getMyTokenIns = (signer) => {
    return new ethers.Contract(
      MY_TOEKN_CONTRACT.target,
      MY_TOEKN_CONTRACT.interface,
      signer
    );
  };

  getBusinessIns = (signer) => {
    return new ethers.Contract(
      BUSINESS_CONTRACT_PROXY.target,
      BUSINESS_CONTRACT_PROXY.interface,
      signer
    );
  };

  toWei = (ethAmount) => {
    return ethers.parseEther(ethAmount + "");
  };

  toEth = (weiAmount) => {
    return parseFloat(ethers.formatEther(weiAmount));
  };

  before(async function () {
    const envSingers = await ethers.getSigners();

    // print all signers
    // envSingers.map((v) => {
    //   console.log(v.address);
    // });

    OWNER = envSingers[0];

    console.log(`Owner address: ${OWNER.address}`);
    for (let i = 1; i < 4; i++) {
      SIGNERS.push(envSingers[i]);
    }
    console.log(`Singers for Business created: length: ${SIGNERS.length}`);
    for (let i = envSingers.length - 1; i > envSingers.length - 11; i--) {
      USERS.push(envSingers[i]);
    }
    console.log(`Users for Business created: length: ${USERS.length}`);

    const MyToken = await ethers.getContractFactory("MyToken", OWNER);
    const Business = await ethers.getContractFactory("BusinessV2", OWNER);

    MY_TOEKN_CONTRACT = await MyToken.deploy("My USDT", "mUSDT", 10000);
    await MY_TOEKN_CONTRACT.waitForDeployment();
    console.log("MyToken deployed at: ", MY_TOEKN_CONTRACT.target);

    BUSINESS_CONTRACT_PROXY = await upgrades.deployProxy(
      Business,
      [
        OWNER.address,
        SIGNERS.map((v) => {
          return v.address;
        }),
        MY_TOEKN_CONTRACT.target,
        MY_TOEKN_CONTRACT.target,
      ],
      {
        initializer: "initialize(address,address[],address,address)",
      }
    );
    await BUSINESS_CONTRACT_PROXY.waitForDeployment();
    console.log(`Business deployed at: ${BUSINESS_CONTRACT_PROXY.target}`);
  });

  // Test case
  it("balance of owner", async function () {
    const myToken = getMyTokenIns(OWNER);
    const balance = await myToken.balanceOf(OWNER.address);
    expect(toEth(balance)).to.equal(10000);
  });

  it("fund user1 some token", async function () {
    const amount = toWei(1000);
    let myToken = getMyTokenIns(OWNER);
    await myToken.approve(USERS[0].address, amount);

    myToken = getMyTokenIns(USERS[0]);
    await myToken.transferFrom(OWNER.address, USERS[0].address, amount);

    const balance1 = await myToken.balanceOf(OWNER.address);
    expect(toEth(balance1)).to.equal(9000);

    const balance2 = await myToken.balanceOf(USERS[0].address);
    expect(toEth(balance2)).to.equal(1000);
  });

  it("user1 deposit", async () => {
    const amountNum = 500;
    let myToken = getMyTokenIns(USERS[0]);
    let business = getBusinessIns(USERS[0]);

    const amount = toWei(amountNum);
    await myToken.approve(BUSINESS_CONTRACT_PROXY.target, amount);
    const buffer = Buffer.alloc(10);
    await business.deposit("ddddddd", MY_TOEKN_CONTRACT.target, amount, buffer);

    const balance1 = await myToken.balanceOf(USERS[0].address);
    const balance2 = await myToken.balanceOf(BUSINESS_CONTRACT_PROXY.target);
    expect(toEth(balance1)).to.equal(amountNum);
    expect(toEth(balance2)).to.equal(amountNum);

    const balance3 = await business.balances(USERS[0].address);
    expect(toEth(balance3)).to.equal(500);
  });

  it("test settle", async () => {
    const accounts = [USERS[0].address];
    const amounts = [toWei(100)];
    const expireTime = 2000000000;

    let opHash = ethers.solidityPacked(
      [
        "string",
        "uint256",
        "address[]",
        "uint256[]",
        "address",
        "uint256",
        "address",
      ],
      [
        ORDER_ID,
        CHAIN_ID,
        accounts,
        amounts,
        MY_TOEKN_CONTRACT.target,
        expireTime,
        BUSINESS_CONTRACT_PROXY.target,
      ]
    );

    opHash = ethers.keccak256(opHash);

    const singer1 = SIGNERS[0];
    const signature1 = await singer1.signMessage(ethers.toBeArray(opHash));

    const singer2 = SIGNERS[1];
    const signature2 = await singer2.signMessage(ethers.toBeArray(opHash));

    let business = getBusinessIns(OWNER);
    await business.settle(
      accounts,
      amounts,
      expireTime,
      ORDER_ID,
      [singer1.address, singer2.address],
      [signature1, signature2]
    );
    const balance = await business.balances(USERS[0].address);
    expect(toEth(balance)).to.equal(400);
    let balance2 = await business.balanceOfOwner();
    expect(toEth(balance2)).to.equal(100);
  });

  it("test withdraws", async () => {
    const accounts = [USERS[0].address];
    const amounts = [toWei(400)];
    const fees = [0];
    const expireTime = 2000000000;

    let opHash = ethers.solidityPacked(
      [
        "string",
        "uint256",
        "address[]",
        "uint256[]",
        "uint256[]",
        "address",
        "uint256",
        "address",
      ],
      [
        ORDER_ID,
        CHAIN_ID,
        accounts,
        amounts,
        fees,
        MY_TOEKN_CONTRACT.target,
        expireTime,
        BUSINESS_CONTRACT_PROXY.target,
      ]
    );

    opHash = ethers.keccak256(opHash);

    const singer1 = SIGNERS[0];
    const signature1 = await singer1.signMessage(ethers.toBeArray(opHash));

    const singer2 = SIGNERS[1];
    const signature2 = await singer2.signMessage(ethers.toBeArray(opHash));

    let business = getBusinessIns(USERS[0]);
    await business.withdraws(
      accounts,
      amounts,
      fees,
      expireTime,
      ORDER_ID,
      [singer1.address, singer2.address],
      [signature1, signature2]
    );
    const balance = await business.balances(USERS[0].address);
    expect(toEth(balance)).to.equal(0);

    const myToken = getMyTokenIns(USERS[0]);
    const balance2 = await myToken.balanceOf(USERS[0].address);
    expect(toEth(balance2)).to.equal(900);
  });

  it("test withdraw", async () => {
    const to = USERS[0].address;
    const amount = toWei(100);
    const expireTime = 2000000000;

    let business = getBusinessIns(OWNER);

    await business.withdraw(to, amount, expireTime);

    const myToken = getMyTokenIns(USERS[0]);
    const balance = await myToken.balanceOf(USERS[0].address);
    expect(toEth(balance)).to.equal(1000);

    business = getBusinessIns(OWNER);
    const balance2 = await business.balances(OWNER.address);
    expect(toEth(balance2)).to.equal(0);
  });
});
