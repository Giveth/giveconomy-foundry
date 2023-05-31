// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.10;

import './GIVpowerTest.sol';

// To test Lock Edge Cases
contract LockTest is GIVpowerTest {
    function setUp() public override {
        super.setUp();

        vm.startPrank(omniBridge);
        givToken.mint(sender, MAX_GIV_BALANCE - givToken.balanceOf(sender));
        vm.stopPrank();
    }

    function testZeroAmountLock(uint8 rounds) public {
        rounds = uint8(bound(rounds, 1, givPower.MAX_LOCK_ROUNDS()));

        vm.expectRevert(GIVpower.ZeroLockAmount.selector);

        vm.prank(sender);
        givPower.lock(0, rounds);
    }

    function testZeroRoundLock(uint256 amount) public {
        amount = bound(amount, 1, MAX_GIV_BALANCE);

        vm.expectRevert(GIVpower.ZeroLockRound.selector);

        vm.prank(sender);
        givPower.lock(amount, 0);
    }

    function testRoundLockMoreThanLimit(uint256 amount, uint256 rounds) public {
        amount = bound(amount, 1, MAX_GIV_BALANCE);
        vm.assume(rounds > givPower.MAX_LOCK_ROUNDS());

        vm.expectRevert(GIVpower.LockRoundLimit.selector);

        vm.prank(sender);
        givPower.lock(amount, rounds);
    }

    function testNormalLock(uint256 amount, uint8 rounds) public {
        amount = bound(amount, 1, MAX_GIV_BALANCE);
        rounds = uint8(bound(rounds, 1, givPower.MAX_LOCK_ROUNDS()));

        vm.startPrank(sender);

        givToken.approve(address(tokenManager), amount);
        tokenManager.wrap(amount);

        uint256 untilRound = givPower.currentRound() + rounds;
        uint256 powerIncreaseAfterLock = givPower.calculatePower(amount, rounds) - amount;

        if (powerIncreaseAfterLock > 0) {
            vm.expectEmit(true, true, true, true);
            emit Staked(sender, powerIncreaseAfterLock);

            vm.expectEmit(true, true, true, true, address(givPower));
            emit Transfer(address(0), sender, powerIncreaseAfterLock);
        }

        vm.expectEmit(true, true, true, true);
        emit TokenLocked(sender, amount, rounds, untilRound);

        givPower.lock(amount, rounds);
    }
}
