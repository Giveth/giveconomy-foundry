// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.6;

import './GIVpowerTest.sol';

contract BalanceTest is GIVpowerTest {
    function setUp() public override {
        super.setUp();

        vm.startPrank(omniBridge);
        givToken.mint(sender, MAX_GIV_BALANCE - givToken.balanceOf(sender));
        vm.stopPrank();
    }

    function testInitialBalance() public {
        assertEq(givToken.balanceOf(sender), MAX_GIV_BALANCE);
        assertEq(gGivToken.balanceOf(sender), 0);
        assertEq(givPower.balanceOf(sender), 0);

        assertEq(givToken.balanceOf(senderWithNoBalance), 0);
        assertEq(gGivToken.balanceOf(senderWithNoBalance), 0);
        assertEq(givPower.balanceOf(senderWithNoBalance), 0);
    }

    function testDirectTransfer(uint256 amount) public {
        vm.assume(amount <= 100 ether);
        vm.assume(amount > 0);

        vm.startPrank(sender);
        givToken.approve(address(tokenManager), amount);

        tokenManager.wrap(amount);

        assertEq(givToken.balanceOf(sender), MAX_GIV_BALANCE - amount);
        assertEq(gGivToken.balanceOf(sender), amount);
        assertEq(givPower.balanceOf(sender), amount);

        gGivToken.transfer(senderWithNoBalance, amount);

        assertEq(givToken.balanceOf(sender), MAX_GIV_BALANCE - amount);
        assertEq(gGivToken.balanceOf(sender), 0);
        assertEq(givPower.balanceOf(sender), 0);

        assertEq(givToken.balanceOf(senderWithNoBalance), 0);
        assertEq(gGivToken.balanceOf(senderWithNoBalance), amount);
        assertEq(givPower.balanceOf(senderWithNoBalance), amount);

        vm.stopPrank();
    }

    function testLock(uint256 amount, uint8 rounds) public {
        uint256 maxLockRounds = givPower.MAX_LOCK_ROUNDS();

        vm.assume(amount < MAX_GIV_BALANCE);
        vm.assume(amount > 0);
        vm.assume(rounds <= maxLockRounds);
        vm.assume(rounds > 0);

        vm.startPrank(sender);
        givToken.approve(address(tokenManager), amount);
        tokenManager.wrap(amount);

        assertEq(gGivToken.balanceOf(sender), amount);
        assertEq(givPower.balanceOf(sender), amount);

        uint256 lockReward = givPower.calculatePower(amount, rounds) - amount;

        vm.assume(lockReward > 0);

        uint256 unlockRound = givPower.currentRound() + rounds;
        givPower.lock(amount, rounds);

        assertEq(gGivToken.balanceOf(sender), amount);
        assertEq(givPower.balanceOf(sender), amount + lockReward);

        skip(givPower.ROUND_DURATION() * (rounds + 1));

        address[] memory unlockAccounts = new address[](1);
        unlockAccounts[0] = sender;
        givPower.unlock(unlockAccounts, unlockRound);

        assertEq(givPower.balanceOf(sender), amount);

        ///////////// Lock half the amount, the rest must be transferable
        uint256 lockAmount = amount / 2;

        vm.assume(lockAmount > 0);

        lockReward = givPower.calculatePower(lockAmount, rounds) - lockAmount;

        vm.assume(lockReward > 0);

        unlockRound = givPower.currentRound() + rounds;
        givPower.lock(lockAmount, rounds);

        gGivToken.transfer(senderWithNoBalance, amount - lockAmount);

        assertEq(gGivToken.balanceOf(sender), lockAmount);
        assertEq(gGivToken.balanceOf(senderWithNoBalance), amount - lockAmount);
        assertEq(givPower.balanceOf(sender), lockAmount + lockReward);
        assertEq(givPower.balanceOf(senderWithNoBalance), amount - lockAmount);

        skip(givPower.ROUND_DURATION() * (rounds + 1));
        givPower.unlock(unlockAccounts, unlockRound);

        assertEq(gGivToken.balanceOf(sender), lockAmount);
        assertEq(gGivToken.balanceOf(senderWithNoBalance), amount - lockAmount);
        assertEq(givPower.balanceOf(sender), lockAmount);
        assertEq(givPower.balanceOf(senderWithNoBalance), amount - lockAmount);

        gGivToken.transfer(senderWithNoBalance, lockAmount);

        assertEq(gGivToken.balanceOf(sender), 0);
        assertEq(gGivToken.balanceOf(senderWithNoBalance), amount);
        assertEq(givPower.balanceOf(sender), 0);
        assertEq(givPower.balanceOf(senderWithNoBalance), amount);

        vm.stopPrank();

        vm.startPrank(senderWithNoBalance);

        // Don't test transfers again
        tokenManager.unwrap(amount / 2);
        assertEq(gGivToken.balanceOf(senderWithNoBalance), amount - amount / 2);
        assertEq(givPower.balanceOf(senderWithNoBalance), amount - amount / 2);

        tokenManager.unwrap(amount - amount / 2);
        assertEq(gGivToken.balanceOf(senderWithNoBalance), 0);
        assertEq(givPower.balanceOf(senderWithNoBalance), 0);

        vm.stopPrank();
    }
}
