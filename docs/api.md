# Solidity API

## EthStakePool

### Status

```solidity
enum Status {
  deposit,
  staked,
  exited
}
```

### currentStatus

```solidity
enum EthStakePool.Status currentStatus
```

### DEPOSIT_CONTRACT

```solidity
contract IDeposit DEPOSIT_CONTRACT
```

### miniumDepositAmount

```solidity
uint256 miniumDepositAmount
```

### operationAddr

```solidity
address operationAddr
```

### idToDepositAmount

```solidity
mapping(uint256 => uint256) idToDepositAmount
```

### totalDeposits

```solidity
uint256 totalDeposits
```

### feePercent

```solidity
uint16 feePercent
```

### constructor

```solidity
constructor() public
```

### RewardRound

```solidity
struct RewardRound {
  uint256 rewardAmount;
  uint256 totalClaimed;
  uint256 timestamp;
  uint256 totalDeposits;
  mapping(uint256 => bool) rewardsClaimedById;
}
```

### rounds

```solidity
mapping(uint256 => struct EthStakePool.RewardRound) rounds
```

### currentRewardRoundIndex

```solidity
uint256 currentRewardRoundIndex
```

### NewRewards

```solidity
event NewRewards(uint256 round, uint256 amount)
```

### rewardsClaimed

```solidity
event rewardsClaimed(uint256 round, uint256 nftid, address addr, uint256 amount)
```

### initialize

```solidity
function initialize(address _owner, address _eth2StakeAddr, address _operationAddr, uint256 _miniumDepositAmount) public
```

### depositETHToStake

```solidity
function depositETHToStake(bytes _pubkey, bytes _withdrawal_credentials, bytes _signature, bytes32 _deposit_data_root) public
```

### setExitStakeStatus

```solidity
function setExitStakeStatus() external
```

### withdrawStake

```solidity
function withdrawStake(uint256 _id) external
```

### participate

```solidity
function participate() external payable
```

### distributeRewards

```solidity
function distributeRewards() external payable
```

### claimRewards

```solidity
function claimRewards(uint256 _roundId, uint256 _nftId) public
```

### claimAllRewards

```solidity
function claimAllRewards(uint256 _nftId) public
```

### getClaimableRewards

```solidity
function getClaimableRewards(uint256 _roundId, uint256 _nftId) public view returns (uint256)
```

### displayDivision

```solidity
function displayDivision(uint256 decimalPlaces, uint256 numerator, uint256 denominator) public pure returns (string result)
```

### numToFixedLengthStr

```solidity
function numToFixedLengthStr(uint256 decimalPlaces, uint256 num) internal pure returns (string result)
```

### getAllClaimableRewards

```solidity
function getAllClaimableRewards(uint256 _nftId) public view returns (uint256)
```

### getStatusKeyByValue

```solidity
function getStatusKeyByValue(enum EthStakePool.Status _status) public pure returns (string)
```

### getImageURI

```solidity
function getImageURI(uint256 _tokenId) internal view returns (string)
```

### compileAttributes

```solidity
function compileAttributes(uint256 _tokenId) internal view returns (string)
```

### attributeForTypeAndValue

```solidity
function attributeForTypeAndValue(string traitType, string value, bool isNumber) internal pure returns (string)
```

### tokenURI

```solidity
function tokenURI(uint256 _tokenId) public view returns (string)
```

### TABLE

```solidity
string TABLE
```

### base64

```solidity
function base64(bytes data) internal pure returns (string)
```

### _getShare

```solidity
function _getShare(uint256 _id, uint256 _amount, uint256 _totalDeposits) internal view returns (uint256)
```

### _authorizeUpgrade

```solidity
function _authorizeUpgrade(address) internal view
```

### updateFeePercent

```solidity
function updateFeePercent(uint16 _percent) external
```

### fallback

```solidity
fallback() external payable
```

### receive

```solidity
receive() external payable
```

## EthStakePoolFactory

### stakingPools

```solidity
address[] stakingPools
```

### ethStakePoolImpAddress

```solidity
address ethStakePoolImpAddress
```

### deposit_contract_address

```solidity
address deposit_contract_address
```

### Create

```solidity
event Create(uint256 contractId, address contractAddress, address owner, address operationAddress, uint256 miniumDepositAmount)
```

### constructor

```solidity
constructor(address _ethStakePoolImpAddress, address _deposit_contract_address) public
```

### setNewStakePoolAddress

```solidity
function setNewStakePoolAddress(address _newethStakePoolImpAddress) public
```

### numberOfStakingPools

```solidity
function numberOfStakingPools() public view returns (uint256)
```

### create

```solidity
function create(address _owner, address _operationAddr, uint256 _miniumDepositAmount) public returns (address)
```

