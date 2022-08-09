// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.6;

import '@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol';
import './GardenUnipoolTokenDistributor.sol';
import './interfaces/ITokenManager.sol';

contract GIVpower is GardenUnipoolTokenDistributor, IERC20MetadataUpgradeable {
    using SafeMathUpgradeable for uint256;

    uint256 public constant INITIAL_DATE = 1654415235; // block 22501098
    uint256 public constant ROUND_DURATION = 14 days;
    uint256 public constant MAX_LOCK_ROUNDS = 26;

    struct RoundBalance {
        uint256 unlockableTokenAmount;
        uint256 releasablePowerAmount;
    }

    struct UserLock {
        uint256 totalAmountLocked;
        mapping(uint256 => RoundBalance) roundBalances;
    }

    mapping(address => UserLock) public userLocks;

    error TokensAreLocked();
    error CannotUnlockUntilRoundIsFinished();
    error NotEnoughBalanceToLock();
    error ZeroLockRound();
    error LockRoundLimit();
    error TokenNonTransferable();

    event TokenLocked(address indexed account, uint256 amount, uint256 rounds, uint256 untilRound);
    event TokenUnlocked(address indexed account, uint256 amount, uint256 round);

    function _getToken() private view returns (IERC20) {
        return ITokenManager(getTokenManager()).token();
    }

    function lock(uint256 amount, uint256 rounds) external {
        if (rounds < 1) {
            revert ZeroLockRound();
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

        super.stake(msg.sender, _gainedPowerAmount);

        emit TokenLocked(msg.sender, amount, rounds, _endRound);
        emit Transfer(address(0), msg.sender, _gainedPowerAmount);
    }

    function unlock(address[] calldata acounts, uint256 round) external {
        if (round >= currentRound()) {
            revert CannotUnlockUntilRoundIsFinished();
        }

        for (uint256 i = 0; i < acounts.length; i++) {
            address _account = acounts[i];
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
            super.withdraw(_account, _releasablePowerAmount);

            _roundBalance.releasablePowerAmount = 0;
            _roundBalance.unlockableTokenAmount = 0;

            emit TokenUnlocked(_account, _unlockableTokenAmount, round);
            emit Transfer(_account, address(0), _releasablePowerAmount);
        }
    }

    function currentRound() public view returns (uint256) {
        return uint256(block.timestamp).sub(INITIAL_DATE).div(ROUND_DURATION);
        // currentRound = (now - INITIAL_DATE) / ROUND_DURATION
    }

    function roundEndsIn() external returns (uint256) {
        return uint256(block.timestamp).sub(INITIAL_DATE).mod(ROUND_DURATION);
    }

    function calculatePower(uint256 amount, uint256 rounds) public pure returns (uint256) {
        return amount.mul(_sqrt(rounds.add(1).mul(10 ** 18))).div(10 ** 9);
    }

    /**
     * @dev Same sqrt implementation as Uniswap v2
     */
    function _sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
        // else z = 0 (default value)
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

    function name() external override returns (string memory) {
        return 'GIVpower';
    }

    function symbol() external override returns (string memory) {
        return 'POW';
    }

    function decimals() external override returns (uint8) {
        return 18;
    }

    function totalSupply() external override returns (uint256) {
        return _totalSupply();
    }

    function balanceOf(address account) external view override returns (uint256) {
        return super._balanceOf(account);
    }

    function transfer(address, uint256) external override returns (bool) {
        revert TokenNonTransferable();
    }

    function allowance(address, address) external override returns (uint256) {
        return 0;
    }

    function approve(address, uint256) external override returns (bool) {
        revert TokenNonTransferable();
    }

    function transferFrom(address, address, uint256) external override returns (bool) {
        revert TokenNonTransferable();
    }

    function increaseAllowance(address, uint256) external returns (bool) {
        revert TokenNonTransferable();
    }

    function decreaseAllowance(address, uint256) external returns (bool) {
        revert TokenNonTransferable();
    }
}