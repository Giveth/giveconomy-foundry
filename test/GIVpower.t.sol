// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.6;

import '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';
import 'forge-std/Test.sol';
import 'forge-std/console.sol';

import 'contracts/GIVpower.sol';
import 'contracts/GardenUnipoolTokenDistributor.sol';
import './interfaces/IERC20Bridged.sol';

contract GIVpowerTest is Test {
    ProxyAdmin gardenUnipoolProxyAdmin;
    TransparentUpgradeableProxy gardenUnipoolProxy;
    GIVpower implementation;
    GIVpower givPower;
    ITokenManager tokenManager;
    IERC20Bridged givToken;
    address givethMultisig;

    // accounts
    address sender = address(1);
    address notAuthorized = address(2);
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

    StorageData storageDataBefore;

    function setUp() public {
        gardenUnipoolProxyAdmin = ProxyAdmin(address(0x076C250700D210e6cf8A27D1EB1Fd754FB487986));

        gardenUnipoolProxy = TransparentUpgradeableProxy(payable(0xD93d3bDBa18ebcB3317a57119ea44ed2Cf41C2F2));

        // new implementation
        implementation = new GIVpower();

        // wrap in ABI to support easier calls
        givPower = GIVpower(address(gardenUnipoolProxy));

        tokenManager = ITokenManager(givPower.getTokenManager());

        givToken = IERC20Bridged(address(tokenManager.wrappableToken()));

        givethMultisig = gardenUnipoolProxyAdmin.owner();

        storageDataBefore = getImplementationStorageData(testUsers);

        // upgrade to new implementation
        vm.prank(givethMultisig);
        gardenUnipoolProxyAdmin.upgrade(gardenUnipoolProxy, address(implementation));

        // mint
        vm.prank(omniBridge);
        givToken.mint(sender, 10 ether);

        // labels
        vm.label(notAuthorized, 'notAuthorizedAddress');
        vm.label(givethMultisig, 'givethMultisig');
        vm.label(address(gardenUnipoolProxyAdmin), 'ProxyAdmin');
        vm.label(address(gardenUnipoolProxy), 'Proxy');
        vm.label(address(givPower), 'GIVpower');
        vm.label(address(tokenManager), 'TokenManager');
        vm.label(address(givToken), 'GivethToken');
    }

    function getImplementationStorageData(address[] memory _users) public returns (StorageData memory) {
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

    function roundHasStartedInSeconds() public returns (uint256) {
        return (block.timestamp - givPower.initialDate()) % 14 days;
    }

    function testImplementationStorage() public {
        StorageData memory storageDataAfter = getImplementationStorageData(testUsers);

        assertEq(givPower.roundDuration(), 14 days);
        assertEq(givPower.maxLockRounds(), 26);

        assertEq(storageDataBefore.tokenManager, storageDataAfter.tokenManager);
        assertEq(storageDataBefore.tokenDistro, storageDataAfter.tokenDistro);
        assertEq(storageDataBefore.duration, storageDataAfter.duration);
        assertEq(storageDataBefore.rewardDistribution, storageDataAfter.rewardDistribution);
        assertEq(storageDataBefore.periodFinish, storageDataAfter.periodFinish);
        assertEq(storageDataBefore.rewardRate, storageDataAfter.rewardRate);
        assertEq(storageDataBefore.lastUpdateTime, storageDataAfter.lastUpdateTime);
        assertEq(storageDataBefore.rewardPerTokenStored, storageDataAfter.rewardPerTokenStored);
        assertEq(storageDataBefore.totalSupply, storageDataAfter.totalSupply);

        for (uint256 i = 0; i < storageDataBefore.usersBalances.length; i++) {
            assertEq(storageDataBefore.usersBalances[i], storageDataAfter.usersBalances[i]);
            assertEq(storageDataBefore.usersRewardsPerTokenPaid[i], storageDataAfter.usersRewardsPerTokenPaid[i]);
            assertEq(storageDataBefore.usersRewards[i], storageDataAfter.usersRewards[i]);
        }
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
        // TBD
        // we can use assertApproxEqAbs or assertApproxEqRel
    }

    function testForbidUnwrapTokensWhileLock() public {
        uint256 wrapAmount = 3 ether;
        uint256 lockAmount = 1 ether;
        uint256 numberOfRounds = 2;

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

        uint256 passedSeconds = roundHasStartedInSeconds();
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
