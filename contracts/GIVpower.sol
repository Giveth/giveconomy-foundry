// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.6;

import "./GIVUnipool.sol";
import "./GardenTokenLock.sol";

contract GIVpower is GardenTokenLock, GIVUnipool {
    using SafeMathUpgradeable for uint256;

    mapping(address => mapping(uint256 => uint256)) public _powerUntilRound;

    function initialize(
        uint256 _initialDate,
        uint256 _roundDuration,
        address _tokenManager,
        address _tokenDistribution,
        uint256 _duration
    ) initializer public {
      __GardenTokenLock_init(_initialDate, _roundDuration, _tokenManager);
      __GIVUnipool_init(_tokenDistribution, _duration);
    }

    function lock(uint256 _amount, uint256 _rounds) public virtual override {
        // we check the amount is lower than the lockable amount in the parent's function
        super.lock(_amount, _rounds);
        uint256 round = currentRound().add(_rounds);
        uint256 powerAmount = calculatePower(_amount, _rounds);
        _powerUntilRound[msg.sender][round] = _powerUntilRound[msg.sender][round].add(powerAmount);
        super.stake(msg.sender, powerAmount);
    }


    function unlock(address[] calldata _locks, uint256 _round) public virtual override {
        // we check the round has passed in the parent's function
        super.unlock(_locks, _round);
        for (uint i = 0; i < _locks.length; i++) {
            address _lock = _locks[i];
            uint256 powerAmount = _powerUntilRound[_lock][_round];
            super.withdraw(_lock, powerAmount);
            _powerUntilRound[_lock][_round] = 0;
        }
    }

    function calculatePower(uint256 _amount, uint256 _rounds) public pure returns (uint256) {
        return _amount.mul(_sqrt(_rounds.add(1)));
    }

    /**
     * @dev Same sqrt implementation as Uniswap v2
     */
    function _sqrt(uint y) internal pure returns (uint256 z) {
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