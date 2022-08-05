// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.6;

import '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';
import 'forge-std/Test.sol';

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

    function setUp() public {
        if (block.chainid == 100) {
            gardenUnipoolProxyAdmin = ProxyAdmin(address(0x076C250700D210e6cf8A27D1EB1Fd754FB487986));

            gardenUnipoolProxy = TransparentUpgradeableProxy(payable(0xD93d3bDBa18ebcB3317a57119ea44ed2Cf41C2F2));
        }

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

    function getImplementationStorageData(address[] _users)
        public
        returns (address, uint256, address, uint256, uint256, uint256, uint256, uint256)
    {
        uint256[] usersBalances;
        uint256[] usersRewardsPerTokenPaid;
        uint256[] usersRewards;

        for (uint256 i = 0; i < _users.length; i++) {
            userBalances.push(givPower.balanceOf(_users[i]));
            usersRewardsPerTokenPaid.push(givPower.userRewardPerTokenPaid(_users[i]));
            usersRewards.push(givPower.rewards(_users[i]));
        }

        return (
            givPower.tokenDistro(),
            givPower.duration(),
            givPower.rewardDistribution(),
            givPower.periodFinish(),
            givPower.rewardRate(),
            givPower.lastUpdateTime(),
            givPower.rewardPerTokenStored(),
            givPower.totalSupply(),
            usersBalances,
            usersRewardsPerTokenPaid,
            usersRewards
        );
    }

    function testImplementationStorage() public {
        assertEq(givPower.roundDuration(), 14 days);
        assertEq(givPower.maxLockRounds(), 26);

        address[2] testUsers = [0xB8306b6d3BA7BaB841C02f0F92b8880a4760199A, 0x975f6807E8406191D1C951331eEa4B26199b37ff];

        (
            tokenDistro,
            duration,
            rewardDistribution,
            periodFinish,
            rewardRate,
            lastUpdateTime,
            rewardPerTokenStored,
            totalSupply,
            usersBalances,
            usersRewardsPerTokenPaid,
            usersRewards
        ) = getImplementationStorageData(testUsers);

        upgradeGardenUnipool();

        (
            tokenDistro,
            duration,
            rewardDistribution,
            periodFinish,
            rewardRate,
            lastUpdateTime,
            rewardPerTokenStored,
            totalSupply,
            usersBalances,
            usersRewardsPerTokenPaid,
            usersRewards
        ) = getImplementationStorageData(testUsers);

        assertEq();
        assertEq();
        assertEq();
        assertEq();
        assertEq();
        assertEq();
        assertEq();
        assertEq();
        assertEq();
        assertEq();
        assertEq();

        for (uint256 i = 0; i < _users.length; i++) {
            userBalances.push(givPower.balanceOf(_users[i]));
            usersRewardsPerTokenPaid.push(givPower.userRewardPerTokenPaid(_users[i]));
            usersRewards.push(givPower.rewards(_users[i]));
        }
    }
}
//     it("is a non-transferable ERC20 token", async () => {
//     expect(await givPower.name()).to.be.eq("GIVpower");
//     expect(await givPower.symbol()).to.be.eq("POW");
//     expect(await givPower.decimals()).to.be.eq(18);
//     expect(await givPower.balanceOf(constants.AddressZero)).to.be.eq(0);
//     expect(await givPower.totalSupply()).to.be.above(0);
//     expect(givPower.approve(GivethMultisig, 1)).to.be.revertedWith(
//       "TokenNonTransferable"
//     );
//     expect(givPower.increaseAllowance(GivethMultisig, 1)).to.be.revertedWith(
//       "TokenNonTransferable"
//     );
//     expect(givPower.decreaseAllowance(GivethMultisig, 1)).to.be.revertedWith(
//       "TokenNonTransferable"
//     );
//     expect(givPower.transfer(GivethMultisig, 1)).to.be.revertedWith(
//       "TokenNonTransferable"
//     );
//     expect(await givPower.allowance(GivethMultisig, GivethMultisig)).to.be.eq(
//       0
//     );
//     expect(
//       givPower.transferFrom(GivethMultisig, GivethMultisig, 1)
//     ).to.be.revertedWith("TokenNonTransferable");
//   });
