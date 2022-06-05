import { evmcl, EVMcrispr } from '@1hive/evmcrispr';
import { Contract } from 'ethers';
// import { expect } from 'chai';
import { ethers, upgrades } from 'hardhat';

import { impersonateAddress, increase } from '../helpers/rpc';


describe('unit/GIVpower', () => {
  let signer
  let instance
  let tokenManager
  let evm

  it('deploys properly', async () => {

    const dao = '0xb25f0ee2d26461e2b5b3d3ddafe197a0da677b98'
    // const dao = '0xb3f3da0080a8811d887531ca4c0dbfe3490bd1a1'
    const tokenDistribution= '0xc0dbDcA66a0636236fAbe1B3C16B1bD4C84bB1E1'
    // const tokenDistribution = '0x74B557bec1A496a8E9BE57e9A1530A15364C87Be';

    signer = await impersonateAddress('0xc125218F4Df091eE40624784caF7F47B9738086f');
    evm = await EVMcrispr.create(dao, signer);
    const voting = evm.app('disputable-voting.open');

    const initialDate = Math.floor(new Date().getTime() / 1000);
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
      exec wrappable-hooked-token-manager.open revokeHook 1
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