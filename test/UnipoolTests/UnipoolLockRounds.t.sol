// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.10;

import './UnipoolGIVpowerTest.sol';

contract LockRounds is UnipoolGIVpowerTest {
    function setUp() public override {
        super.setUp();
        vm.startPrank(optimismL2Bridge);
        bridgedGivToken.mint(sender, MAX_GIV_BALANCE - givToken.balanceOf(sender));
        vm.stopPrank();
    }

    function testUnlockInsideRound() public {
        uint256 roundDuration = givPower.ROUND_DURATION();
        address[] memory accounts = new address[](1);
        accounts[0] = sender;

        // Skip the rest of round
        skip(roundDuration - this.roundHasStartedInSeconds());

        // At the beginning of the round
        assertEq(this.roundHasStartedInSeconds(), 0);

        uint256 round = givPower.currentRound();

        vm.expectRevert(UnipoolGIVpower.CannotUnlockUntilRoundIsFinished.selector);
        givPower.unlock(accounts, round);

        // One second before round ends (at the edge of next round)
        skip(roundDuration - 1);

        assertEq(round, givPower.currentRound());

        vm.expectRevert(UnipoolGIVpower.CannotUnlockUntilRoundIsFinished.selector);
        givPower.unlock(accounts, round);

        // Move one second forward (beginning of the next round)
        skip(1);

        assertEq(round + 1, givPower.currentRound());
        givPower.unlock(accounts, round);
    }

    function testUnlockAdvanced(uint256 amount, uint8 rounds) public {
        uint256 maxLockRounds = givPower.MAX_LOCK_ROUNDS();
        uint256 roundDuration = givPower.ROUND_DURATION();

        rounds = uint8(bound(rounds, 1, maxLockRounds));
        amount = bound(amount, 1, MAX_GIV_BALANCE);

        uint256 lockRewards = givPower.calculatePower(amount, rounds) - amount;

        vm.startPrank(sender);

        givToken.approve(address(givPower), amount);

        console.log("this is the amount", amount);
        console.log("this is the user balance", givPower.balanceOf(sender));
        console.log("this is the user locks", givPower.userLocks(sender));
        givPower.stake(amount);
        console.log("this is the user balance", givPower.balanceOf(sender));


        givPower.lock(amount, rounds);

        uint256 untilRound = givPower.currentRound() + rounds;
        uint256 passedSeconds = this.roundHasStartedInSeconds();

        assertGt(
            roundDuration,
            passedSeconds,
            'Seconds passed from the start of round should be less than the round duration'
        );

        address[] memory accounts = new address[](1);
        accounts[0] = sender;

        vm.expectRevert(UnipoolGIVpower.CannotUnlockUntilRoundIsFinished.selector);
        givPower.unlock(accounts, untilRound);

        // vm.expectRevert(UnipoolGIVpower.TokensAreLocked.selector);
        // gGivToken.transfer(senderWithNoBalance, amount);

        console.log("this is the amount", amount);
        console.log("this is the user balance", givPower.balanceOf(sender));
        console.log("this is the user locks", givPower.userLocks(sender));
        
        // broken here
        vm.expectRevert(UnipoolGIVpower.TokensAreLocked.selector);
        givPower.withdraw(amount);
        // -----------------

        skip(rounds * roundDuration);

        vm.expectRevert(UnipoolGIVpower.CannotUnlockUntilRoundIsFinished.selector);
        givPower.unlock(accounts, untilRound);

        // vm.expectRevert(UnipoolGIVpower.TokensAreLocked.selector);
        // gGivToken.transfer(senderWithNoBalance, amount);

        vm.expectRevert(UnipoolGIVpower.TokensAreLocked.selector);
        givPower.withdraw(amount);

        skip(roundDuration - passedSeconds);

        if (lockRewards > 0) {
            vm.expectEmit(true, true, true, true);
            emit Withdrawn(sender, lockRewards);

            vm.expectEmit(true, true, true, true, address(givPower));
            emit Transfer(sender, address(0), lockRewards);
        }

        vm.expectEmit(true, true, true, true);
        emit TokenUnlocked(sender, amount, untilRound);

        givPower.unlock(accounts, untilRound);
    }

    function testLockForDifferentRounds(uint256 amount1, uint8 rounds1, uint256 amount2, uint8 rounds2) public {
        uint256 roundDuration = givPower.ROUND_DURATION();
        uint256 maxLockRounds = givPower.MAX_LOCK_ROUNDS();
        address[] memory accounts = new address[](1);
        accounts[0] = sender;

        rounds1 = uint8(bound(rounds1, 1, maxLockRounds));
        rounds2 = uint8(bound(rounds2, 1, maxLockRounds));
        // rounds2 should be longer then rounds1
        vm.assume(rounds1 < rounds2);

        amount1 = bound(amount1, 1, MAX_GIV_BALANCE);
        amount2 = bound(amount2, 1, MAX_GIV_BALANCE);
        vm.assume(amount1 < (MAX_GIV_BALANCE - amount2)); // Same as (amount1 + amount2) < MAX_GIV_BALANCE; to avoid overflow

        vm.startPrank(sender);

        givToken.approve(address(givPower), amount1 + amount2);
        givPower.stake(amount1 + amount2);

        uint256 untilRound1 = givPower.currentRound() + rounds1;
        uint256 untilRound2 = givPower.currentRound() + rounds2;

        vm.expectEmit(true, true, true, true);
        emit TokenLocked(sender, amount1, rounds1, untilRound1);
        givPower.lock(amount1, rounds1);

        vm.expectEmit(true, true, true, true);
        emit TokenLocked(sender, amount2, rounds2, untilRound2);
        givPower.lock(amount2, rounds2);

        skip(roundDuration * rounds1 + roundDuration);

        vm.expectEmit(true, true, true, true);
        emit TokenUnlocked(sender, amount1, untilRound1);
        givPower.unlock(accounts, untilRound1);

        vm.expectRevert(UnipoolGIVpower.CannotUnlockUntilRoundIsFinished.selector);
        givPower.unlock(accounts, untilRound2);

        skip(roundDuration * (rounds2 - rounds1));

        vm.expectEmit(true, true, true, true);
        emit TokenUnlocked(sender, amount2, untilRound2);
        givPower.unlock(accounts, untilRound2);
    }
}