// test/Business.test.js
// Load dependencies
const { expect } = require("chai");
const { ethers } = require("hardhat");

// Start test block
describe("Business", function () {
  let MY_TOEKN_CONTRACT;
  let BUSINESS_CONTRACT;
  let OWNER;
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
      BUSINESS_CONTRACT.target,
      BUSINESS_CONTRACT.interface,
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
    const Business = await ethers.getContractFactory("Business", OWNER);

    MY_TOEKN_CONTRACT = await MyToken.deploy("My USDT", "mUSDT", 10000);
    await MY_TOEKN_CONTRACT.waitForDeployment();
    console.log("MyToken deployed at: ", MY_TOEKN_CONTRACT.target);

    BUSINESS_CONTRACT = await Business.deploy(
      SIGNERS.map((v) => {
        return v.address;
      }),
      MY_TOEKN_CONTRACT.target
    );
    await BUSINESS_CONTRACT.waitForDeployment();
    console.log(`Business deployed at: ${BUSINESS_CONTRACT.target}`);
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
    await myToken.approve(BUSINESS_CONTRACT.target, amount);
    await business.deposit(MY_TOEKN_CONTRACT.target, amount);

    const balance1 = await myToken.balanceOf(USERS[0].address);
    const balance2 = await myToken.balanceOf(BUSINESS_CONTRACT.target);
    expect(toEth(balance1)).to.equal(amountNum);
    expect(toEth(balance2)).to.equal(amountNum);

    const balance3 = await business.balanceOf(USERS[0].address);
    expect(toEth(balance3)).to.equal(500);
  });

  it("test settle", async () => {
    const accounts = [USERS[0].address];
    const amounts = [toWei(100)];
    const expireTime = 2000000000;

    let opHash = ethers.solidityPacked(
      ["address[]", "uint256[]", "address", "uint256", "address"],
      [
        accounts,
        amounts,
        MY_TOEKN_CONTRACT.target,
        expireTime,
        BUSINESS_CONTRACT.target,
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
      [singer1.address, singer2.address],
      [signature1, signature2]
    );
    const balance = await business.balanceOf(USERS[0].address);
    expect(toEth(balance)).to.equal(400);

    const balance2 = await business.balanceOf(OWNER.address);
    expect(toEth(balance2)).to.equal(100);
  });

  it("test withdraws", async () => {
    const accounts = [USERS[0].address];
    const amounts = [toWei(400)];
    const expireTime = 2000000000;

    let opHash = ethers.solidityPacked(
      ["address[]", "uint256[]", "address", "uint256", "address"],
      [
        accounts,
        amounts,
        MY_TOEKN_CONTRACT.target,
        expireTime,
        BUSINESS_CONTRACT.target,
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
      expireTime,
      [singer1.address, singer2.address],
      [signature1, signature2]
    );
    const balance = await business.balanceOf(USERS[0].address);
    expect(toEth(balance)).to.equal(0);

    const myToken = getMyTokenIns(USERS[0]);
    const balance2 = await myToken.balanceOf(USERS[0].address);
    expect(toEth(balance2)).to.equal(900);
  });

  it("test withdraw", async () => {
    const to = USERS[0].address;
    const amount = toWei(100);
    const expireTime = 2000000000;

    let opHash = ethers.solidityPacked(
      ["address", "uint256", "address", "uint256", "address"],
      [
        to,
        amount,
        MY_TOEKN_CONTRACT.target,
        expireTime,
        BUSINESS_CONTRACT.target,
      ]
    );

    opHash = ethers.keccak256(opHash);

    const singer1 = SIGNERS[0];
    let business = getBusinessIns(singer1);
    const signature1 = await singer1.signMessage(ethers.toBeArray(opHash));

    const singer2 = SIGNERS[1];
    const signature2 = await singer2.signMessage(ethers.toBeArray(opHash));

    await business.withdraw(
      to,
      amount,
      expireTime,
      [singer1.address, singer2.address],
      [signature1, signature2]
    );

    const myToken = getMyTokenIns(USERS[0]);
    const balance = await myToken.balanceOf(USERS[0].address);
    expect(toEth(balance)).to.equal(1000);

    business = getBusinessIns(OWNER);
    const balance2 = await business.balanceOf(OWNER.address);
    expect(toEth(balance2)).to.equal(0);
  });
});
