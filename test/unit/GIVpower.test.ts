import { evmcl, EVMcrispr } from '@1hive/evmcrispr';
// import { expect } from 'chai';
import { ethers, upgrades } from 'hardhat';

import { impersonateAddress, increase } from '../helpers/rpc';


describe('unit/GIVpower', () => {
  it('deploys properly', async () => {

    const signer = await impersonateAddress('0xc125218F4Df091eE40624784caF7F47B9738086f');
    const evm = await EVMcrispr.create('0xb3f3da0080a8811d887531ca4c0dbfe3490bd1a1', signer);
    const voting = evm.app('disputable-voting.open');

    const initialDate = Math.floor(new Date().getTime() / 1000);
    const roundDuration = evm.resolver.resolveNumber('14d');
    const tokenManager = evm.app('wrappable-hooked-token-manager.open').address;
    const tokenDistribution = '0x74B557bec1A496a8E9BE57e9A1530A15364C87Be';
    const duration = evm.resolver.resolveNumber('30d');

    const GIVpower = await ethers.getContractFactory("GIVpower");
    const instance = await upgrades.deployProxy(GIVpower, [
      initialDate,
      roundDuration,
      tokenManager,
      tokenDistribution,
      duration
    ]);
    await instance.deployed();

    const tx = await evmcl`
      connect 0xb3f3da0080a8811d887531ca4c0dbfe3490bd1a1 disputable-voting.open --context Install GIVpower
      exec wrappable-hooked-token-manager.open revokeHook 1
      exec wrappable-hooked-token-manager.open registerHook ${instance.address}
    `.forward(signer);
  
    const voteId = parseInt(tx[0].logs[2].topics[1], 16);
    const executionScript = voting.interface.decodeEventLog('StartVote', tx[0].logs[2].data).executionScript;
    
    await voting.vote(voteId, true);

    await increase(String(30*24*60*60));

    await (await voting.executeVote(voteId, executionScript)).wait();
  });
});