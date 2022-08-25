// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.6;

import '@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol';
import 'solmate/utils/FixedPointMathLib.sol';
import './GardenUnipoolTokenDistributor.sol';
import './interfaces/ITokenManager.sol';

contract GIVpower is GardenUnipoolTokenDistributor, IERC20MetadataUpgradeable {
    using SafeMathUpgradeable for uint256;

    /// @dev Start time of the first round
    uint256 public constant INITIAL_DATE = 1654415235; // block 22501098
    /// @notice Duration of each round
    uint256 public constant ROUND_DURATION = 14 days;
    /// @notice Maximum number of rounds to lock
    uint256 public constant MAX_LOCK_ROUNDS = 26;

    /// @dev Represents balances of locked tokens and gained power till end of a round
    /// @param unlockableTokenAmount Total of all locked token unlockable after the corresponding round finishes
    /// @param releasablePowerAmount Total of gained power by locking releasable after the corresponding round finishes
    struct RoundBalance {
        uint256 unlockableTokenAmount;
        uint256 releasablePowerAmount;
    }

    /// @param totalAmountLocked the users total amount of locked (nontransferable) tokens
    /// @param roundBalances Mapping of round number to corresponding round balances
    struct UserLock {
        uint256 totalAmountLocked;
        mapping(uint256 => RoundBalance) roundBalances;
    }

    /// @notice Mapping with all accounts have locked tokens
    mapping(address => UserLock) public userLocks;

    /// Tokens are locked
    error TokensAreLocked();
    /// Must unlock after the round finishes
    error CannotUnlockUntilRoundIsFinished();
    /// Not enough unlocked tokens to lock
    error NotEnoughBalanceToLock();
    /// Must lock for positive number of rounds
    error ZeroLockRound();
    /// Must lock for positive amount
    error ZeroLockAmount();
    /// Locking has limitation on number of rounds - maxLockRounds
    error LockRoundLimit();
    /// Token is not transferable
    error TokenNonTransferable();

    /// Emitted when users lock their token
    event TokenLocked(address indexed account, uint256 amount, uint256 rounds, uint256 untilRound);
    /// Emitted when the user tokens locked till end of round are unlocked
    event TokenUnlocked(address indexed account, uint256 amount, uint256 round);

    /// @dev Used to fetch 1Hive Garden wrapped token by the help of Token Manager, gGIV for Giveth
    /// @return Garden GIV wrapped token (gGIV) address
    function _getToken() private view returns (IERC20) {
        return ITokenManager(getTokenManager()).token();
    }

    /// @notice Lock the user's unlocked tokens for a number rounds
    /// @param amount Amount of unlocked tokens to lock
    /// @param rounds Number of rounds to lock amount of tokens
    function lock(uint256 amount, uint256 rounds) external {
        if (rounds < 1) {
            revert ZeroLockRound();
        }
        if (amount == 0) {
            revert ZeroLockAmount();
        }
        if (rounds > MAX_LOCK_ROUNDS) {
            revert LockRoundLimit();
        }

        UserLock storage _userLock = userLocks[msg.sender];
        IERC20 token = _getToken();

        if (token.balanceOf(msg.sender).sub(_userLock.totalAmountLocked) < amount) {
            revert NotEnoughBalanceToLock();
        }

        uint256 _endRound = currentRound().add(rounds);
        RoundBalance storage _roundBalance = _userLock.roundBalances[_endRound];

        _userLock.totalAmountLocked = _userLock.totalAmountLocked.add(amount);
        _roundBalance.unlockableTokenAmount = _roundBalance.unlockableTokenAmount.add(amount);

        uint256 _gainedPowerAmount = calculatePower(amount, rounds).sub(amount);

        _roundBalance.releasablePowerAmount = _roundBalance.releasablePowerAmount.add(_gainedPowerAmount);

        if (_gainedPowerAmount > 0) {
            // Add power/farming benefit of locking
            super.stake(msg.sender, _gainedPowerAmount);
        }

        emit TokenLocked(msg.sender, amount, rounds, _endRound);
        emit Transfer(address(0), msg.sender, _gainedPowerAmount);
    }

    /// @notice Unlock tokens belongs to accounts which are locked till the end of round
    /// @param accounts List of accounts to unlock their tokens
    /// @param round The round number token are locked till the end of
    function unlock(address[] calldata accounts, uint256 round) external {
        if (round >= currentRound()) {
            revert CannotUnlockUntilRoundIsFinished();
        }

        for (uint256 i = 0; i < accounts.length; i++) {
            address _account = accounts[i];
            UserLock storage _userLock = userLocks[_account];
            RoundBalance storage _roundBalance = _userLock.roundBalances[round];

            // @dev Based on the design, unlockableTokenAmount and releasablePowerAmount are both zero or both positive
            if (_roundBalance.unlockableTokenAmount == 0) {
                // && _roundBalance._releasablePowerAmount == 0
                continue;
            }

            uint256 _releasablePowerAmount = _roundBalance.releasablePowerAmount;
            uint256 _unlockableTokenAmount = _roundBalance.unlockableTokenAmount;

            _userLock.totalAmountLocked = _userLock.totalAmountLocked.sub(_unlockableTokenAmount);

            _roundBalance.releasablePowerAmount = 0;
            _roundBalance.unlockableTokenAmount = 0;

            if (_releasablePowerAmount > 0) {
                // Reduce power/farming benefit of locking
                super.withdraw(_account, _releasablePowerAmount);
            }

            emit TokenUnlocked(_account, _unlockableTokenAmount, round);
            emit Transfer(_account, address(0), _releasablePowerAmount);
        }
    }

    /// Returns the number of current round
    /// @return Current round number starting 0
    function currentRound() public view returns (uint256) {
        return uint256(block.timestamp).sub(INITIAL_DATE).div(ROUND_DURATION);
        // currentRound = (now - INITIAL_DATE) / ROUND_DURATION
    }

    /// Returns seconds till the end of current round
    /// @return The number of seconds till the end of current round
    function roundEndsIn() external view returns (uint256) {
        return uint256(block.timestamp).sub(INITIAL_DATE).mod(ROUND_DURATION);
    }

    /// Returns new power amount after locking for rounds
    /// @dev The precision of result is 10**9
    /// @param amount The amount of tokens to be locked
    /// @param rounds The number of rounds to lock token for
    /// @return The new amount of power gained by the same amount of token; amount plus extra gained value
    function calculatePower(uint256 amount, uint256 rounds) public pure returns (uint256) {
        return amount.mul(FixedPointMathLib.sqrt(rounds.add(1).mul(10 ** 18))).div(10 ** 9);
    }

    /**
     * @dev This function is called everytime a gGIV is wrapped/unwrapped
     * @param from 0x0 if we are wrapping gGIV
     * @param amount Number of gGIV that is wrapped/unwrapped
     */
    function _onTransfer(address from, address to, uint256 amount) internal override returns (bool) {
        require(super._onTransfer(from, to, amount));

        if (from != address(0)) {
            if (_getToken().balanceOf(from).sub(amount) < userLocks[from].totalAmountLocked) {
                revert TokensAreLocked();
            }
        }

        emit Transfer(from, to, amount);

        return true;
    }

    /// @inheritdoc IERC20MetadataUpgradeable
    function name() external pure override returns (string memory) {
        return 'GIVpower';
    }

    /// @inheritdoc IERC20MetadataUpgradeable
    function symbol() external pure override returns (string memory) {
        return 'POW';
    }

    /// @inheritdoc IERC20MetadataUpgradeable
    function decimals() external pure override returns (uint8) {
        return 18;
    }

    /// @inheritdoc IERC20Upgradeable
    function totalSupply() external view override returns (uint256) {
        return _totalSupply();
    }

    /// @inheritdoc IERC20Upgradeable
    function balanceOf(address account) external view override returns (uint256) {
        return super._balanceOf(account);
    }

    /// Token is not transferable
    function transfer(address, uint256) external pure override returns (bool) {
        revert TokenNonTransferable();
    }

    /// Token is not transferable
    function allowance(address, address) external pure override returns (uint256) {
        return 0;
    }

    /// Token is not transferable
    function approve(address, uint256) external pure override returns (bool) {
        revert TokenNonTransferable();
    }

    /// Token is not transferable
    function transferFrom(address, address, uint256) external pure override returns (bool) {
        revert TokenNonTransferable();
    }

    /// Token is not transferable
    function increaseAllowance(address, uint256) external pure returns (bool) {
        revert TokenNonTransferable();
    }

    /// Token is not transferable
    function decreaseAllowance(address, uint256) external pure returns (bool) {
        revert TokenNonTransferable();
    }
}
