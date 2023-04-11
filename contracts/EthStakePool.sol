pragma solidity ^0.8.17;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721RoyaltyUpgradeable.sol";
import "./interfaces/IDeposit.sol";

/**
 * @author  .
 * @title   Eth Stake Pool.
 * @dev     .
 * @notice  the logic contract for staking pool that user can particate.
 */

contract EthStakePool is
    ERC721EnumerableUpgradeable,
    ERC721RoyaltyUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;
    CountersUpgradeable.Counter private tokenIds;
    /*
       deposit: the pool collect user eth for eth2 staking
       staked: the pool start eth2 staking
       failed: the pool failed to collect enough eth for eth2 staking
       dismiss: the pool is dismissed and user get eth back
    */
    enum Status {
        deposit,
        staked,
        failed,
        dismiss
    }
    using StringsUpgradeable for uint256;
    Status currentStatus;
    IDeposit DEPOSIT_CONTRACT;
    uint256 public miniumDepositAmount;
    address public operationAddr;
    mapping(uint256 => uint256) public idToDepositAmount;
    uint256 public totalDeposits;
    uint256 public dismissPoolEthAmount;
    // 100 means 1%
    uint16 public feePercent;

    uint16 public nftFee;

    uint256 public historyRewardsAccumulated;
    uint256 public userClaimRewardsAccumulated;

    constructor() {
        _disableInitializers();
    }

    struct RewardRound {
        uint256 rewardAmount;
        uint256 totalClaimed;
        uint256 timestamp;
        uint256 totalDeposits;
        mapping(uint256 => bool) rewardsClaimedById;
    }

    mapping(uint256 => RewardRound) rounds;

    uint256 currentRewardRoundIndex;

    event NewRewards(uint256 indexed round, uint256 indexed amount);
    event rewardsClaimed(
        uint256 indexed round,
        uint256 nftid,
        address addr,
        uint256 amount
    );

    /**
     * @notice  initialize the pool with basic settings, such as fee, operation address
     * @dev     nft start with 1, so the first nft id is 1
     * @param   _owner can upgrade the contract, set the operation address .
     * @param   _eth2StakeAddr  the offical eth2 deposit contract.
     * @param   _operationAddr  setting this address for basic pool opearion, for example, change pool status, distribute rewards.
     * @param   _miniumDepositAmount  minimum eth that user can particate.
     */
    function initialize(
        address _owner,
        address _eth2StakeAddr,
        address _operationAddr,
        uint256 _miniumDepositAmount
    ) public initializer {
        __ERC721_init("ETHStakePool", "ESP");
        __ERC721Enumerable_init();
        __ERC721Royalty_init();
        __ReentrancyGuard_init();
        __Ownable_init();
        //default operation fee 1%
        feePercent = 100;
        //default nft trade fee 2%
        nftFee = 200;
        setDefaultRoyalty(_owner, nftFee);
        transferOwnership(_owner);
        require(_operationAddr != address(0), "zero address");
        operationAddr = _operationAddr;
        currentStatus = Status.deposit;
        DEPOSIT_CONTRACT = IDeposit(_eth2StakeAddr);
        miniumDepositAmount = _miniumDepositAmount;

        // default nft start from 1
        tokenIds.increment();
        userClaimRewardsAccumulated = 0;
        historyRewardsAccumulated = 0;
    }

     /**
      * @notice  .
      * @dev    ACL: operator modifiter.
      */
     modifier onlyOperator() {
        require(operationAddr == msg.sender, "not operator");
        _;
    }


    /**
     * @notice  the paramater to call offical deposit contract referencen: https://github.com/ethereum/consensus-specs/blob/dev/specs/phase0/deposit-contract.md.
     * @dev     the first two bytes of this credential are known as the withdrawal prefix. 
     *          the prefix for withdrawal credential should be 0x01 format.
     *          the function check if the witdrwal credential setting to the pool itself which means Partial withdrawals and full withdrawals from the eth2.0, the eth always go back to the pool itself.
     *          the function check if the pool has enough eth to deposit. 
     *          
     * @param   _pubkey  generated using https://github.com/ethereum/staking-deposit-cli.
     * @param   _withdrawal_credentials  .
     * @param   _signature  .
     * @param   _deposit_data_root  .
     */
    function depositETHToStake(
        bytes calldata _pubkey,
        bytes calldata _withdrawal_credentials,
        bytes calldata _signature,
        bytes32 _deposit_data_root
    ) public onlyOperator {
        require(currentStatus == Status.deposit, "status error");
        require(address(this).balance >= 32 ether, "balance is not enough");
        currentStatus = Status.staked;
        uint256 value = 32 ether;
        bytes1 withdrawPrefix = bytes1(_withdrawal_credentials[0:1]);
        require(withdrawPrefix == 0x01, "withdraw address prefix error");
        address withdrawAddr = address(bytes20(_withdrawal_credentials[12: 32]));
        require(withdrawAddr == address(this), "withdraw address shoud be pool");
        DEPOSIT_CONTRACT.deposit{value: value}(
            _pubkey,
            _withdrawal_credentials,
            _signature,
            _deposit_data_root
        );
        // send the rest to operation address
        if (address(this).balance > 0) {
            payable(operationAddr).transfer(address(this).balance);
        }
    }

    /**
     * @notice  when we do full withdrawals (exit validation), the operatior change the pool status to dismiss which allows user to burn the nft and get the ether back.
     * @dev     .
     * @param   _dismissPoolEthAmount  .
     */
    function dismissPool(uint256 _dismissPoolEthAmount)
        external
        onlyOperator
    {
        require(
            currentStatus == Status.staked,
            "only in staked status can dismiss pool"
        );
        dismissPoolEthAmount = _dismissPoolEthAmount;
        currentStatus = Status.dismiss;
    }

    /**
     * @notice  when the pool is in dismiss status, user can burn the nft to get the eth back.
     *          if there is any rewards unclaimed, perform claim as well.
     * @dev     .
     * @param   _id  .
     */
    function exitFromDismissPool(uint256 _id) external nonReentrant {
        require(currentStatus == Status.dismiss, "not in dismiss status");
        require(msg.sender == ownerOf(_id), "not the owner");
        uint256 checkClaimableRewards = getAllClaimableRewards(_id);
        if (checkClaimableRewards > 0) {
            _claimRewards(_id);
        }

        uint256 ethBackAmount = _getShare(
            _id,
            dismissPoolEthAmount,
            totalDeposits
        );
        require(
            address(this).balance >= ethBackAmount,
            "balance is not enough"
        );
        totalDeposits -= idToDepositAmount[_id];
        dismissPoolEthAmount -= ethBackAmount;
        idToDepositAmount[_id] = 0;
        payable(msg.sender).transfer(ethBackAmount);
        _burn(_id);
    }

    /**
     * @notice  operator set the pool to failed when the pool cannot collect the 32 eth to partitipate the eth2.0 staking.
     * @dev     .
     */
    function setFailedStatus() external onlyOperator {
        currentStatus = Status.failed;
    }

    /**
     * @notice  the pool cannot collect 32 eth for eth2.0 staking, user call whis function to get the eth back.
     * @dev     .
     * @param   _id  .
     */
    function exitFromFailedPool(uint256 _id) external nonReentrant {
        require(currentStatus == Status.failed, "not in failed status");
        require(msg.sender == ownerOf(_id), "not the owner");
        uint256 depositAmount = idToDepositAmount[_id];
        require(
            address(this).balance >= depositAmount,
            "balance is not enough"
        );
        idToDepositAmount[_id] = 0;
        totalDeposits -= depositAmount;
        payable(msg.sender).transfer(depositAmount);
        _burn(_id);
    }

    /**
     * @notice  user call this function to particate eth staking.
     *          the user contribute the eth to the pool, the pool will deposit the eth to the eth2.0 staking contract.
     *          user can get the nft as the proof of participation.
     *          the nft store the user's share of the pool.
     *          the nft can be burned to get the eth back in the future when exit from validation.
     *          once the pool has 32 eth, user cannot contribute more eth to the pool.
     *          we set the minium deposit amount to prevent the user from contributing too small amount of eth.
     *          the pool will charge 1% fee for the user.
     *          the last user who particiate the pool, if the user contribute more the 32 eth, the pool will refund the extra eth to the user.
     * @dev     .
     */
    function participate() external payable nonReentrant {
        require(currentStatus == Status.deposit, "status error");
        require(
            msg.value >= miniumDepositAmount,
            "deposit amount is not enough"
        );
        require(totalDeposits < 32 ether, "pool full");
        uint256 id = tokenIds.current();
        uint256 poolRequired = ((32 ether - totalDeposits) *
            (10000 + feePercent)) / 10000;

        if (msg.value >= poolRequired) {
            uint256 fee = ((32 ether - totalDeposits) * feePercent) / 10000;
            uint256 depositAmount = (32 ether - totalDeposits);
            idToDepositAmount[id] = depositAmount;
            totalDeposits += depositAmount;
            payable(operationAddr).transfer(fee);
            uint256 refundAmount = msg.value - poolRequired;
            if (refundAmount > 0) {
                payable(msg.sender).transfer(refundAmount);
            }
        } else {
            uint256 fee = (msg.value * feePercent) / 10000;
            uint256 depositAmount = msg.value - fee;
            idToDepositAmount[id] = depositAmount;
            totalDeposits += depositAmount;
            payable(operationAddr).transfer(fee);
        }

        _mint(msg.sender, id);
        tokenIds.increment();
    }
    // only balance update in the pool, we have to mannualy trigger the rewards amount
    /**
     * @notice  accourding to the official eth2.0 withdrawal FAQ https://notes.ethereum.org/@launchpad/withdrawals-faq#Q-Do-Partial-withdrawals-happen-automatically. 
     * the particial withdraw is gasless operatoin, and it perform automically by design. there is no transaction send to the contract.
     * we use this function to manunaly trigger the rewards amount for the pool, that user can claim there staking rewards.
     * @dev     .
     */
    function distributeRewards() external onlyOperator nonReentrant {
        require(currentStatus == Status.staked, "status should be staked");
        uint256 currentRewards = address(this).balance - historyRewardsAccumulated + userClaimRewardsAccumulated;
        require(currentRewards > 0, "currentRewards needs > 0");

        uint256 rewards = currentRewards;
        RewardRound storage round = rounds[currentRewardRoundIndex];
        round.rewardAmount = rewards;
        round.timestamp = block.timestamp;
        round.totalDeposits = totalDeposits;
        emit NewRewards(currentRewardRoundIndex, rewards);
        currentRewardRoundIndex = currentRewardRoundIndex + 1;
        historyRewardsAccumulated += rewards;
    }

    /**
     * @notice  claim the rewards based on rewards round and nft id.
     * @dev     .
     * @param   _roundId  .
     * @param   _nftId  .
     */
    function _claimRewards(uint256 _roundId, uint256 _nftId) private {
        RewardRound storage round = rounds[_roundId];
        address tokenOwner = ownerOf(_nftId);
        require(msg.sender == tokenOwner, "wrong owner");
        require(round.rewardAmount > 0, "no rewards");
        require(!round.rewardsClaimedById[_nftId], "already claimed");
        uint256 rewards = round.rewardAmount;
        uint256 share = _getShare(_nftId, rewards, round.totalDeposits);
        round.rewardsClaimedById[_nftId] = true;
        round.totalClaimed += share;
        userClaimRewardsAccumulated += share; 
        payable(tokenOwner).transfer(share);
        emit rewardsClaimed(_roundId, _nftId, msg.sender, share);
    }

    /**
     * @notice  public function let user to call _claimRewards with nonReentrant guard.
     * @dev     .
     * @param   _roundId  .
     * @param   _nftId  .
     */
    function claimRewards(uint256 _roundId, uint256 _nftId)
        public
        nonReentrant
    {
        _claimRewards(_roundId, _nftId);
    }

    /**
     * @notice  claim all the rewards based on the nft id.
     * @dev     .
     * @param   _nftId  .
     */
    function _claimRewards(uint256 _nftId) private {
        address tokenOwner = ownerOf(_nftId);
        require(msg.sender == tokenOwner, "wrong owner");
        for (uint256 index = 0; index < currentRewardRoundIndex; index++) {
            RewardRound storage round = rounds[index];
            if (!round.rewardsClaimedById[_nftId]) {
                _claimRewards(index, _nftId);
            }
        }
    }

    /**
     * @notice  public fuction let user call _claimRewards with nonReentrant guard.
     * @dev     .
     * @param   _nftId  .
     */
    function claimRewards(uint256 _nftId) public nonReentrant {
        _claimRewards(_nftId);
    }

    /**
     * @notice  claim all the rewards based on user address.
     * @dev     .
     */
    function claimRewards() public nonReentrant {
        uint256 balance = balanceOf(msg.sender);
        for (uint256 i; i < balance; i++) {
            uint256 id = tokenOfOwnerByIndex(msg.sender, i);
            _claimRewards(id);
        }
    }

    /**
     * @notice  view function to get how much rewards.
     * @dev     .
     * @param   _roundId  .
     * @param   _nftId  .
     * @return  uint256  .
     */
    function getClaimableRewards(uint256 _roundId, uint256 _nftId)
        public
        view
        returns (uint256)
    {
        RewardRound storage round = rounds[_roundId];
        if (round.rewardsClaimedById[_nftId]) {
            return 0;
        }
        uint256 rewards = round.rewardAmount;
        uint256 share = _getShare(_nftId, rewards, round.totalDeposits);
        return share;
    }

    /**
     * @notice  helper fucntion to generate nft svg data.
     * @dev     .
     * @param   decimalPlaces  .
     * @param   numerator  .
     * @param   denominator  .
     * @return  result  .
     */
    function displayDivision(
        uint256 decimalPlaces,
        uint256 numerator,
        uint256 denominator
    ) public pure returns (string memory result) {
        uint256 factor = 10**decimalPlaces;
        uint256 quotient = numerator / denominator;
        bool rounding = 2 * ((numerator * factor) % denominator) >= denominator;
        uint256 remainder = ((numerator * factor) / denominator) % factor;
        if (rounding) {
            remainder += 1;
        }
        result = string(
            abi.encodePacked(
                quotient.toString(),
                ".",
                numToFixedLengthStr(decimalPlaces, remainder)
            )
        );
        return result;
    }

    /**
     * @notice  helper fucntion to generate nft svg data.
     * @dev     .
     * @param   decimalPlaces  .
     * @param   num  .
     * @return  result  .
     */
    function numToFixedLengthStr(uint256 decimalPlaces, uint256 num)
        internal
        pure
        returns (string memory result)
    {
        bytes memory byteString;
        for (uint256 i = 0; i < decimalPlaces; i++) {
            uint256 remainder = num % 10;
            byteString = abi.encodePacked(remainder.toString(), byteString);
            num = num / 10;
        }
        result = string(byteString);
    }

    /**
     * @notice  view function to query all claimable rewards based on nft id.
     * @dev     .
     * @param   _nftId  .
     * @return  uint256  .
     */
    function getAllClaimableRewards(uint256 _nftId)
        public
        view
        returns (uint256)
    {
        uint256 totalrewards;
        for (uint256 index = 0; index < currentRewardRoundIndex; index++) {
            RewardRound storage round = rounds[index];
            if (!round.rewardsClaimedById[_nftId]) {
                totalrewards =
                    totalrewards +
                    getClaimableRewards(index, _nftId);
            }
        }
        return totalrewards;
    }

    /**
     * @notice  convert status enum to human readable string.
     * @dev     .
     * @param   _status  .
     * @return  string  .
     */
    function getStatusKeyByValue(Status _status)
        internal
        pure
        returns (string memory)
    {
        if (Status.deposit == _status) return "deposit";
        if (Status.staked == _status) return "staked";
        if (Status.failed == _status) return "failed";
        if (Status.dismiss == _status) return "dismiss";
        return "";
    }

    /**
     * @notice  get the current status for the pool.
     * @dev     .
     * @return  string  .
     */
    function getCurrentStatus() public view returns (string memory) {
        return getStatusKeyByValue(currentStatus);
    }

    /**
     * @notice  generate onchain svg for the nft.
     * @dev     .
     * @param   _tokenId  .
     * @return  string  .
     */
    function getImageURI(uint256 _tokenId)
        internal
        view
        returns (string memory)
    {
        return
            string(
                abi.encodePacked(
                    '<svg id="ethstakepool" width="100%" height="100%" version="1.1" viewBox="0 0 128 128" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">'
                    '<text font-family="monospace"><tspan x="2" y="4" font-size="0.25em">Staked Eth:</tspan><tspan id="g" x="25" y="4" font-size="0.25em">',
                    string(
                        abi.encodePacked(
                            displayDivision(
                                4,
                                idToDepositAmount[_tokenId],
                                1 ether
                            ),
                            " ETH"
                        )
                    ),
                    '</tspan></text><text font-family="monospace"><tspan x="2" y="9" font-size="0.25em">Status:</tspan><tspan id="b" x="25" y="9" font-size="0.25em">',
                    getStatusKeyByValue(currentStatus),
                    '</tspan></text><text font-family="monospace"><tspan x="2" y="13" font-size="0.15em">everyone can participate eth staking</tspan></text>',
                    "</svg>"
                )
            );
    }

    /**
     * @notice  generate nft arribute onchain.
     * @dev     .
     * @param   _tokenId  .
     * @return  string  .
     */
    function compileAttributes(uint256 _tokenId)
        internal
        view
        returns (string memory)
    {
        string memory attributes = string(
            abi.encodePacked(
                attributeForTypeAndValue(
                    "stake amount",
                    string(
                        abi.encodePacked(
                            displayDivision(
                                4,
                                idToDepositAmount[_tokenId],
                                1 ether
                            ),
                            " ETH"
                        )
                    ),
                    false
                ),
                ",",
                attributeForTypeAndValue(
                    "pool total deposits",
                    string(
                        abi.encodePacked(
                            displayDivision(4, totalDeposits, 1 ether),
                            " ETH"
                        )
                    ),
                    false
                ),
                ",",
                attributeForTypeAndValue(
                    "claimable rewards",
                    string(
                        abi.encodePacked(
                            displayDivision(
                                4,
                                getAllClaimableRewards(_tokenId),
                                1 ether
                            ),
                            " ETH"
                        )
                    ),
                    false
                )
            )
        );
        return string(abi.encodePacked("[", attributes, "]"));
    }

    function attributeForTypeAndValue(
        string memory traitType,
        string memory value,
        bool isNumber
    ) internal pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    '{"trait_type":"',
                    traitType,
                    '","value":',
                    isNumber ? "" : '"',
                    value,
                    isNumber ? "" : '"',
                    "}"
                )
            );
    }

    /**
     * @notice  ERC721 tokenURI.
     * @dev     .
     * @param   _tokenId  .
     * @return  string  .
     */
    function tokenURI(uint256 _tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(
            _exists(_tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );
        string memory metadata = string(
            abi.encodePacked(
                '{"name": "Eth Stake Pool #',
                _tokenId.toString(),
                '","description": "everyone can participate eth staking",',
                '"image": "data:image/svg+xml;base64,',
                base64(bytes(getImageURI(_tokenId))),
                '", "attributes":',
                compileAttributes(_tokenId),
                "}"
            )
        );

        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    base64(bytes(metadata))
                )
            );
    }

    string internal constant TABLE =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    function base64(bytes memory data) internal pure returns (string memory) {
        if (data.length == 0) return "";

        // load the table into memory
        string memory table = TABLE;

        // multiply by 4/3 rounded up
        uint256 encodedLen = 4 * ((data.length + 2) / 3);

        // add some extra buffer at the end required for the writing
        string memory result = new string(encodedLen + 32);

        assembly {
            // set the actual output length
            mstore(result, encodedLen)

            // prepare the lookup table
            let tablePtr := add(table, 1)

            // input ptr
            let dataPtr := data
            let endPtr := add(dataPtr, mload(data))

            // result ptr, jump over length
            let resultPtr := add(result, 32)

            // run over the input, 3 bytes at a time
            for {

            } lt(dataPtr, endPtr) {

            } {
                dataPtr := add(dataPtr, 3)

                // read 3 bytes
                let input := mload(dataPtr)

                // write 4 characters
                mstore(
                    resultPtr,
                    shl(248, mload(add(tablePtr, and(shr(18, input), 0x3F))))
                )
                resultPtr := add(resultPtr, 1)
                mstore(
                    resultPtr,
                    shl(248, mload(add(tablePtr, and(shr(12, input), 0x3F))))
                )
                resultPtr := add(resultPtr, 1)
                mstore(
                    resultPtr,
                    shl(248, mload(add(tablePtr, and(shr(6, input), 0x3F))))
                )
                resultPtr := add(resultPtr, 1)
                mstore(
                    resultPtr,
                    shl(248, mload(add(tablePtr, and(input, 0x3F))))
                )
                resultPtr := add(resultPtr, 1)
            }

            // padding with '='
            switch mod(mload(data), 3)
            case 1 {
                mstore(sub(resultPtr, 2), shl(240, 0x3d3d))
            }
            case 2 {
                mstore(sub(resultPtr, 1), shl(248, 0x3d))
            }
        }

        return result;
    }

    /**
     * @notice  calcuate the share based on the nft id.
     * @dev     .
     * @param   _id  .
     * @param   _amount  .
     * @param   _totalDeposits  .
     * @return  uint256  .
     */
    function _getShare(
        uint256 _id,
        uint256 _amount,
        uint256 _totalDeposits
    ) internal view returns (uint256) {
        return (_amount * idToDepositAmount[_id]) / _totalDeposits;
    }

    /**
     * @notice  only owner can upgrade the pool.
     * @dev     .
     */
    function _authorizeUpgrade(address) internal view override onlyOwner {}

    /**
     * @notice  operator set the fee for the pool.
     * @dev     .
     * @param   _percent  .
     */
    function updateFeePercent(uint16 _percent) external onlyOperator {
        require(_percent <= 10000, "input value is more than 100%");
        feePercent = _percent;
    }

    /**
     * @notice   send eth to contract incase something wrong, like missing rewards.
     * @dev     .
     * @param   _ethAmount  .
     */
    function topUp(uint256 _ethAmount) external payable onlyOperator {
        require(msg.value > 0, "rewards needs > 0");
        require(msg.value == _ethAmount, "wrong amount");
    }

    /**
     * @notice  only owner can change the operator address.
     * @dev     .
     * @param   _newOperationAddr  .
     */
    function updateOperationAddress(address _newOperationAddr)
        external
        onlyOwner
    {
        require(_newOperationAddr != address(0), "zero address");
        operationAddr = _newOperationAddr;
    }

    /**
     * @notice  ERC-2981 only specifies a way to signal royalty information and does not enforce its payment.
     * @dev     .
     * @param   receiver  .
     * @param   feeNumerator  .
     */
    function setDefaultRoyalty(address receiver, uint96 feeNumerator)
        public
        onlyOwner
    {
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    /**
     * @notice  operator set the mimum deposit amount.
     * @dev     .
     * @param   _newMiniumDepositAmount  .
     */
    function updateMiniumDepositAmount(uint256 _newMiniumDepositAmount)
        external
        onlyOperator
    {
        miniumDepositAmount = _newMiniumDepositAmount;
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) {
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721RoyaltyUpgradeable, ERC721EnumerableUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @notice  burn function for the nft.
     * @dev     .
     * @param   tokenId  .
     */
    function _burn(uint256 tokenId)
        internal
        override(ERC721Upgradeable, ERC721RoyaltyUpgradeable)
    {
        super._burn(tokenId);
    }

}
