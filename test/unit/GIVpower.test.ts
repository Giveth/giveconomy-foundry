import { EVMcrispr } from '@1hive/evmcrispr';
import { BigNumber, Contract } from 'ethers';
import { ethers, upgrades } from 'hardhat';
import { getImplementationAddress } from '@openzeppelin/upgrades-core';

import { impersonateAddress, increase } from '../helpers/rpc';
import { GIVpower__factory } from '../../typechain-types';
import { expect } from '../shared';
import GardenUnipoolTokenDistributorAbiOrigin from '../abi/GardenUnipoolTokenDistributor_original.json';

describe('unit/GIVpower', () => {
  let signer;
  let tokenManager;
  let evm;
  const gardenUnipoolProxyAdminAddress = '0x076C250700D210e6cf8A27D1EB1Fd754FB487986';
  const gardenUnipoolAddress = '0xD93d3bDBa18ebcB3317a57119ea44ed2Cf41C2F2';
  let gardenUnipool;
  let givPower;

  before(async () => {
    signer = (await ethers.getSigners())[0];
    gardenUnipool = new Contract(gardenUnipoolAddress, GardenUnipoolTokenDistributorAbiOrigin, signer);
  });

  it('upgrade GardenUnipoolTokenDistributor', async () => {
    const testUsers = ['0xB8306b6d3BA7BaB841C02f0F92b8880a4760199A', '0x975f6807E8406191D1C951331eEa4B26199b37ff'];

    const GardenUnipoolProxyAdmin = new Contract(
      gardenUnipoolProxyAdminAddress,
      ['function owner() public view returns (address)'],
      signer
    );

    console.log('implementation address: ', await getImplementationAddress(ethers.provider, gardenUnipoolAddress));
    const beforeContractValues = await Promise.all([
      gardenUnipool.tokenDistro(),
      gardenUnipool.duration(),
      gardenUnipool.rewardDistribution(),
      gardenUnipool.periodFinish(),
      gardenUnipool.rewardRate(),
      gardenUnipool.lastUpdateTime(),
      gardenUnipool.rewardPerTokenStored(),
      gardenUnipool.totalSupply(),
    ]);

    const beforeUsersValues = {};
    for (const testUser of testUsers) {
      beforeUsersValues[testUser] = await Promise.all([
        gardenUnipool.balanceOf(testUser),
        gardenUnipool.userRewardPerTokenPaid(testUser),
        gardenUnipool.rewards(testUser),
      ]);
    }

    signer = await impersonateAddress(await GardenUnipoolProxyAdmin.owner());

    const GIVPower = (await ethers.getContractFactory('GIVpower', signer)) as GIVpower__factory;

    await upgrades.upgradeProxy(gardenUnipoolAddress, GIVPower, {
      unsafeAllowRenames: true,
    });

    console.log('new implementation address: ', await getImplementationAddress(ethers.provider, gardenUnipoolAddress));
    givPower = GIVPower.attach(gardenUnipoolAddress);

    const afterContractValues = await Promise.all([
      givPower.tokenDistro(),
      givPower.duration(),
      givPower.rewardDistribution(),
      givPower.periodFinish(),
      givPower.rewardRate(),
      givPower.lastUpdateTime(),
      givPower.rewardPerTokenStored(),
      givPower.totalSupply(),
    ]);

    const afterUsersValues = {};
    for (const testUser of testUsers) {
      afterUsersValues[testUser] = await Promise.all([
        givPower.balanceOf(testUser),
        givPower.userRewardPerTokenPaid(testUser),
        givPower.rewards(testUser),
      ]);
    }

    expect(beforeContractValues).to.deep.eq(afterContractValues);
    expect(beforeUsersValues).to.deep.eq(afterUsersValues);
  });

  it('Wraps, locks, unlocks, and unwraps properly', async () => {
    const dao = '0xb25f0ee2d26461e2b5b3d3ddafe197a0da677b98';
    evm = await EVMcrispr.create(dao, signer);
    tokenManager = evm.app('wrappable-hooked-token-manager.open');

    const _lockAmount = ethers.utils.parseEther('100');
    const _numberOfRounds = 1;
    const _powerIncreaseAfterLock = _lockAmount
      .mul(Math.floor(Math.sqrt((1 + _numberOfRounds) * Math.pow(10, 18))))
      .div(Math.pow(10, 9))
      .sub(_lockAmount);
    const _wrapAmount = _lockAmount.mul(2);
    const signerAddress = await signer.getAddress();
    const _initialUnipoolBalance = (await givPower.balanceOf(signerAddress)) as BigNumber;

    const givToken = new Contract(
      await tokenManager.wrappableToken(),
      [
        'function approve(address spender, uint256 amount) external returns (bool)',
        'function balanceOf(address account) external view returns (uint256)',
      ],
      signer
    );
    await (await givToken.approve(tokenManager.address, _wrapAmount)).wait();
    await expect(tokenManager.wrap(_wrapAmount))
      .to.emit(givPower, 'Staked')
      .withArgs(signerAddress, _wrapAmount)
      .to.emit(givPower, 'Transfer')
      .withArgs(ethers.constants.AddressZero, signerAddress, _wrapAmount);
    expect(await givPower.balanceOf(signerAddress)).to.be.eq(_initialUnipoolBalance.add(_wrapAmount));

    // const lockTx = await (await givPower.lock(_lockAmount, _numberOfRounds)).wait();
    // const untilRound = givPower.interface.decodeEventLog('TokenLocked', lockTx.logs[1].data).untilRound;

    const currentRound: BigNumber = await givPower.currentRound();
    const untilRound = currentRound.add(_numberOfRounds);
    await expect(givPower.lock(_lockAmount, _numberOfRounds))
      .to.emit(givPower, 'Staked')
      .withArgs(signerAddress, _powerIncreaseAfterLock)
      .to.emit(givPower, 'Transfer')
      .withArgs(ethers.constants.AddressZero, signerAddress, _powerIncreaseAfterLock)
      .to.emit(givPower, 'TokenLocked')
      .withArgs(signerAddress, _lockAmount, _numberOfRounds, untilRound);
    expect(await givPower.balanceOf(signerAddress)).to.be.eq(_wrapAmount.add(_powerIncreaseAfterLock));

    await expect(tokenManager.unwrap(_wrapAmount.sub(_lockAmount)))
      .to.emit(givPower, 'Withdrawn')
      .withArgs(signerAddress, _wrapAmount.sub(_lockAmount))
      .to.emit(givPower, 'Transfer')
      .withArgs(signerAddress, ethers.constants.AddressZero, _wrapAmount.sub(_lockAmount));

    await increase(evm.resolver.resolveNumber(`${(_numberOfRounds + 1) * 14}d`));

    await expect(givPower.unlock([await signer.getAddress()], untilRound))
      .to.emit(givPower, 'Withdrawn')
      .withArgs(signerAddress, _powerIncreaseAfterLock)
      .to.emit(givPower, 'Transfer')
      .withArgs(signerAddress, ethers.constants.AddressZero, _powerIncreaseAfterLock)
      .to.emit(givPower, 'TokenUnlocked')
      .withArgs(signerAddress, _lockAmount, untilRound);

    expect(await givPower.balanceOf(signerAddress)).to.be.eq(_lockAmount);
    await (await tokenManager.unwrap(_lockAmount)).wait();
  });
});
