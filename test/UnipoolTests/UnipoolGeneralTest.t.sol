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
        // broken here - need to sort out testUsers on network or omit
        // storageDataBeforeUpgrade = getImplementationStorageData(testUsers);
        super.setUp();
    }

    // function testImplementationStorage() public {
    //     StorageData memory storageDataAfterUpgrade = getImplementationStorageData(testUsers);

    //     assertEq(givPower.ROUND_DURATION(), 14 days);
    //     assertEq(givPower.MAX_LOCK_ROUNDS(), 26);

    //     // assertEq(storageDataBeforeUpgrade.tokenManager, storageDataAfterUpgrade.tokenManager);
    //     assertEq(storageDataBeforeUpgrade.tokenDistro, storageDataAfterUpgrade.tokenDistro);
    //     assertEq(storageDataBeforeUpgrade.duration, storageDataAfterUpgrade.duration);
    //     assertEq(storageDataBeforeUpgrade.rewardDistribution, storageDataAfterUpgrade.rewardDistribution);
    //     assertEq(storageDataBeforeUpgrade.periodFinish, storageDataAfterUpgrade.periodFinish);
    //     assertEq(storageDataBeforeUpgrade.rewardRate, storageDataAfterUpgrade.rewardRate);
    //     assertEq(storageDataBeforeUpgrade.lastUpdateTime, storageDataAfterUpgrade.lastUpdateTime);
    //     assertEq(storageDataBeforeUpgrade.rewardPerTokenStored, storageDataAfterUpgrade.rewardPerTokenStored);
    //     assertEq(storageDataBeforeUpgrade.totalSupply, storageDataAfterUpgrade.totalSupply);

    //     for (uint256 i = 0; i < storageDataBeforeUpgrade.usersBalances.length; i++) {
    //         assertEq(storageDataBeforeUpgrade.usersBalances[i], storageDataAfterUpgrade.usersBalances[i]);
    //         assertEq(
    //             storageDataBeforeUpgrade.usersRewardsPerTokenPaid[i],
    //             storageDataAfterUpgrade.usersRewardsPerTokenPaid[i]
    //         );
    //         assertEq(storageDataBeforeUpgrade.usersRewards[i], storageDataAfterUpgrade.usersRewards[i]);
    //     }
    // }

    function testZeroLockRound() public {
        vm.expectRevert(UnipoolGIVpower.ZeroLockRound.selector);
        givPower.lock(1 ether, 0);
    }

    function testLockRoundLimit() public {
        vm.expectRevert(UnipoolGIVpower.LockRoundLimit.selector);
        givPower.lock(1 ether, 27);
    }

    function testNotEnoughBalanceToLock() public {
        console.log('balance of sender with no balance', givPower.balanceOf(senderWithNoBalance));
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
        uint256 wrapAmount = 20 ether;
        uint256 lockAmount = 10 ether;
        uint256 numberOfRounds = 1;
        address[] memory accounts = new address[](1);
        accounts[0] = sender;

        uint256 currentRound = givPower.currentRound();
        uint256 untilRound = currentRound + numberOfRounds;
        uint256 powerIncreaseAfterLock = givPower.calculatePower(lockAmount, numberOfRounds) - lockAmount;

        uint256 initialTotalSupply = givPower.totalSupply();
        uint256 initialUnipoolBalance = givPower.balanceOf(sender);
        // uint256 initialgGivBalance = gGivToken.balanceOf(sender);

        // Before lock unipool balance should be same as gGiv balance
        // assertEq(initialgGivBalance, initialgGivBalance);

        vm.startPrank(sender);
        givToken.approve(address(givPower), wrapAmount);

        /// WRAP

        vm.expectEmit(true, true, true, true);
        emit Staked(sender, wrapAmount);

        vm.expectEmit(true, true, true, true, address(givPower));
        emit Transfer(address(0), sender, wrapAmount);

        // vm.expectEmit(true, true, true, true, address(gGivToken));
        // emit Transfer(address(0), sender, wrapAmount);

        givPower.stake(wrapAmount);

        assertEq(givPower.balanceOf(sender), initialUnipoolBalance + wrapAmount);
        // assertEq(gGivToken.balanceOf(sender), initialgGivBalance + wrapAmount);
        assertEq(givPower.totalSupply(), initialTotalSupply + wrapAmount);

        /// LOCK

        vm.expectEmit(true, true, true, true);
        emit Staked(sender, powerIncreaseAfterLock);

        vm.expectEmit(true, true, true, true, address(givPower));
        emit Transfer(address(0), sender, powerIncreaseAfterLock);

        vm.expectEmit(true, true, true, true);
        emit TokenLocked(sender, lockAmount, numberOfRounds, untilRound);

        givPower.lock(lockAmount, numberOfRounds);

        assertEq(givPower.balanceOf(sender), wrapAmount + powerIncreaseAfterLock);
        // gGIV balance should not change after lock
        // assertEq(gGivToken.balanceOf(sender), initialgGivBalance + wrapAmount);

        /// UNWRAP

        vm.expectEmit(true, true, true, true);
        emit Withdrawn(sender, wrapAmount - lockAmount);

        vm.expectEmit(true, true, true, true, address(givPower));
        emit Transfer(sender, address(0), wrapAmount - lockAmount);

        // vm.expectEmit(true, true, true, true, address(gGivToken));
        // emit Transfer(sender, address(0), wrapAmount - lockAmount);

        givPower.withdraw(wrapAmount - lockAmount);

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
        // assertFalse(givPower.totalSupply() == 0);

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
