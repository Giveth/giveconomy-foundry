// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.10;

import './UnipoolGIVpowerTest.sol';

contract TransferTest is UnipoolGIVpowerTest {
    function setUp() public override {
        super.setUp();

        vm.startPrank(optimismL2Bridge);
        bridgedGivToken.mint(sender, MAX_GIV_BALANCE - givToken.balanceOf(sender));
        vm.stopPrank();
    }

    function testDirectTransfer(uint256 amount) public {
        vm.assume(amount <= 100 ether);
        vm.assume(amount > 0);

        vm.expectEmit(true, true, true, true, address(givToken));
        emit Approval(sender, address(givPower), amount);

        vm.startPrank(sender);
        givToken.approve(address(givPower), amount);

        vm.expectEmit(true, true, true, true, address(givPower));
        emit Staked(sender, amount);

        vm.expectEmit(true, true, true, true, address(givPower));
        emit Transfer(address(0), sender, amount);

        vm.expectEmit(true, true, true, true, address(givToken));
        emit Transfer(sender, address(givPower), amount);

        vm.expectEmit(true, true, true, true, address(givToken));
        emit Approval(sender, address(givPower), 0);

        givPower.stake(amount);

        vm.expectRevert(UnipoolGIVpower.TokenNonTransferable.selector);
        givPower.transfer(senderWithNoBalance, amount);

        // vm.expectEmit(true, true, true, true, address(givPower));
        // emit Withdrawn(sender, amount);

        // vm.expectEmit(true, true, true, true, address(givPower));
        // emit Staked(senderWithNoBalance, amount);

        // vm.expectEmit(true, true, true, true, address(givPower));
        // emit Transfer(sender, senderWithNoBalance, amount);

        // vm.expectEmit(true, true, true, true, address(gGivToken));
        // emit Transfer(sender, senderWithNoBalance, amount);

        // gGivToken.transfer(senderWithNoBalance, amount);
        vm.stopPrank();
    }

    function testWithLockUnlock(uint256 amount, uint8 rounds) public {
        uint256 maxLockRounds = givPower.MAX_LOCK_ROUNDS();

        vm.assume(amount < MAX_GIV_BALANCE);
        vm.assume(amount > 0);
        vm.assume(rounds <= maxLockRounds);
        vm.assume(rounds > 0);

        vm.startPrank(sender);
        givToken.approve(address(givPower), amount);
        givPower.stake(amount);

        vm.expectRevert(UnipoolGIVpower.TokenNonTransferable.selector);
        givPower.transfer(senderWithNoBalance, amount);

        uint256 lockReward = givPower.calculatePower(amount, rounds) - amount;

        if (lockReward > 0) {
            vm.expectEmit(true, true, true, true, address(givPower));
            emit Staked(sender, lockReward);

            vm.expectEmit(true, true, true, true, address(givPower));
            emit Transfer(address(0), sender, lockReward);
        }

        uint256 unlockRound = givPower.currentRound() + rounds;
        givPower.lock(amount, rounds);

        vm.expectRevert(UnipoolGIVpower.TokenNonTransferable.selector);
        givPower.transfer(senderWithNoBalance, amount);

        vm.expectRevert(UnipoolGIVpower.TokenNonTransferable.selector);
        givPower.transfer(senderWithNoBalance, amount + lockReward);

        // vm.expectRevert(UnipoolGIVpower.TokensAreLocked.selector);
        // gGivToken.transfer(senderWithNoBalance, amount);

        skip(givPower.ROUND_DURATION() * (rounds + 1));

        if (lockReward > 0) {
            vm.expectEmit(true, true, true, true, address(givPower));
            emit Withdrawn(sender, lockReward);
            vm.expectEmit(true, true, true, true, address(givPower));
            emit Transfer(sender, address(0), lockReward);
        }

        address[] memory unlockAccounts = new address[](1);
        unlockAccounts[0] = sender;
        givPower.unlock(unlockAccounts, unlockRound);

        ///////////// Lock half the amount, the rest must be transferable
        uint256 lockAmount = amount / 2;

        vm.assume(lockAmount > 0);

        lockReward = givPower.calculatePower(lockAmount, rounds) - lockAmount;

        unlockRound = givPower.currentRound() + rounds;
        givPower.lock(lockAmount, rounds);

        // vm.expectRevert(UnipoolGIVpower.TokensAreLocked.selector);
        // gGivToken.transfer(senderWithNoBalance, amount - lockAmount + 1);

        // These seem repetitive
        // vm.expectEmit(true, true, true, true, address(givPower));
        // emit Withdrawn(sender, amount - lockAmount);

        // vm.expectEmit(true, true, true, true, address(givPower));
        // emit Staked(senderWithNoBalance, amount - lockAmount);

        // vm.expectEmit(true, true, true, true, address(givPower));
        // emit Transfer(sender, senderWithNoBalance, amount - lockAmount);

        // vm.expectEmit(true, true, true, true, address(gGivToken));
        // emit Transfer(sender, senderWithNoBalance, amount - lockAmount);

        // gGivToken.transfer(senderWithNoBalance, amount - lockAmount);

        skip(givPower.ROUND_DURATION() * (rounds + 1));

        vm.expectEmit(true, true, true, true, address(givPower));
        emit TokenUnlocked(sender, lockAmount, unlockRound);

        givPower.unlock(unlockAccounts, unlockRound);
        // gGivToken.transfer(senderWithNoBalance, lockAmount);
    }
}
