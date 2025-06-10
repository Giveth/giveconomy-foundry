// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.10;

import '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';
import 'forge-std/console.sol';
import '../interfaces/IERC20Bridged.sol';
import './UnipoolGIVpowerTest.sol';

contract GeneralTest is UnipoolGIVpowerTest {
    StorageData storageDataBeforeUpgrade;

    function setUp() public override {
        super.setUp();
    }

    function testZeroLockRound() public {
        vm.expectRevert(UnipoolGIVpower.ZeroLockRound.selector);
        givPower.lock(1 ether, 0);
    }

    function testLockRoundLimit() public {
        vm.expectRevert(UnipoolGIVpower.LockRoundLimit.selector);
        givPower.lock(1 ether, 27);
    }

    function testNotEnoughBalanceToLock() public {
        vm.expectRevert(UnipoolGIVpower.NotEnoughBalanceToLock.selector);
        vm.prank(senderWithNoBalance);
        givPower.lock(2 ether, 2);
    }

    function testNotEnoughBalanceToLockAfterLockingAll() public {
        uint256 wrapAmount = 2 ether;
        uint256 lockAmount = 2 ether;
        uint256 numberOfRounds = 2;

        vm.startPrank(sender);
        givToken.approve(address(givPower), wrapAmount);
        givPower.stake(lockAmount);
        givPower.lock(lockAmount, numberOfRounds);

        vm.expectRevert(UnipoolGIVpower.NotEnoughBalanceToLock.selector);
        givPower.lock(1 ether, numberOfRounds);
        vm.stopPrank();
    }

    function testWrapLockUnwrapUnlockProperly() public {
        uint256 stakeAmount = 20 ether;
        uint256 lockAmount = 10 ether;
        uint256 numberOfRounds = 1;
        address[] memory accounts = new address[](1);
        accounts[0] = sender;

        uint256 currentRound = givPower.currentRound();
        uint256 untilRound = currentRound + numberOfRounds;
        uint256 powerIncreaseAfterLock = givPower.calculatePower(lockAmount, numberOfRounds) - lockAmount;

        uint256 initialTotalSupply = givPower.totalSupply();
        uint256 initialUnipoolBalance = givPower.balanceOf(sender);

        vm.startPrank(sender);
        givToken.approve(address(givPower), stakeAmount);

        vm.expectEmit(true, true, true, true);
        emit Staked(sender, stakeAmount);

        vm.expectEmit(true, true, true, true, address(givPower));
        emit Transfer(address(0), sender, stakeAmount);

        vm.expectEmit(true, true, true, true, address(givPower));
        emit DepositTokenDeposited(sender, stakeAmount);

        givPower.stake(stakeAmount);

        assertEq(givPower.balanceOf(sender), initialUnipoolBalance + stakeAmount);
        assertEq(givPower.totalSupply(), initialTotalSupply + stakeAmount);

        /// LOCK

        vm.expectEmit(true, true, true, true);
        emit Staked(sender, powerIncreaseAfterLock);

        vm.expectEmit(true, true, true, true, address(givPower));
        emit Transfer(address(0), sender, powerIncreaseAfterLock);

        vm.expectEmit(true, true, true, true);
        emit TokenLocked(sender, lockAmount, numberOfRounds, untilRound);

        givPower.lock(lockAmount, numberOfRounds);

        assertEq(givPower.balanceOf(sender), stakeAmount + powerIncreaseAfterLock);

        /// UNWRAP

        vm.expectEmit(true, true, true, true);
        emit Withdrawn(sender, stakeAmount - lockAmount);

        vm.expectEmit(true, true, true, true, address(givPower));
        emit Transfer(sender, address(0), stakeAmount - lockAmount);

        vm.expectEmit(true, true, true, true, address(givToken));
        emit Transfer(address(givPower), sender, stakeAmount - lockAmount);

        vm.expectEmit(true, true, true, true, address(givPower));
        emit DepositTokenWithdrawn(sender, stakeAmount - lockAmount);

        givPower.withdraw(stakeAmount - lockAmount);

        skip(14 days * (numberOfRounds + 1));

        /// UNLOCK

        vm.expectEmit(true, true, true, true);
        emit Withdrawn(sender, powerIncreaseAfterLock);

        vm.expectEmit(true, true, true, true, address(givPower));
        emit Transfer(sender, address(0), powerIncreaseAfterLock);

        vm.expectEmit(true, true, true, true);
        emit TokenUnlocked(sender, lockAmount, untilRound);

        givPower.unlock(accounts, untilRound);

        assertEq(givPower.balanceOf(sender), lockAmount);

        givPower.withdraw(lockAmount);
    }

    function testCannotUnlockUntilRoundIsFinished() public {
        address[] memory accounts = new address[](1);
        uint256 round = givPower.currentRound();

        vm.expectRevert(UnipoolGIVpower.CannotUnlockUntilRoundIsFinished.selector);
        givPower.unlock(accounts, round);
    }

    function testIsNonTransferableToken() public {
        assertEq(givPower.name(), 'GIVpower');
        assertEq(givPower.symbol(), 'POW');
        assertEq(givPower.decimals(), 18);
        assertEq(givPower.balanceOf(address(0)), 0);

        assertEq(givPower.allowance(givethMultisig, givethMultisig), 0);

        vm.expectRevert(UnipoolGIVpower.TokenNonTransferable.selector);
        givPower.approve(givethMultisig, 1);

        vm.expectRevert(UnipoolGIVpower.TokenNonTransferable.selector);
        givPower.increaseAllowance(givethMultisig, 1);

        vm.expectRevert(UnipoolGIVpower.TokenNonTransferable.selector);
        givPower.decreaseAllowance(givethMultisig, 1);

        vm.expectRevert(UnipoolGIVpower.TokenNonTransferable.selector);
        givPower.transfer(givethMultisig, 1);

        vm.expectRevert(UnipoolGIVpower.TokenNonTransferable.selector);
        givPower.transferFrom(givethMultisig, givethMultisig, 1);

        vm.expectRevert(UnipoolGIVpower.TokenNonTransferable.selector);
        givPower.transfer(givethMultisig, 1);
    }

    function testTrackCurrentRound() public {
        uint256 currentRound = givPower.currentRound();

        skip(14 days);
        assertEq(givPower.currentRound(), currentRound + 1);

        skip(14 days);
        assertEq(givPower.currentRound(), currentRound + 2);

        skip(14 days - (roundHasStartedInSeconds() + 1));
        assertEq(givPower.currentRound(), currentRound + 2);

        skip(1);
        assertEq(givPower.currentRound(), currentRound + 3);
    }

    function testCalculatePower() public {
        assertApproxEqRel(givPower.calculatePower(1e10, 1), FixedPointMathLib.sqrt(2e20), 0.000000001e18);

        assertApproxEqRel(givPower.calculatePower(5e10, 1), FixedPointMathLib.sqrt(2e20) * 5, 0.000000001e18);

        assertApproxEqRel(givPower.calculatePower(1e10, 10), FixedPointMathLib.sqrt(11e20), 0.000000001e18);

        assertApproxEqRel(givPower.calculatePower(5e10, 10), FixedPointMathLib.sqrt(11e20) * 5, 0.000000001e18);
    }

    function testForbidUnwrapTokensWhileLock() public {
        uint256 wrapAmount = 3 ether;
        uint256 lockAmount = 1 ether;
        uint256 numberOfRounds = 2;

        uint256 passedSeconds = roundHasStartedInSeconds();

        // Be at least one second after round start time
        if (passedSeconds == 0) {
            skip(1);
        }

        vm.startPrank(sender);
        givToken.approve(address(givPower), wrapAmount);
        givPower.stake(lockAmount);
        givPower.lock(lockAmount, numberOfRounds);
        vm.stopPrank();

        uint256 round = givPower.currentRound() + numberOfRounds;
        uint256 lockTimeRound = givPower.currentRound();

        skip(14 days);

        address[] memory accounts = new address[](1);
        accounts[0] = sender;

        vm.expectRevert(UnipoolGIVpower.CannotUnlockUntilRoundIsFinished.selector);
        givPower.unlock(accounts, round);

        passedSeconds = roundHasStartedInSeconds();
        // Seconds has passed from round start time, for this test it should be positive
        assertFalse(passedSeconds == 0);

        // After this line, less than 2 rounds (4 weeks) are passed from lock time because passedSeconds is positive
        skip(14 days - passedSeconds);

        // Still not 2 complete rounds has passed since lock time!!
        assertEq(givPower.currentRound(), lockTimeRound + 2);

        vm.expectRevert(UnipoolGIVpower.CannotUnlockUntilRoundIsFinished.selector);
        givPower.unlock(accounts, round);

        skip(14 days);

        givPower.unlock(accounts, round);
    }
}
