import { evmcl, EVMcrispr } from '@1hive/evmcrispr';
import { Contract } from 'ethers';
import { ethers, upgrades } from 'hardhat';
import { getImplementationAddress } from '@openzeppelin/upgrades-core';

import { impersonateAddress, increase } from '../helpers/rpc';
import {GardenUnipoolTokenDistributor__factory} from "../../typechain-types";
import {expect} from "../shared";


describe('unit/GIVpower', () => {
  let signer
  let instance
  let tokenManager
  let evm

  it('upgrade GardenUnipoolTokenDistributor', async () => {
    const gardenUnipoolProxyAdminAddress = '0x076C250700D210e6cf8A27D1EB1Fd754FB487986';
    const gardenUnipoolAddress = '0xD93d3bDBa18ebcB3317a57119ea44ed2Cf41C2F2';

    const testUsers = [
      '0xB8306b6d3BA7BaB841C02f0F92b8880a4760199A',
      '0x975f6807E8406191D1C951331eEa4B26199b37ff'
    ]

    signer = (await ethers.getSigners())[0];
    const GardenUnipoolProxyAdmin = new Contract(gardenUnipoolProxyAdminAddress, [
      'function owner() public view returns (address)',
    ], signer)
    signer = await impersonateAddress(await GardenUnipoolProxyAdmin.owner());

    const GardenUnipoolTokenDistributor =
        await ethers.getContractFactory("GardenUnipoolTokenDistributor", signer) as GardenUnipoolTokenDistributor__factory;


    const gardenUnipool = GardenUnipoolTokenDistributor.attach(gardenUnipoolAddress);

    console.log('implementation address: ', await getImplementationAddress(ethers.provider, gardenUnipoolAddress))
    const beforeContractValues = await Promise.all([
      gardenUnipool.tokenDistro(),
      gardenUnipool.duration(),
      gardenUnipool.rewardDistribution(),
      gardenUnipool.periodFinish(),
      gardenUnipool.rewardRate(),
      gardenUnipool.lastUpdateTime(),
      gardenUnipool.rewardPerTokenStored(),
      gardenUnipool.totalSupply()
    ]);

    const beforeUsersValues = {};
    for (const testUser of testUsers) {
      beforeUsersValues[testUser] = await Promise.all([
          gardenUnipool.balanceOf(testUser),
          gardenUnipool.userRewardPerTokenPaid(testUser),
          gardenUnipool.rewards(testUser),
      ])
    }

    await upgrades.upgradeProxy(gardenUnipoolAddress, GardenUnipoolTokenDistributor, {
      unsafeSkipStorageCheck: true,
    });

    console.log('new implementation address: ', await getImplementationAddress(ethers.provider, gardenUnipoolAddress))
    const afterContractValues = await Promise.all([
      gardenUnipool.tokenDistro(),
      gardenUnipool.duration(),
      gardenUnipool.rewardDistribution(),
      gardenUnipool.periodFinish(),
      gardenUnipool.rewardRate(),
      gardenUnipool.lastUpdateTime(),
      gardenUnipool.rewardPerTokenStored(),
      gardenUnipool.totalSupply()
    ]);

    const afterUsersValues = {};
    for (const testUser of testUsers) {
      afterUsersValues[testUser] = await Promise.all([
        gardenUnipool.balanceOf(testUser),
        gardenUnipool.userRewardPerTokenPaid(testUser),
        gardenUnipool.rewards(testUser),
      ])
    }

    expect(beforeContractValues).to.deep.eq(afterContractValues);
    expect(beforeUsersValues).to.deep.eq(afterUsersValues);
  })

  it('deploys properly', async () => {

    const dao = '0xb25f0ee2d26461e2b5b3d3ddafe197a0da677b98'
    // const dao = '0xb3f3da0080a8811d887531ca4c0dbfe3490bd1a1'
    const tokenDistribution= '0xc0dbDcA66a0636236fAbe1B3C16B1bD4C84bB1E1'
    // const tokenDistribution = '0x74B557bec1A496a8E9BE57e9A1530A15364C87Be';

    signer = await impersonateAddress('0xc125218F4Df091eE40624784caF7F47B9738086f');
    evm = await EVMcrispr.create(dao, signer);
    const voting = evm.app('disputable-voting.open');

    const initialDate = (await ethers.provider.getBlock('latest')).timestamp;
    const roundDuration = evm.resolver.resolveNumber('14d');
    tokenManager = evm.app('wrappable-hooked-token-manager.open');
    const duration = evm.resolver.resolveNumber('14d');

    const GIVpower = await ethers.getContractFactory("GIVpower");
    instance = await upgrades.deployProxy(GIVpower, [
      initialDate,
      roundDuration,
      tokenManager.address,
      tokenDistribution,
      duration
    ]);
    await instance.deployed();

    const tx = await evmcl`
      connect ${dao} disputable-voting.open --context Install GIVpower
      exec wrappable-hooked-token-manager.open revokeHook 2
      exec wrappable-hooked-token-manager.open registerHook ${instance.address}
    `.forward(signer);

    const voteId = parseInt(tx[0].logs[2].topics[1], 16);
    const executionScript = voting.interface.decodeEventLog('StartVote', tx[0].logs[2].data).executionScript;

    await voting.connect(await impersonateAddress('0xECb179EA5910D652eDa6988E919c7930F5Ffcf11')).vote(voteId, true);
    await voting.connect(await impersonateAddress('0x839395e20bbB182fa440d08F850E6c7A8f6F0780')).vote(voteId, true);

    await increase(evm.resolver.resolveNumber('30d'));

    await (await voting.executeVote(voteId, executionScript)).wait();
  });

  it('Wraps, locks, unlocks, and unwraps properly', async () => {
    const givToken = new Contract(await tokenManager.wrappableToken(), [
      'function approve(address spender, uint256 amount) external returns (bool)',
      'function balanceOf(address account) external view returns (uint256)',
    ], signer)
    await (await givToken.approve(tokenManager.address, 100)).wait()
    await (await tokenManager.wrap(100)).wait()
    console.log("Current round: " + String(await instance.currentRound()))
    const lockTx = await (await instance.connect(signer).lock(100, 1)).wait()
    console.log("GIVpower: " + String(await instance.balanceOf(await signer.getAddress())))
    const untilRound = instance.interface.decodeEventLog('PowerLocked', lockTx.logs[0].data).untilRound
    await (await tokenManager.unwrap(String(1e18))).wait()
    await increase(evm.resolver.resolveNumber('14d'))
    console.log("Current round: " + String(await instance.currentRound()))
    await (await instance.unlock([await signer.getAddress()], untilRound))
    console.log("GIVpower: " + String(await instance.balanceOf(await signer.getAddress())))
    await (await tokenManager.unwrap(1)).wait()
  })
});
