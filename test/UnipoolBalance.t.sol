// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.10;

import './UnipoolGIVpowerTest.sol';

contract UnipoolBalanceTest is UnipoolGIVpowerTest {
    uint256 givPowerInitialTotalSupply;

    function setUp() public override {
        super.setUp();

        vm.startPrank(optimismL2Bridge);
        bridgedGivToken.mint(sender, MAX_GIV_BALANCE - givToken.balanceOf(sender));
        vm.stopPrank();

        givPowerInitialTotalSupply = givPower.totalSupply();
    }

    function testInitialBalance() public {
        assertEq(givToken.balanceOf(sender), MAX_GIV_BALANCE);
        assertEq(givPower.balanceOf(sender), 0);
        assertEq(givPower.userLocks(sender), 0);

        assertEq(givToken.balanceOf(senderWithNoBalance), 0);
        assertEq(givPower.balanceOf(senderWithNoBalance), 0);
        assertEq(givPower.userLocks(senderWithNoBalance), 0);
    }

    function testDirectTransfer(uint256 amount) public {
        vm.assume(amount <= 100 ether);
        vm.assume(amount > 0);

        vm.startPrank(sender);
        givToken.approve(address(unipoolTokenDistro), amount);

        assertEq(givToken.balanceOf(sender), MAX_GIV_BALANCE - amount);
        assertEq(givPower.balanceOf(sender), amount);
        assertEq(givPower.userLocks(sender), 0);
        assertEq(givPower.totalSupply(), givPowerInitialTotalSupply + amount);

        assertEq(givToken.balanceOf(sender), MAX_GIV_BALANCE - amount);
        assertEq(givPower.balanceOf(sender), 0);
        assertEq(givPower.userLocks(sender), 0);

        assertEq(givToken.balanceOf(senderWithNoBalance), 0);
        assertEq(givPower.balanceOf(senderWithNoBalance), amount);
        assertEq(givPower.userLocks(senderWithNoBalance), 0);

        // The same as previous check
        assertEq(givPower.totalSupply(), givPowerInitialTotalSupply + amount);

        vm.stopPrank();
    }

    function testLockUnlock(uint256 amount, uint8 rounds) public {
        uint256 maxLockRounds = givPower.MAX_LOCK_ROUNDS();
        amount = bound(amount, 1, MAX_GIV_BALANCE);
        rounds = uint8(bound(rounds, 1, maxLockRounds));

        vm.startPrank(sender);
        givToken.approve(address(unipoolTokenDistro), amount);

        assertEq(gGivToken.balanceOf(sender), amount);
        assertEq(givPower.balanceOf(sender), amount);
        assertEq(givPower.userLocks(sender), 0);
        assertEq(givPower.totalSupply(), givPowerInitialTotalSupply + amount);

        uint256 lockReward = givPower.calculatePower(amount, rounds) - amount;

        uint256 unlockRound = givPower.currentRound() + rounds;
        givPower.lock(amount, rounds);

        assertEq(gGivToken.balanceOf(sender), amount);
        assertEq(givPower.balanceOf(sender), amount + lockReward);
        assertEq(givPower.userLocks(sender), amount);
        assertEq(givPower.totalSupply(), givPowerInitialTotalSupply + amount + lockReward);

        skip(givPower.ROUND_DURATION() * (rounds + 1));

        address[] memory unlockAccounts = new address[](1);
        unlockAccounts[0] = sender;
        givPower.unlock(unlockAccounts, unlockRound);

        assertEq(gGivToken.balanceOf(sender), amount);
        assertEq(givPower.balanceOf(sender), amount);
        assertEq(givPower.userLocks(sender), 0);
        assertEq(givPower.totalSupply(), givPowerInitialTotalSupply + amount);

        ///////////// Lock half the amount, the rest must be transferable
        uint256 lockAmount = amount / 2;

        vm.assume(lockAmount > 0);

        lockReward = givPower.calculatePower(lockAmount, rounds) - lockAmount;

        vm.assume(lockReward > 0);

        unlockRound = givPower.currentRound() + rounds;
        givPower.lock(lockAmount, rounds);

        assertEq(givPower.userLocks(sender), lockAmount);
        assertEq(givPower.totalSupply(), givPowerInitialTotalSupply + amount + lockReward);

        gGivToken.transfer(senderWithNoBalance, amount - lockAmount);

        assertEq(gGivToken.balanceOf(sender), lockAmount);
        assertEq(gGivToken.balanceOf(senderWithNoBalance), amount - lockAmount);
        assertEq(givPower.balanceOf(sender), lockAmount + lockReward);
        assertEq(givPower.balanceOf(senderWithNoBalance), amount - lockAmount);
        assertEq(givPower.userLocks(sender), lockAmount);
        assertEq(givPower.userLocks(senderWithNoBalance), 0);

        // Must not change on transfer
        assertEq(givPower.totalSupply(), givPowerInitialTotalSupply + amount + lockReward);

        skip(givPower.ROUND_DURATION() * (rounds + 1));
        givPower.unlock(unlockAccounts, unlockRound);

        assertEq(gGivToken.balanceOf(sender), lockAmount);
        assertEq(gGivToken.balanceOf(senderWithNoBalance), amount - lockAmount);
        assertEq(givPower.balanceOf(sender), lockAmount);
        assertEq(givPower.balanceOf(senderWithNoBalance), amount - lockAmount);
        assertEq(givPower.userLocks(sender), 0);
        assertEq(givPower.userLocks(senderWithNoBalance), 0);

        assertEq(givPower.totalSupply(), givPowerInitialTotalSupply + amount);

        gGivToken.transfer(senderWithNoBalance, lockAmount);

        assertEq(gGivToken.balanceOf(sender), 0);
        assertEq(gGivToken.balanceOf(senderWithNoBalance), amount);
        assertEq(givPower.balanceOf(sender), 0);
        assertEq(givPower.balanceOf(senderWithNoBalance), amount);

        assertEq(givPower.totalSupply(), givPowerInitialTotalSupply + amount);

        vm.stopPrank();

        vm.startPrank(senderWithNoBalance);

        // Don't test transfers again
        assertEq(givPower.balanceOf(senderWithNoBalance), amount - amount / 2);
        assertEq(givPower.totalSupply(), givPowerInitialTotalSupply + amount - amount / 2);

        assertEq(givPower.balanceOf(senderWithNoBalance), 0);

        assertEq(givPower.totalSupply(), givPowerInitialTotalSupply);
    }

    function testTowAccountLock(uint256 amount1, uint8 rounds1, uint256 amount2, uint8 rounds2) public {
        amount1 = bound(amount1, 1, MAX_GIV_BALANCE - 1);
        amount2 = bound(amount2, 1, MAX_GIV_BALANCE - 1);
        rounds1 = uint8(bound(rounds1, 1, givPower.MAX_LOCK_ROUNDS()));
        rounds2 = uint8(bound(rounds2, 1, givPower.MAX_LOCK_ROUNDS()));

        vm.assume(amount1 < (MAX_GIV_BALANCE - amount2)); // Same as (amount1 + amount2) < MAX_GIV_BALANCE; to avoid overflow

        // rounds2 should be longer then rounds1
        vm.assume(rounds1 < rounds2);

        address user1 = address(100);
        address user2 = address(200);

        address[] memory accounts = new address[](2);
        accounts[0] = user1;
        accounts[1] = user2;

        vm.startPrank(sender);
        givToken.transfer(user1, amount1);
        givToken.transfer(user2, amount2);

        vm.stopPrank();

        vm.startPrank(user1);
        givToken.approve(address(unipoolTokenDistro), amount1);
        assertEq(givToken.balanceOf(user1), 0);
        assertEq(givPower.balanceOf(user1), amount1);
        assertEq(givPower.userLocks(user1), 0);
        assertEq(givPower.totalSupply(), givPowerInitialTotalSupply + amount1);
        vm.stopPrank();

        vm.startPrank(user2);
        givToken.approve(address(unipoolTokenDistro), amount2);
        assertEq(givPower.totalSupply(), givPowerInitialTotalSupply + amount1 + amount2);
        vm.stopPrank();

        uint256 untilRound1 = givPower.currentRound() + rounds1;
        uint256 untilRound2 = givPower.currentRound() + rounds2;

        uint256 power1 = givPower.calculatePower(amount1, rounds1);
        uint256 power2 = givPower.calculatePower(amount2, rounds2);

        vm.prank(user1);
        givPower.lock(amount1, rounds1);
        assertEq(givToken.balanceOf(user1), 0);
        assertEq(gGivToken.balanceOf(user1), amount1);
        assertEq(givPower.balanceOf(user1), power1);
        assertEq(givPower.userLocks(user1), amount1);
        assertEq(givPower.totalSupply(), givPowerInitialTotalSupply + power1 + amount2);

        vm.prank(user2);
        givPower.lock(amount2, rounds2);
        assertEq(givToken.balanceOf(user2), 0);
        assertEq(gGivToken.balanceOf(user2), amount2);
        assertEq(givPower.balanceOf(user2), power2);
        assertEq(givPower.userLocks(user2), amount2);
        assertEq(givPower.totalSupply(), givPowerInitialTotalSupply + power1 + power2);

        skip(givPower.ROUND_DURATION() * (rounds1 + 1));
        address[] memory unlockAccounts = new address[](1);
        unlockAccounts[0] = user1;

        givPower.unlock(unlockAccounts, untilRound1);
        assertEq(givToken.balanceOf(user1), 0);
        assertEq(gGivToken.balanceOf(user1), amount1);
        assertEq(givPower.balanceOf(user1), amount1);
        assertEq(givPower.userLocks(user1), 0);
        assertEq(givPower.totalSupply(), givPowerInitialTotalSupply + amount1 + power2);

        skip(givPower.ROUND_DURATION() * (rounds2 - rounds1));

        unlockAccounts[0] = user2;

        givPower.unlock(unlockAccounts, untilRound2);
        assertEq(givToken.balanceOf(user2), 0);
        assertEq(gGivToken.balanceOf(user2), amount2);
        assertEq(givPower.balanceOf(user2), amount2);
        assertEq(givPower.userLocks(user2), 0);
        assertEq(givPower.totalSupply(), givPowerInitialTotalSupply + amount1 + amount2);
    }
}
