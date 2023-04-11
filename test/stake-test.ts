import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers, network } from "hardhat";
import {
  EthStakePool,
  EthStakePoolFactory,
  DepositContract,
} from "../src/types/index";
const log_on = true;
const log = (message?, ...optionalParams ) => { if (log_on) console.log(message, ...optionalParams) };

let withdrawPrefix = "0x010000000000000000000000";
var fakeData = {
  pubkeys:
    "0xaa373f716f2f1e7ce7042f3d24b71676f719adc0f666543e7f35155e15844e5a592d83459cc168e689d8ae9137868cef",
  withdrawal_credentials: "0x010000000000000000000000bce0f9c20ad0a745d5a1d924fa3f545f502c3991",

  signatures:
    "0xb75e6c67494ee58df336cccfe77e7f6b86dfd28f233168ab5c379c3d0de6f8cca944744133f927afba51ad4cfa35da100f7c2e903add979a986d486e71a396a5afc095250ae11586c95564d2476d404b163884dd429689a12b1a39928275d94a",

  deposit_data_root:
    "0x498dbfe250fe169efbc93fe75c2246a53f55ff55140eae32724d1e3247c23cee",
};

describe("Stake Pool Testcase", function () {
  async function deployEth2Fixture() {
    let EthStakePool = await ethers.getContractFactory("EthStakePool");
    let ethStakePool: EthStakePool = await EthStakePool.deploy();
    const [owner, addr1, addr2, addr3] = await ethers.getSigners();


    const beaconContractDeployer = "0xb20a608c624ca5003905aa834de7156c68b2e1d0"
    await network.provider.send("hardhat_setBalance", [
      beaconContractDeployer,
      "0x10000000000000000000000000000000000",
    ]);
    await network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [beaconContractDeployer],
    });
    const beaconSigner = await ethers.getSigner(beaconContractDeployer)
    let DepositContract = await ethers.getContractFactory("DepositContract");
    let depositContract: DepositContract = await DepositContract.connect(beaconSigner).deploy();
    console.log(`depositContract.address`, depositContract.address)
    // expect deposit contract equal to the address in eth2 spec
    // https://etherscan.io/address/0x00000000219ab540356cbb839cbe05303d7705fa
    expect(await depositContract.address).to.equal("0x00000000219ab540356cBB839Cbe05303d7705Fa");
    let EthStakePoolFactory = await ethers.getContractFactory(
      "EthStakePoolFactory"
    );
    let ethStakePoolFactory: EthStakePoolFactory =
      await EthStakePoolFactory.deploy(
        ethStakePool.address
      );
    return { ethStakePool, ethStakePoolFactory, owner, addr1, addr2, addr3 };
  }

  describe("Deployment", function () {
    it("deploy a eth2 pool", async function () {
      const { ethStakePoolFactory, owner, addr1, addr2, addr3 } =
        await loadFixture(deployEth2Fixture);
      await ethStakePoolFactory.create(
        addr1.address,
        addr1.address,
        ethers.utils.parseEther("0.1").toString()
      );
      let newPoolAddr = await ethStakePoolFactory.stakingPools(0);

      const ethStakePool = await ethers.getContractAt(
        "EthStakePool",
        newPoolAddr
      );

      for (let i = 0; i < 32; i++) {
        await ethStakePool
          .connect(addr3)
          .participate({ value: ethers.utils.parseEther("1").toString() });
      }
      await ethStakePool.connect(addr3).participate({
        value: ethers.utils.parseEther("0.323200000000000001").toString(),
      });
      await ethStakePool;
      let tokenUri = await ethStakePool.tokenURI(33);
      log(`tokenUri `, tokenUri);
      fakeData.withdrawal_credentials = `${withdrawPrefix}${ethStakePool.address
        .slice(2, 42)
        .toLowerCase()}`;
      log(`withdraw address ${fakeData.withdrawal_credentials}`);
      await ethStakePool
        .connect(addr1)
        .depositETHToStake(
          fakeData.pubkeys,
          fakeData.withdrawal_credentials,
          fakeData.signatures,
          fakeData.deposit_data_root
        );
    });

    it("distribute rewards", async function () {
      const { ethStakePoolFactory, owner, addr1, addr2, addr3 } =
        await loadFixture(deployEth2Fixture);
      await ethStakePoolFactory.create(
        addr1.address,
        addr1.address,
        ethers.utils.parseEther("0.1").toString()
      );
      let newPoolAddr = await ethStakePoolFactory.stakingPools(0);

      const ethStakePool = await ethers.getContractAt(
        "EthStakePool",
        newPoolAddr
      );

      for (let i = 0; i < 32; i++) {
        await ethStakePool
          .connect(addr3)
          .participate({ value: ethers.utils.parseEther("1").toString() });
      }
      await ethStakePool.connect(addr3).participate({
        value: ethers.utils.parseEther("0.323200000000000001").toString(),
      });
      fakeData.withdrawal_credentials = `${withdrawPrefix}${ethStakePool.address
        .slice(2, 42)
        .toLowerCase()}`;
      log(`withdraw address ${fakeData.withdrawal_credentials}`);
      await ethStakePool
        .connect(addr1)
        .depositETHToStake(
          fakeData.pubkeys,
          fakeData.withdrawal_credentials,
          fakeData.signatures,
          fakeData.deposit_data_root
        );
      await ethStakePool
        .connect(addr1)
        .distributeRewards().toString();

    });

    it("dismiss pool", async function () {
      const { ethStakePoolFactory, owner, addr1, addr2, addr3 } =
        await loadFixture(deployEth2Fixture);
      await ethStakePoolFactory.create(
        addr1.address,
        addr1.address,
        ethers.utils.parseEther("0.1").toString()
      );
      let newPoolAddr = await ethStakePoolFactory.stakingPools(0);

      const ethStakePool = await ethers.getContractAt(
        "EthStakePool",
        newPoolAddr
      );

      await ethStakePool.connect(addr3).participate({
        value: ethers.utils.parseEther("16.16161616161616").toString(),
      });
      await ethStakePool.connect(addr3).participate({
        value: ethers.utils.parseEther("16.16161616161617").toString(),
      });
      fakeData.withdrawal_credentials = `${withdrawPrefix}${ethStakePool.address
        .slice(2, 42)
        .toLowerCase()}`;
      log(`withdraw address ${fakeData.withdrawal_credentials}`);

      await ethStakePool
        .connect(addr1)
        .depositETHToStake(
          fakeData.pubkeys,
          fakeData.withdrawal_credentials,
          fakeData.signatures,
          fakeData.deposit_data_root
        );
      // mock withdraw balance
     
      await ethStakePool
      .connect(addr1)
      .topUp(ethers.utils.parseEther("32").toString(), {value: ethers.utils.parseEther("32").toString()});

      await ethStakePool
        .connect(addr1)
        .dismissPool(ethers.utils.parseEther("32").toString());
      await ethStakePool.connect(addr3).exitFromDismissPool(1);
      await ethStakePool.connect(addr3).exitFromDismissPool(2);
    });

    it("failed pool", async function () {
      const { ethStakePoolFactory, owner, addr1, addr2, addr3 } =
        await loadFixture(deployEth2Fixture);
      await ethStakePoolFactory.create(
        addr1.address,
        addr1.address,
        ethers.utils.parseEther("0.1").toString()
      );
      let newPoolAddr = await ethStakePoolFactory.stakingPools(0);

      const ethStakePool = await ethers.getContractAt(
        "EthStakePool",
        newPoolAddr
      );

      await ethStakePool.connect(addr3).participate({
        value: ethers.utils.parseEther("16.16161616161617").toString(),
      });
      await ethStakePool
        .connect(addr3)
        .participate({ value: ethers.utils.parseEther("10.1").toString() });

      await ethStakePool.connect(addr1).setFailedStatus();
      await ethStakePool.connect(addr3).exitFromFailedPool(1);
      await ethStakePool.connect(addr3).exitFromFailedPool(2);
    });

    it("royalty fee", async function () {
      const { ethStakePoolFactory, owner, addr1, addr2, addr3 } =
        await loadFixture(deployEth2Fixture);
      await ethStakePoolFactory.create(
        addr1.address,
        addr1.address,
        ethers.utils.parseEther("0.1").toString()
      );
      let newPoolAddr = await ethStakePoolFactory.stakingPools(0);

      const ethStakePool = await ethers.getContractAt(
        "EthStakePool",
        newPoolAddr
      );

      await ethStakePool.connect(addr3).participate({
        value: ethers.utils.parseEther("16.16161616161617").toString(),
      });
      await ethStakePool
        .connect(addr3)
        .participate({ value: ethers.utils.parseEther("10.1").toString() });
      let royaltyInfo = await ethStakePool.royaltyInfo(
        1,
        ethers.utils.parseEther("1")
      );
      log(`royaltyInfo `, royaltyInfo);
    });
  });
});
