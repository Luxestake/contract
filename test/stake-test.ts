import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";
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
    "0xb325ccf371b5b71cc48e202c9a19848d212d27ae9902ac796078ac41644503b5f5c75fe0f0b1c97b2684b7632e685e41",
  withdrawal_credentials: "",

  signatures:
    "0x84a2c9b617a5168ccb274a83356e5f6d4a55e23a959787b068bf063ff3ca8f60a24900dc2b9fd7f5a6023f1715638ba416bfe2ec0c715dff6bd4a948a7ea576f0124352c2d8a1c130c5316d97762144dcc018e5afb85aefd3d1f91af56cf3fe6",

  deposit_data_root:
    "0xe16e8c180a5376b7c4bf8c7ab530f1d51f78102646e7be1c1a1e63770a9d84cb",
};

describe("Stake Pool Testcase", function () {
  async function deployEth2Fixture() {
    let EthStakePool = await ethers.getContractFactory("EthStakePool");
    let ethStakePool: EthStakePool = await EthStakePool.deploy();
    const [owner, addr1, addr2, addr3] = await ethers.getSigners();

    let DepositContract = await ethers.getContractFactory("DepositContract");
    let depositContract: DepositContract = await DepositContract.deploy();

    let EthStakePoolFactory = await ethers.getContractFactory(
      "EthStakePoolFactory"
    );
    let ethStakePoolFactory: EthStakePoolFactory =
      await EthStakePoolFactory.deploy(
        ethStakePool.address,
        depositContract.address
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
      let newPoolAddr = await ethStakePoolFactory.getPoolByIndex(0);

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
      let newPoolAddr = await ethStakePoolFactory.getPoolByIndex(0);

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
      let newPoolAddr = await ethStakePoolFactory.getPoolByIndex(0);

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
      let newPoolAddr = await ethStakePoolFactory.getPoolByIndex(0);

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
      let newPoolAddr = await ethStakePoolFactory.getPoolByIndex(0);

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
