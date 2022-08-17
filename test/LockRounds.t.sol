// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.6;

import './GIVpowerTest.sol';

contract LockRounds is GIVpowerTest {
    function setUp() public override {
        super.setUp();
        vm.startPrank(omniBridge);
        givToken.mint(sender, MAX_GIV_BALANCE - givToken.balanceOf(sender));
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

        vm.expectRevert(GIVpower.CannotUnlockUntilRoundIsFinished.selector);
        givPower.unlock(accounts, round);

        // One second before round ends (at the edge of next round)
        skip(roundDuration - 1);

        assertEq(round, givPower.currentRound());

        vm.expectRevert(GIVpower.CannotUnlockUntilRoundIsFinished.selector);
        givPower.unlock(accounts, round);

        // Move one second forward (beginning of the next round)
        skip(1);

        assertEq(round + 1, givPower.currentRound());
        givPower.unlock(accounts, round);
    }

    function testUnlockAdvanced(uint256 amount, uint8 rounds) public {
        uint256 maxLockRounds = givPower.MAX_LOCK_ROUNDS();
        uint256 roundDuration = givPower.ROUND_DURATION();

        vm.assume(rounds > 0);
        vm.assume(rounds <= maxLockRounds);
        vm.assume(amount > 0);
        vm.assume(amount < MAX_GIV_BALANCE);

        uint256 lockRewards = givPower.calculatePower(amount, rounds) - amount;
        vm.assume(lockRewards > 0);

        vm.startPrank(sender);

        givToken.approve(address(tokenManager), amount);
        tokenManager.wrap(amount);
        givPower.lock(amount, rounds);

        uint256 untilRound = givPower.currentRound() + rounds;
        uint256 passedSeconds = this.roundHasStartedInSeconds();

        assertGt(
            roundDuration, passedSeconds, 'Seconds passed from the start of round should be less than the round duration'
        );

        address[] memory accounts = new address[](1);
        accounts[0] = sender;

        vm.expectRevert(GIVpower.CannotUnlockUntilRoundIsFinished.selector);
        givPower.unlock(accounts, untilRound);

        vm.expectRevert(GIVpower.TokensAreLocked.selector);
        gGivToken.transfer(senderWithNoBalance, amount);

        vm.expectRevert(GIVpower.TokensAreLocked.selector);
        tokenManager.unwrap(amount);

        skip(rounds * roundDuration);

        vm.expectRevert(GIVpower.CannotUnlockUntilRoundIsFinished.selector);
        givPower.unlock(accounts, untilRound);

        vm.expectRevert(GIVpower.TokensAreLocked.selector);
        gGivToken.transfer(senderWithNoBalance, amount);

        vm.expectRevert(GIVpower.TokensAreLocked.selector);
        tokenManager.unwrap(amount);

        skip(roundDuration - passedSeconds);

        vm.expectEmit(true, true, true, true);
        emit Withdrawn(sender, lockRewards);

        vm.expectEmit(true, true, true, true);
        emit TokenUnlocked(sender, amount, untilRound);

        vm.expectEmit(true, true, true, true, address(givPower));
        emit Transfer(sender, address(0), lockRewards);
        givPower.unlock(accounts, untilRound);
    }
}
