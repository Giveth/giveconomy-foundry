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

    function testNormalExit(uint256 amount, uint8 rounds) public {
        uint256 maxLockRounds = givPower.MAX_LOCK_ROUNDS();

        vm.assume(amount <= 100 ether);
        vm.assume(amount > 0);
        rounds = uint8(bound(rounds, 1, maxLockRounds));

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

        vm.expectEmit(true, true, true, true, address(givPower));
        emit Withdrawn(sender, amount);

        vm.expectEmit(true, true, true, true, address(givPower));
        emit Transfer(sender, address(0), amount);

        vm.expectEmit(true, true, true, true, address(givToken));
        emit Transfer(address(givPower), sender, amount);
        givPower.exit();

        vm.stopPrank();
    }

    function testBlockExit(uint256 amount, uint8 rounds) public {
        uint256 maxLockRounds = givPower.MAX_LOCK_ROUNDS();

        vm.assume(amount <= 100 ether);
        vm.assume(amount > 0);
        rounds = uint8(bound(rounds, 1, maxLockRounds));

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

        uint256 untilRound = givPower.currentRound() + rounds;

        vm.expectEmit(true, true, true, true);
        emit TokenLocked(sender, amount, rounds, untilRound);
        givPower.lock(amount, rounds);

        vm.expectRevert(UnipoolGIVpower.TokensAreLocked.selector);
        givPower.exit();
        vm.stopPrank();
    }
}
