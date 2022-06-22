import { EVMcrispr } from '@1hive/evmcrispr';
import { BigNumber, Contract } from 'ethers';
import { ethers, deployments } from 'hardhat';

import { impersonateAddress, increase } from '../helpers/rpc';
import { GIVpower__factory } from '../../typechain-types';
import { expect } from '../shared';
import GardenUnipoolTokenDistributorAbiOrigin from '../abi/GardenUnipoolTokenDistributor_original.json';
import BigNumberJs from 'bignumber.js';

describe('unit/GIVpower', () => {
  let signer;
  let tokenManager;
  let evm;
  const gardenUnipoolAddress = '0xD93d3bDBa18ebcB3317a57119ea44ed2Cf41C2F2';
  let gardenUnipool;
  let givPower;

  before(async () => {
    signer = (await ethers.getSigners())[0];
    gardenUnipool = new Contract(gardenUnipoolAddress, GardenUnipoolTokenDistributorAbiOrigin, signer);
  });

  it('upgrade GardenUnipoolTokenDistributor', async () => {
    const testUsers = ['0xB8306b6d3BA7BaB841C02f0F92b8880a4760199A', '0x975f6807E8406191D1C951331eEa4B26199b37ff'];

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

    await deployments.fixture(['UpgradeUnipool']);

    const GIVPower = (await ethers.getContractFactory('GIVpower', signer)) as GIVpower__factory;
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
    const GivethMultisig = '0x4D9339dd97db55e3B9bCBE65dE39fF9c04d1C2cd';
    const sqrtPrecision = 1 / Math.pow(10, 9);

    const multisigSigner = await impersonateAddress(GivethMultisig);

    evm = await EVMcrispr.create(dao, multisigSigner);
    tokenManager = evm.app('wrappable-hooked-token-manager.open');

    const _lockAmount = ethers.utils.parseEther('100');
    const _numberOfRounds = 1;
    const _powerIncreaseAfterLockExpected = new BigNumberJs(_lockAmount.toString())
      .times(new BigNumberJs(1 + _numberOfRounds).sqrt())
      .minus(_lockAmount.toString());

    const _powerIncreaseAfterLock = (await givPower.calculatePower(_lockAmount, _numberOfRounds)).sub(_lockAmount);

    expect(_powerIncreaseAfterLockExpected.div(_powerIncreaseAfterLock.toString()).toNumber()).to.be.within(
      1 - sqrtPrecision,
      1 + sqrtPrecision
    );

    const _wrapAmount = _lockAmount.mul(2);
    const _initialUnipoolBalance = (await givPower.balanceOf(GivethMultisig)) as BigNumber;

    const givToken = new Contract(
      await tokenManager.wrappableToken(),
      [
        'function approve(address spender, uint256 amount) external returns (bool)',
        'function balanceOf(address account) external view returns (uint256)',
      ],
      signer
    );
    await (await givToken.connect(multisigSigner).approve(tokenManager.address, _wrapAmount)).wait();
    await expect(tokenManager.connect(multisigSigner).wrap(_wrapAmount))
      .to.emit(givPower, 'Staked')
      .withArgs(GivethMultisig, _wrapAmount)
      .to.emit(givPower, 'Transfer')
      .withArgs(ethers.constants.AddressZero, GivethMultisig, _wrapAmount);
    expect(await givPower.balanceOf(GivethMultisig)).to.be.eq(_initialUnipoolBalance.add(_wrapAmount));

    // const lockTx = await (await givPower.lock(_lockAmount, _numberOfRounds)).wait();
    // const untilRound = givPower.interface.decodeEventLog('TokenLocked', lockTx.logs[1].data).untilRound;

    const currentRound: BigNumber = await givPower.currentRound();
    const untilRound = currentRound.add(_numberOfRounds);
    await expect(givPower.connect(multisigSigner).lock(_lockAmount, _numberOfRounds))
      .to.emit(givPower, 'Staked')
      .withArgs(GivethMultisig, _powerIncreaseAfterLock)
      .to.emit(givPower, 'Transfer')
      .withArgs(ethers.constants.AddressZero, GivethMultisig, _powerIncreaseAfterLock)
      .to.emit(givPower, 'TokenLocked')
      .withArgs(GivethMultisig, _lockAmount, _numberOfRounds, untilRound);
    expect(await givPower.balanceOf(GivethMultisig)).to.be.eq(_wrapAmount.add(_powerIncreaseAfterLock));

    await expect(tokenManager.connect(multisigSigner).unwrap(_wrapAmount.sub(_lockAmount)))
      .to.emit(givPower, 'Withdrawn')
      .withArgs(GivethMultisig, _wrapAmount.sub(_lockAmount))
      .to.emit(givPower, 'Transfer')
      .withArgs(GivethMultisig, ethers.constants.AddressZero, _wrapAmount.sub(_lockAmount));

    await increase(evm.resolver.resolveNumber(`${(_numberOfRounds + 1) * 14}d`));

    await expect(givPower.unlock([GivethMultisig], untilRound))
      .to.emit(givPower, 'Withdrawn')
      .withArgs(GivethMultisig, _powerIncreaseAfterLock)
      .to.emit(givPower, 'Transfer')
      .withArgs(GivethMultisig, ethers.constants.AddressZero, _powerIncreaseAfterLock)
      .to.emit(givPower, 'TokenUnlocked')
      .withArgs(GivethMultisig, _lockAmount, untilRound);

    expect(await givPower.balanceOf(GivethMultisig)).to.be.eq(_lockAmount);
    await (await tokenManager.connect(multisigSigner).unwrap(_lockAmount)).wait();
  });
});
