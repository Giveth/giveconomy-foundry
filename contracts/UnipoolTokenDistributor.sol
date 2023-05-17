// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.6;

import "openzeppelin-contracts-upgradable-v4/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradable-v4/utils/math/MathUpgradeable.sol";
import "openzeppelin-contracts-upgradable-v4/utils/math/SafeMathUpgradeable.sol";
import "openzeppelin-contracts-upgradable-v4/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../Interfaces/IDistro.sol";

// Based on: https://github.com/Synthetixio/Unipool/tree/master/contracts
/*
 * changelog:
 *      * Added SPDX-License-Identifier
 *      * Update to solidity ^0.8.0
 *      * Update openzeppelin imports
 *      * IRewardDistributionRecipient integrated in Unipool and removed
 *      * Added virtual and override to stake and withdraw methods
 *      * Added constructors to LPTokenWrapper and Unipool
 *      * Change transfer to allocate (TokenVesting)
 *      * Added `stakeWithPermit` function for NODE and the BridgeToken
 */
contract LPTokenWrapper is Initializable {
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable public uni;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    function __LPTokenWrapper_initialize(IERC20Upgradeable _uni)
        public
        initializer
    {
        uni = _uni;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function stake(uint256 amount) public virtual {
        _totalSupply = _totalSupply.add(amount);
        _balances[msg.sender] = _balances[msg.sender].add(amount);
        uni.safeTransferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 amount) public virtual {
        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        uni.safeTransfer(msg.sender, amount);
    }
}

contract UnipoolTokenDistributor is LPTokenWrapper, OwnableUpgradeable {
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IDistro public tokenDistro;
    uint256 public duration;

    address public rewardDistribution;
    uint256 public periodFinish;
    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    // bytes4 private constant _PERMIT_SIGNATURE =
    //    bytes4(keccak256(bytes("permit(address,address,uint256,uint256,uint8,bytes32,bytes32)")));
    bytes4 private constant _PERMIT_SIGNATURE = 0xd505accf;
    // bytes4 private constant _PERMIT_SIGNATURE_BRIDGE =
    //    bytes4(keccak256(bytes("permit(address,address,uint256,uint256,bool,uint8,bytes32,bytes32)")));
    bytes4 private constant _PERMIT_SIGNATURE_BRIDGE = 0x8fcbaf0c;

    modifier onlyRewardDistribution() {
        require(
            _msgSender() == rewardDistribution,
            "Caller is not reward distribution"
        );
        _;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    function initialize(
        IDistro _tokenDistribution,
        IERC20Upgradeable _uni,
        uint256 _duration
    ) public initializer {
        __Ownable_init();
        __LPTokenWrapper_initialize(_uni);
        tokenDistro = _tokenDistribution;
        duration = _duration;
        periodFinish = 0;
        rewardRate = 0;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return MathUpgradeable.min(_getBlockTimestamp(), periodFinish);
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply() == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored.add(
                lastTimeRewardApplicable()
                    .sub(lastUpdateTime)
                    .mul(rewardRate)
                    .mul(1e18)
                    .div(totalSupply())
            );
    }

    function earned(address account) public view returns (uint256) {
        return
            balanceOf(account)
                .mul(rewardPerToken().sub(userRewardPerTokenPaid[account]))
                .div(1e18)
                .add(rewards[account]);
    }

    // stake visibility is public as overriding LPTokenWrapper's stake() function
    function stake(uint256 amount) public override updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0");
        super.stake(amount);
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) public override updateReward(msg.sender) {
        require(amount > 0, "Cannot withdraw 0");
        super.withdraw(amount);
        emit Withdrawn(msg.sender, amount);
    }

    function exit() external {
        withdraw(balanceOf(msg.sender));
        getReward();
    }

    function getReward() public updateReward(msg.sender) {
        uint256 reward = earned(msg.sender);
        if (reward > 0) {
            rewards[msg.sender] = 0;
            //token.safeTransfer(msg.sender, reward);
            tokenDistro.allocate(msg.sender, reward, true);
            emit RewardPaid(msg.sender, reward);
        }
    }

    function notifyRewardAmount(uint256 reward)
        external
        onlyRewardDistribution
        updateReward(address(0))
    {
        uint256 _timestamp = _getBlockTimestamp();
        if (_timestamp >= periodFinish) {
            rewardRate = reward.div(duration);
        } else {
            uint256 remaining = periodFinish.sub(_timestamp);
            uint256 leftover = remaining.mul(rewardRate);
            rewardRate = reward.add(leftover).div(duration);
        }
        lastUpdateTime = _timestamp;
        periodFinish = _timestamp.add(duration);
        emit RewardAdded(reward);
    }

    function setRewardDistribution(address _rewardDistribution)
        external
        onlyOwner
    {
        rewardDistribution = _rewardDistribution;
    }

    /**
     * @notice method that allows you to stake by using the permit method
     * @param amount the amount to be staked, it has to match the amount that appears in the signature
     * @param permit the bytes of the signed permit function call
     */
    function stakeWithPermit(uint256 amount, bytes calldata permit)
        public
        updateReward(msg.sender)
    {
        require(amount > 0, "Cannot stake 0");
        // we call without checking the result, in case it fails and he doesn't have enough balance
        // the following transferFrom should be fail. This prevents DoS attacks from using a signature
        // before the smartcontract call
        _permit(amount, permit);
        super.stake(amount);
        emit Staked(msg.sender, amount);
    }

    /**
     * @notice function to extract the selector of a bytes calldata
     * @param _data the calldata bytes
     */
    function getSelector(bytes memory _data) private pure returns (bytes4 sig) {
        assembly {
            sig := mload(add(_data, 32))
        }
    }

    /**
     * @notice function to call token permit function, since the token on xDAI has a different implementation
     * we need to distinguish between them
     * @param _amount the quantity that is expected to be allowed
     * @param _permitData the raw data of the call `permit` of the token
     */
    function _permit(uint256 _amount, bytes calldata _permitData)
        internal
        returns (bool success, bytes memory returndata)
    {
        bytes4 sig = getSelector(_permitData);

        if (sig == _PERMIT_SIGNATURE) {
            (
                address owner,
                address spender,
                uint256 value,
                uint256 deadline,
                uint8 v,
                bytes32 r,
                bytes32 s
            ) = abi.decode(
                    _permitData[4:],
                    (
                        address,
                        address,
                        uint256,
                        uint256,
                        uint8,
                        bytes32,
                        bytes32
                    )
                );
            require(
                owner == msg.sender,
                "UnipoolTokenDistributor: OWNER_NOT_EQUAL_SENDER"
            );
            require(
                spender == address(this),
                "UnipoolTokenDistributor: SPENDER_NOT_EQUAL_THIS"
            );
            require(value == _amount, "UnipoolTokenDistributor: WRONG_AMOUNT");

            /* solhint-disable avoid-low-level-calls avoid-call-value */
            return
                address(uni).call(
                    abi.encodeWithSelector(
                        _PERMIT_SIGNATURE,
                        owner,
                        spender,
                        value,
                        deadline,
                        v,
                        r,
                        s
                    )
                );
        } else if (sig == _PERMIT_SIGNATURE_BRIDGE) {
            (
                address _holder,
                address _spender,
                uint256 _nonce,
                uint256 _expiry,
                bool _allowed,
                uint8 v,
                bytes32 r,
                bytes32 s
            ) = abi.decode(
                    _permitData[4:],
                    (
                        address,
                        address,
                        uint256,
                        uint256,
                        bool,
                        uint8,
                        bytes32,
                        bytes32
                    )
                );
            require(
                _holder == msg.sender,
                "UnipoolTokenDistributor: OWNER_NOT_EQUAL_SENDER"
            );
            require(
                _spender == address(this),
                "UnipoolTokenDistributor: SPENDER_NOT_EQUAL_THIS"
            );
            return
                address(uni).call(
                    abi.encodeWithSelector(
                        _PERMIT_SIGNATURE_BRIDGE,
                        _holder,
                        _spender,
                        _nonce,
                        _expiry,
                        _allowed,
                        v,
                        r,
                        s
                    )
                );
        } else {
            revert("UnipoolTokenDistributor: NOT_VALID_CALL_SIGNATURE");
        }
    }

    /// @dev Internal method that returns the current block timestamp
    /// We expect this function call to be optimized away
    /// Mock implementations can override this to set a fixed block timestamp value
    /// @return The current block timestamp
    function _getBlockTimestamp() internal view virtual returns (uint256) {
        return block.timestamp;
    }
}
