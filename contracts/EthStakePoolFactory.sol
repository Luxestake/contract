pragma solidity ^0.8.17;
import "@openzeppelin/contracts/access/Ownable.sol";
import "./EthStakePoolProxy.sol";
import "./EthStakePool.sol";

/**
 * @author  .
 * @title   factory contract to create the staking pool.
 * @dev     .
 * @notice  .
 */

contract EthStakePoolFactory is Ownable {
    address[] public stakingPools;
    address ethStakePoolImpAddress;

    address public constant deposit_contract_address =
        0x00000000219ab540356cBB839Cbe05303d7705Fa;

    event Create(
        uint indexed contractId,
        address indexed contractAddress,
        address owner,
        address operationAddress,
        uint256 miniumDepositAmount
    );

    constructor(address _ethStakePoolImpAddress) {
        require(_ethStakePoolImpAddress != address(0), "zero address");
        ethStakePoolImpAddress = _ethStakePoolImpAddress;
    }

    /**
     * @notice  set the new logic address for staking pool.
     * @dev     .
     * @param   _newethStakePoolImpAddress  .
     */
    function setNewStakePoolAddress(address _newethStakePoolImpAddress)
        public
        onlyOwner
    {
        require(_newethStakePoolImpAddress != address(0), "zero address");
        ethStakePoolImpAddress = _newethStakePoolImpAddress;
    }

    function numberOfStakingPools() public view returns (uint) {
        return stakingPools.length;
    }

    /**
     * @notice  using this function to create staking pool contract.
     * @dev     .
     * @param   _owner  .
     * @param   _operationAddr  .
     * @param   _miniumDepositAmount  .
     */
    function create(
        address _owner,
        address _operationAddr,
        uint256 _miniumDepositAmount
    ) public onlyOwner returns(address){
        uint256 poolId = numberOfStakingPools();
        address newPool = deploy(
            ethStakePoolImpAddress,
            new bytes(0),
            bytes32(poolId)
        );
        EthStakePool(payable(newPool)).initialize(
            _owner,
            deposit_contract_address,
            _operationAddr,
            _miniumDepositAmount
        );
        emit Create(
            poolId,
            newPool,
            _owner,
            _operationAddr,
            _miniumDepositAmount
        );
        stakingPools.push(newPool);
        return newPool;
    }
    function deploy(
        address _logic,
        bytes memory _data,
        bytes32 _salt
    ) private returns (address) {
        // This syntax is a newer way to invoke create2 without assembly, you just need to pass salt
        // https://docs.soliditylang.org/en/latest/control-structures.html#salted-contract-creations-create2
        return address(new EthStakePoolProxy{salt: _salt}(_logic, _data));
    }
}
