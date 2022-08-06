// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.6;

import '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';
import 'forge-std/Test.sol';
import 'forge-std/console.sol';

import 'contracts/GIVpower.sol';
import 'contracts/GardenUnipoolTokenDistributor.sol';

contract GIVpowerTest is Test {
    ProxyAdmin gardenUnipoolProxyAdmin;
    TransparentUpgradeableProxy gardenUnipoolProxy;
    GIVpower implementation;
    GIVpower givPower;

    // accounts
    address sender = address(1);
    address notAuthorized = address(2);
    address givethMultisig = 0x4D9339dd97db55e3B9bCBE65dE39fF9c04d1C2cd;

    struct StorageData {
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

    function setUp() public {
        gardenUnipoolProxyAdmin = ProxyAdmin(address(0x076C250700D210e6cf8A27D1EB1Fd754FB487986));

        gardenUnipoolProxy = TransparentUpgradeableProxy(payable(0xD93d3bDBa18ebcB3317a57119ea44ed2Cf41C2F2));

        // new implementation
        implementation = new GIVpower();

        // wrap in ABI to support easier calls
        givPower = GIVpower(address(gardenUnipoolProxy));

        // labels
        vm.label(sender, 'sender');
        vm.label(notAuthorized, 'notAuthorizedAddress');
    }

    function upgradeGardenUnipool() public {
        vm.prank(gardenUnipoolProxyAdmin.owner());
        gardenUnipoolProxyAdmin.upgrade(gardenUnipoolProxy, address(implementation));
    }

    function roundHasStartedInSeconds() public returns (uint256) {
        return (block.timestamp - givPower.initialDate()) % 14 days;
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

    function testImplementationStorage() public {
        address[] memory testUsers = new address[](2);
        testUsers[0] = 0xB8306b6d3BA7BaB841C02f0F92b8880a4760199A;
        testUsers[1] = 0x975f6807E8406191D1C951331eEa4B26199b37ff;

        StorageData memory storageDataBefore = getImplementationStorageData(testUsers);

        upgradeGardenUnipool();

        StorageData memory storageDataAfter = getImplementationStorageData(testUsers);

        assertEq(givPower.roundDuration(), 14 days);
        assertEq(givPower.maxLockRounds(), 26);

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
        upgradeGardenUnipool();

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
        upgradeGardenUnipool();

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
}
