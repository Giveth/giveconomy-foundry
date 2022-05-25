import { evmcl, EVMcrispr } from '@1hive/evmcrispr';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import { impersonateAddress, increase } from '../helpers/rpc';

describe('unit/GIVpower', () => {
  it('deploys properly', async () => {
    expect(true).to.be.true;

    const signer = await impersonateAddress('0xc125218F4Df091eE40624784caF7F47B9738086f');
    const GIVpower = await ethers.getContractFactory("GIVpower");
    const instance = await GIVpower.deploy();

    const tx = await evmcl`
      connect 0xb3f3da0080a8811d887531ca4c0dbfe3490bd1a1 disputable-voting.open --context Bu
      exec wrappable-hooked-token-manager.open revokeHook 1
      exec wrappable-hooked-token-manager.open registerHook ${instance.address}
    `.forward(signer);
    
    const evm = await EVMcrispr.create('0xb3f3da0080a8811d887531ca4c0dbfe3490bd1a1', signer);
    const voting = evm.app('disputable-voting.open');
    const voteId = parseInt(tx[0].logs[2].topics[1], 16);
    const executionScript = voting.interface.decodeEventLog('StartVote', tx[0].logs[2].data).executionScript;
    
    await voting.vote(voteId, true);

    await increase(String(30*24*60*60));

    await (await voting.executeVote(voteId, executionScript)).wait();
  });
});