### getPoolByIndex

```solidity
function getPoolByIndex(uint256 _index) public view returns (address)
```

### deploy

```solidity
function deploy(address _logic, bytes _data, bytes32 _salt) private returns (address)
```

## EthStakePoolProxy

### constructor

```solidity
constructor(address logic, bytes data) public
```

## IDeposit

Interface of the official Deposit contract from the ETH
         Foundation.

### deposit

```solidity
function deposit(bytes pubkey, bytes withdrawal_credentials, bytes signature, bytes32 deposit_data_root) external payable
```

Submit a Phase 0 DepositData object.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| pubkey | bytes | - A BLS12-381 public key. |
| withdrawal_credentials | bytes | - Commitment to a public key for withdrawals. |
| signature | bytes | - A BLS12-381 signature. |
| deposit_data_root | bytes32 | - The SHA-256 hash of the SSZ-encoded DepositData object.                            Used as a protection against malformed input. |

## IDepositContract

This is the Ethereum 2.0 deposit contract interface.
For more information see the Phase 0 specification under https://github.com/ethereum/eth2.0-specs

### DepositEvent

```solidity
event DepositEvent(bytes pubkey, bytes withdrawal_credentials, bytes amount, bytes signature, bytes index)
```

A processed deposit event.

### deposit

```solidity
function deposit(bytes pubkey, bytes withdrawal_credentials, bytes signature, bytes32 deposit_data_root) external payable
```

Submit a Phase 0 DepositData object.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| pubkey | bytes | A BLS12-381 public key. |
| withdrawal_credentials | bytes | Commitment to a public key for withdrawals. |
| signature | bytes | A BLS12-381 signature. |
| deposit_data_root | bytes32 | The SHA-256 hash of the SSZ-encoded DepositData object. Used as a protection against malformed input. |

### get_deposit_root

```solidity
function get_deposit_root() external view returns (bytes32)
```

Query the current deposit root hash.

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bytes32 | The deposit root hash. |

### get_deposit_count

```solidity
function get_deposit_count() external view returns (bytes)
```

Query the current deposit count.

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bytes | The deposit count encoded as a little endian 64-bit number. |

## ERC165

### supportsInterface

```solidity
function supportsInterface(bytes4 interfaceId) external pure returns (bool)
```

Query if a contract implements an interface

_Interface identification is specified in ERC-165. This function
 uses less than 30,000 gas._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| interfaceId | bytes4 | The interface identifier, as specified in ERC-165 |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool | `true` if the contract implements `interfaceId` and  `interfaceId` is not 0xffffffff, `false` otherwise |

## DepositContract

This is the Ethereum 2.0 deposit contract interface.
For more information see the Phase 0 specification under https://github.com/ethereum/eth2.0-specs

### DEPOSIT_CONTRACT_TREE_DEPTH

```solidity
uint256 DEPOSIT_CONTRACT_TREE_DEPTH
```

### MAX_DEPOSIT_COUNT

```solidity
uint256 MAX_DEPOSIT_COUNT
```

### branch

```solidity
bytes32[32] branch
```

### deposit_count

```solidity
uint256 deposit_count
```

### zero_hashes

```solidity
bytes32[32] zero_hashes
```

### constructor

```solidity
constructor() public
```

### get_deposit_root

```solidity
function get_deposit_root() external view returns (bytes32)
```

Query the current deposit root hash.

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bytes32 | The deposit root hash. |

### get_deposit_count

```solidity
function get_deposit_count() external view returns (bytes)
```

Query the current deposit count.

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bytes | The deposit count encoded as a little endian 64-bit number. |

### deposit

```solidity
function deposit(bytes pubkey, bytes withdrawal_credentials, bytes signature, bytes32 deposit_data_root) external payable
```

Submit a Phase 0 DepositData object.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| pubkey | bytes | A BLS12-381 public key. |
| withdrawal_credentials | bytes | Commitment to a public key for withdrawals. |
| signature | bytes | A BLS12-381 signature. |
| deposit_data_root | bytes32 | The SHA-256 hash of the SSZ-encoded DepositData object. Used as a protection against malformed input. |

### supportsInterface

```solidity
function supportsInterface(bytes4 interfaceId) external pure returns (bool)
```

Query if a contract implements an interface

_Interface identification is specified in ERC-165. This function
 uses less than 30,000 gas._

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| interfaceId | bytes4 | The interface identifier, as specified in ERC-165 |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| [0] | bool | `true` if the contract implements `interfaceId` and  `interfaceId` is not 0xffffffff, `false` otherwise |

### to_little_endian_64

```solidity
function to_little_endian_64(uint64 value) internal pure returns (bytes ret)
```

