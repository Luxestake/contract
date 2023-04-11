import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import 'solidity-docgen';

/** @type import('hardhat/config').HardhatUserConfig */
const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.17",
    settings: {
      optimizer: { enabled: true, runs: 200},
    },
  },

  typechain: {
    outDir: "src/types",
    target: "ethers-v5",
    alwaysGenerateOverloads: false, // should overloads with full signatures like deposit(uint256) be generated always, even if there are no overloads?
    externalArtifacts: ["externalArtifacts/*.json"], // optional array of glob patterns with external artifacts to process (for example external libs from node_modules)
    dontOverrideCompile: false, // defaults to false
  },
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
      accounts: {
        mnemonic: 'test test test test test test test test test test test test',
        initialIndex: 0,
      },

    },
    localhost: {
      allowUnlimitedContractSize: true
    },
    zhejiang: {
      url: "https://rpc.zhejiang.ethpandaops.io",
      accounts: {
        mnemonic: 'test test test test test test test test test test test junk',
        initialIndex: 0,
      },
      gasPrice: "auto",
      timeout: 1000000
    },
  }
 
  
};

export default config;
