/**
 * Contract has the most of the functionalities of UnipoolTokenDistributor contract, but is updated
 * to be compatible with token-manager-app of 1Hive.
 * 1. Stake/Withdraw methods are updated to internal type.
 * 2. Methods related to permit are removed.
 * 3. Stake/Withdraw are update based on 1Hive unipool (https://github.com/1Hive/unipool/blob/master/contracts/Unipool.sol).
 * This PR was the guide: https://github.com/1Hive/unipool/pull/7/files
 */

// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.6;

import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol';
import './interfaces/IDistro.sol';

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

contract GIVUnipool is ERC20Upgradeable, OwnableUpgradeable {
    using SafeMathUpgradeable for uint256;

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

    error TokenNonTransferable();

    modifier onlyRewardDistribution() {
        require(_msgSender() == rewardDistribution, 'Caller is not reward distribution');
        _;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = claimableStream(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    function __GIVUnipool_init(address _tokenDistribution, uint256 _duration) public initializer {
        __Ownable_init();
        __ERC20_init('GIVpower', 'POW');
        tokenDistro = IDistro(_tokenDistribution);
        duration = _duration;
        periodFinish = 0;
        rewardRate = 0;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return MathUpgradeable.min(getTimestamp(), periodFinish);
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply() == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored.add(
                lastTimeRewardApplicable().sub(lastUpdateTime).mul(rewardRate).mul(1e18).div(totalSupply())
            );
    }

    /**
     * Function to get the current timestamp from the block
     */
    function getTimestamp() public view virtual returns (uint256) {
        return block.timestamp;
    }

    /**
     * Function to get the amount of tokens is transferred in the claim tx
     * @notice The difference between what this returns and what the claimableStream function returns
     *  will be locked in TokenDistro to be streamed and released gradually
     */
    function earned(address account) external view returns (uint256) {
        uint256 _totalEarned = claimableStream(account);
        uint256 _tokenDistroReleasedTokens = tokenDistro.globallyClaimableAt(getTimestamp());
        uint256 _tokenDistroTotalTokens = tokenDistro.totalTokens();

        return (_totalEarned * _tokenDistroReleasedTokens) / _tokenDistroTotalTokens;
    }

    // @dev This does the same thing the earned function of UnipoolTokenDistributor contract does.
    // Returns the exact amount will be allocated on TokenDistro
    function claimableStream(address account) public view returns (uint256) {
        return
            balanceOf(account).mul(rewardPerToken().sub(userRewardPerTokenPaid[account])).div(1e18).add(
                rewards[account]
            );
    }

    function stake(address user, uint256 amount) internal updateReward(user) {
        require(amount > 0, 'Cannot stake 0');
        _mint(user, amount);
        emit Staked(user, amount);
    }

    function withdraw(address user, uint256 amount) internal updateReward(user) {
        require(amount > 0, 'Cannot withdraw 0');
        _burn(user, amount);
        _getReward(user);
        emit Withdrawn(user, amount);
    }

    function getReward() public updateReward(msg.sender) {
        _getReward(msg.sender);
    }

    function _getReward(address user) internal {
        uint256 reward = claimableStream(user);
        if (reward > 0) {
            rewards[user] = 0;
            //token.safeTransfer(msg.sender, reward);
            tokenDistro.allocate(user, reward, true);
            emit RewardPaid(user, reward);
        }
    }

    function notifyRewardAmount(uint256 reward) external onlyRewardDistribution updateReward(address(0)) {
        uint256 _timestamp = getTimestamp();
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

    function setRewardDistribution(address _rewardDistribution) external onlyOwner {
        rewardDistribution = _rewardDistribution;
    }

    function transfer(address, uint256) public pure override returns (bool) {
        revert TokenNonTransferable();
    }

    function allowance(address, address) public pure override returns (uint256) {
        return 0;
    }

    function approve(address, uint256) public pure override returns (bool) {
        revert TokenNonTransferable();
    }

    function transferFrom(
        address,
        address,
        uint256
    ) public pure override returns (bool) {
        revert TokenNonTransferable();
    }

    function increaseAllowance(address, uint256) public pure override returns (bool) {
        revert TokenNonTransferable();
    }

    function decreaseAllowance(address, uint256) public pure override returns (bool) {
        revert TokenNonTransferable();
    }
}
