// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.6;

import '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';
import 'forge-std/Test.sol';
import 'forge-std/console.sol';

import 'contracts/GIVpower.sol';
import 'contracts/GardenUnipoolTokenDistributor.sol';
import './interfaces/IERC20Bridged.sol';

library Math {
    function sqrt(uint256 y) internal pure returns (uint256 z) {
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
        // else z = 0 (default value)
    }
}

contract GIVpowerTest is Test {
    ProxyAdmin gardenUnipoolProxyAdmin;
    TransparentUpgradeableProxy gardenUnipoolProxy;
    GIVpower implementation;
    GIVpower givPower;
    ITokenManager tokenManager;
    IERC20Bridged givToken;
    IERC20 ggivToken;
    address givethMultisig;

    // accounts
    address sender = address(1);
    address senderWithNoBalance = address(2);
    address omniBridge = 0xf6A78083ca3e2a662D6dd1703c939c8aCE2e268d;
    address[] testUsers = [0xB8306b6d3BA7BaB841C02f0F92b8880a4760199A, 0x975f6807E8406191D1C951331eEa4B26199b37ff];

    struct StorageData {
        address tokenManager;
        address tokenDistro;
        uint256 duration;
        address rewardDistribution;
        uint256 periodFinish;
        uint256 rewardRate;
        uint256 lastUpdateTime;
        uint256 rewardPerTokenStored;
        uint256 totalSupply;
        uint256[] usersBalances;
        uint256[] usersRewardsPerTokenPaid;
        uint256[] usersRewards;
    }

    StorageData storageDataBeforeUpgrade;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event TokenLocked(address indexed account, uint256 amount, uint256 rounds, uint256 untilRound);
    event TokenUnlocked(address indexed account, uint256 amount, uint256 round);

    function setUp() public {
        uint256 forkId = vm.createFork('https://xdai-archive.blockscout.com/', 22501098);
        vm.selectFork(forkId);

        gardenUnipoolProxyAdmin = ProxyAdmin(address(0x076C250700D210e6cf8A27D1EB1Fd754FB487986));

        gardenUnipoolProxy = TransparentUpgradeableProxy(payable(0xD93d3bDBa18ebcB3317a57119ea44ed2Cf41C2F2));

        // new implementation
        implementation = new GIVpower();

        // wrap in ABI to support easier calls
        givPower = GIVpower(address(gardenUnipoolProxy));

        tokenManager = ITokenManager(givPower.getTokenManager());

        givToken = IERC20Bridged(address(tokenManager.wrappableToken()));

        ggivToken = IERC20(address(tokenManager.token()));

        givethMultisig = gardenUnipoolProxyAdmin.owner();

        storageDataBeforeUpgrade = getImplementationStorageData(testUsers);

        // upgrade to new implementation
        vm.prank(givethMultisig);
        gardenUnipoolProxyAdmin.upgrade(gardenUnipoolProxy, address(implementation));

        // mint
        vm.prank(omniBridge);
        givToken.mint(sender, 100 ether);

        // labels
        vm.label(senderWithNoBalance, 'senderWithNoBalance');
        vm.label(givethMultisig, 'givethMultisig');
        vm.label(address(gardenUnipoolProxyAdmin), 'ProxyAdmin');
        vm.label(address(gardenUnipoolProxy), 'Proxy');
        vm.label(address(givPower), 'GIVpower');
        vm.label(address(tokenManager), 'TokenManager');
        vm.label(address(givToken), 'GivethToken');
        vm.label(address(ggivToken), 'gGivToken');
    }

    function getImplementationStorageData(address[] memory _users) public view returns (StorageData memory) {
        uint256[] memory usersBalances = new uint256[](_users.length);
        uint256[] memory usersRewardsPerTokenPaid = new uint256[](
            _users.length
        );
        uint256[] memory usersRewards = new uint256[](_users.length);

        for (uint256 i = 0; i < _users.length; i++) {
            usersBalances[i] = givPower.balanceOf(_users[i]);
            usersRewardsPerTokenPaid[i] = givPower.userRewardPerTokenPaid(_users[i]);
            usersRewards[i] = givPower.rewards(_users[i]);
        }

        return StorageData({
            tokenManager: givPower.getTokenManager(),
            tokenDistro: address(givPower.tokenDistro()),
            duration: givPower.duration(),
            rewardDistribution: givPower.rewardDistribution(),
            periodFinish: givPower.periodFinish(),
            rewardRate: givPower.rewardRate(),
            lastUpdateTime: givPower.lastUpdateTime(),
            rewardPerTokenStored: givPower.rewardPerTokenStored(),
            totalSupply: givPower.totalSupply(),
            usersBalances: usersBalances,
            usersRewardsPerTokenPaid: usersRewardsPerTokenPaid,
            usersRewards: usersRewards
        });
    }

    function roundHasStartedInSeconds() public view returns (uint256) {
        return (block.timestamp - givPower.initialDate()) % 14 days;
    }

    function testImplementationStorage() public {
        StorageData memory storageDataAfterUpgrade = getImplementationStorageData(testUsers);

        assertEq(givPower.roundDuration(), 14 days);
        assertEq(givPower.maxLockRounds(), 26);

        assertEq(storageDataBeforeUpgrade.tokenManager, storageDataAfterUpgrade.tokenManager);
        assertEq(storageDataBeforeUpgrade.tokenDistro, storageDataAfterUpgrade.tokenDistro);
        assertEq(storageDataBeforeUpgrade.duration, storageDataAfterUpgrade.duration);
        assertEq(storageDataBeforeUpgrade.rewardDistribution, storageDataAfterUpgrade.rewardDistribution);
        assertEq(storageDataBeforeUpgrade.periodFinish, storageDataAfterUpgrade.periodFinish);
        assertEq(storageDataBeforeUpgrade.rewardRate, storageDataAfterUpgrade.rewardRate);
        assertEq(storageDataBeforeUpgrade.lastUpdateTime, storageDataAfterUpgrade.lastUpdateTime);
        assertEq(storageDataBeforeUpgrade.rewardPerTokenStored, storageDataAfterUpgrade.rewardPerTokenStored);
        assertEq(storageDataBeforeUpgrade.totalSupply, storageDataAfterUpgrade.totalSupply);

        for (uint256 i = 0; i < storageDataBeforeUpgrade.usersBalances.length; i++) {
            assertEq(storageDataBeforeUpgrade.usersBalances[i], storageDataAfterUpgrade.usersBalances[i]);
            assertEq(
                storageDataBeforeUpgrade.usersRewardsPerTokenPaid[i], storageDataAfterUpgrade.usersRewardsPerTokenPaid[i]
            );
            assertEq(storageDataBeforeUpgrade.usersRewards[i], storageDataAfterUpgrade.usersRewards[i]);
        }
    }

    function testZeroLockRound() public {
        vm.expectRevert(GIVpower.ZeroLockRound.selector);
        givPower.lock(1 ether, 0);
    }

    function testLockRoundLimit() public {
        vm.expectRevert(GIVpower.LockRoundLimit.selector);
        givPower.lock(1 ether, 27);
    }

    function testNotEnoughBalanceToLock() public {
        vm.expectRevert(GIVpower.NotEnoughBalanceToLock.selector);
        vm.prank(senderWithNoBalance);
        givPower.lock(2 ether, 2);
    }

    function testNotEnoughBalanceToLockAfterLockingAll() public {
        uint256 wrapAmount = 2 ether;
        uint256 lockAmount = 2 ether;
        uint256 numberOfRounds = 2;

        vm.startPrank(sender);
        givToken.approve(address(tokenManager), wrapAmount);
        tokenManager.wrap(lockAmount);
        givPower.lock(lockAmount, numberOfRounds);

        vm.expectRevert(GIVpower.NotEnoughBalanceToLock.selector);
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
        uint256 initialgGivBalance = ggivToken.balanceOf(sender);

        // Before lock unipool balance should be same as gGiv balance
        assertEq(initialgGivBalance, initialgGivBalance);

        vm.startPrank(sender);
        givToken.approve(address(tokenManager), wrapAmount);

        /// WRAP

        vm.expectEmit(true, true, false, false);
        emit Staked(sender, wrapAmount);

        vm.expectEmit(true, true, true, false);
        emit Transfer(address(0), sender, wrapAmount);

        tokenManager.wrap(wrapAmount);

        assertEq(givPower.balanceOf(sender), initialUnipoolBalance + wrapAmount);
        assertEq(ggivToken.balanceOf(sender), initialgGivBalance + wrapAmount);
        assertEq(givPower.totalSupply(), initialTotalSupply + wrapAmount);

        /// LOCK

        vm.expectEmit(true, true, false, false);
        emit Staked(sender, powerIncreaseAfterLock);

        vm.expectEmit(true, true, true, true);
        emit TokenLocked(sender, lockAmount, numberOfRounds, untilRound);

        vm.expectEmit(true, true, true, false);
        emit Transfer(address(0), sender, powerIncreaseAfterLock);

        givPower.lock(lockAmount, numberOfRounds);

        assertEq(givPower.balanceOf(sender), wrapAmount + powerIncreaseAfterLock);
        // gGIV balance should not change after lock
        assertEq(ggivToken.balanceOf(sender), initialgGivBalance + wrapAmount);

        /// UNWRAP

        vm.expectEmit(true, true, false, false);
        emit Withdrawn(sender, wrapAmount - lockAmount);

        vm.expectEmit(true, true, true, false);
        emit TokenUnlocked(sender, lockAmount, untilRound);

        vm.expectEmit(true, true, true, false);
        emit Transfer(sender, address(0), wrapAmount - lockAmount);

        tokenManager.unwrap(wrapAmount - lockAmount);

        skip(14 days * (numberOfRounds + 1));

        /// UNLOCK

        vm.expectEmit(true, true, false, false);
        emit Withdrawn(sender, powerIncreaseAfterLock);

        vm.expectEmit(true, true, true, false);
        emit Transfer(sender, address(0), powerIncreaseAfterLock);

        givPower.unlock(accounts, currentRound + numberOfRounds);

        assertEq(givPower.balanceOf(sender), lockAmount);

        tokenManager.unwrap(lockAmount);
    }

    function testCannotUnlockUntilRoundIsFinished() public {
        address[] memory accounts = new address[](1);
        uint256 round = givPower.currentRound();

        vm.expectRevert(GIVpower.CannotUnlockUntilRoundIsFinished.selector);
        givPower.unlock(accounts, round);
    }

    function testIsNonTransferableToken() public {
        assertEq(givPower.name(), 'GIVpower');
        assertEq(givPower.symbol(), 'POW');
        assertEq(givPower.decimals(), 18);
        assertEq(givPower.balanceOf(address(0)), 0);
        assertFalse(givPower.totalSupply() == 0);

        assertEq(givPower.allowance(givethMultisig, givethMultisig), 0);

        vm.expectRevert(GIVpower.TokenNonTransferable.selector);
        givPower.approve(givethMultisig, 1);

        vm.expectRevert(GIVpower.TokenNonTransferable.selector);
        givPower.increaseAllowance(givethMultisig, 1);

        vm.expectRevert(GIVpower.TokenNonTransferable.selector);
        givPower.decreaseAllowance(givethMultisig, 1);

        vm.expectRevert(GIVpower.TokenNonTransferable.selector);
        givPower.transfer(givethMultisig, 1);

        vm.expectRevert(GIVpower.TokenNonTransferable.selector);
        givPower.transferFrom(givethMultisig, givethMultisig, 1);

        vm.expectRevert(GIVpower.TokenNonTransferable.selector);
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
        assertApproxEqAbs(givPower.calculatePower(1e10, 1), Math.sqrt(2e20), 20);

        assertApproxEqAbs(givPower.calculatePower(5e10, 1), Math.sqrt(2e20) * 5, 20);

        assertApproxEqAbs(givPower.calculatePower(1e10, 10), Math.sqrt(11e20), 20);

        assertApproxEqAbs(givPower.calculatePower(5e10, 10), Math.sqrt(11e20) * 5, 20);
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
        givToken.approve(address(tokenManager), wrapAmount);
        tokenManager.wrap(lockAmount);
        givPower.lock(lockAmount, numberOfRounds);
        vm.stopPrank();

        uint256 round = givPower.currentRound() + numberOfRounds;
        uint256 lockTimeRound = givPower.currentRound();

        skip(14 days);

        address[] memory accounts = new address[](1);
        accounts[0] = sender;

        vm.expectRevert(GIVpower.CannotUnlockUntilRoundIsFinished.selector);
        givPower.unlock(accounts, round);

        passedSeconds = roundHasStartedInSeconds();
        // Seconds has passed from round start time, for this test it should be positive
        assertFalse(passedSeconds == 0);

        // After this line, less than 2 rounds (4 weeks) are passed from lock time because passedSeconds is positive
        skip(14 days - passedSeconds);

        // Still not 2 complete rounds has passed since lock time!!
        assertEq(givPower.currentRound(), lockTimeRound + 2);

        vm.expectRevert(GIVpower.CannotUnlockUntilRoundIsFinished.selector);
        givPower.unlock(accounts, round);

        skip(14 days);

        givPower.unlock(accounts, round);
    }
}
