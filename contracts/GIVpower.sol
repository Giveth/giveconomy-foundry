// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.6;

import './GardenTokenLock.sol';
import './interfaces/IGardenUnipool.sol';

contract GIVpower is GardenTokenLock {
    using SafeMathUpgradeable for uint256;

    IGardenUnipool public gardenUnipool;

    mapping(address => mapping(uint256 => uint256)) public _powerUntilRound;

    event PowerLocked(address account, uint256 powerAmount, uint256 rounds, uint256 untilRound);
    event PowerUnlocked(address account, uint256 powerAmount, uint256 round);

    function initialize(
        uint256 _initialDate,
        uint256 _roundDuration,
        address _tokenManager,
        address _gardenUnipool
    ) public initializer {
        __GardenTokenLock_init(_initialDate, _roundDuration, _tokenManager);
        gardenUnipool = IGardenUnipool(_gardenUnipool);
    }

    function lock(uint256 _amount, uint256 _rounds) public virtual override {
        // we check the amount is lower than the lockable amount in the parent's function
        super.lock(_amount, _rounds);
        uint256 round = currentRound().add(_rounds);
        uint256 powerAmount = calculatePower(_amount, _rounds);
        _powerUntilRound[msg.sender][round] = _powerUntilRound[msg.sender][round].add(powerAmount);
        if (powerAmount > _amount) {
            gardenUnipool.stakeGivPower(msg.sender, powerAmount - _amount);
        }
        emit PowerLocked(msg.sender, powerAmount, _rounds, round);
    }

    function unlock(address[] calldata _locks, uint256 _round)
        public
        virtual
        override
        returns (uint256[] memory unlockedAmounts)
    {
        unlockedAmounts = super.unlock(_locks, _round);
        // we check the round has passed in the parent's function
        for (uint256 i = 0; i < _locks.length; i++) {
            address _lock = _locks[i];
            uint256 powerAmount = _powerUntilRound[_lock][_round];
            uint256 unlockedAmount = unlockedAmounts[i];
            if (powerAmount > unlockedAmount) {
                gardenUnipool.withdrawGivPower(_lock, powerAmount - unlockedAmount);
            }
            _powerUntilRound[_lock][_round] = 0;
            emit PowerUnlocked(_lock, powerAmount, _round);
        }
    }

    function calculatePower(uint256 _amount, uint256 _rounds) public pure returns (uint256) {
        return _amount.mul(_sqrt(_rounds.add(1).mul(10**18))).div(10**9);
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
    }
}
