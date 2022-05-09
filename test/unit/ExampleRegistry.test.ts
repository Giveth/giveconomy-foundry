import { Wallet } from '@ethersproject/wallet';
import { expect } from 'chai';
import {
  ActorFixture,
  createFixtureLoader,
  exampleRegistryFixture,
  ExampleRegistryFixture,
  provider,
} from '../shared';
import { LoadFixtureFunction } from '../types';

let loadFixture: LoadFixtureFunction;

describe('unit/ExampleRegistry', () => {
  const actors = new ActorFixture(provider.getWallets(), provider);
  let context: ExampleRegistryFixture;

  before('loader', async () => {
    loadFixture = createFixtureLoader(provider.getWallets(), provider);
  });

  beforeEach('create fixture loader', async () => {
    context = await loadFixture(exampleRegistryFixture);
  });

  describe('#setMessage', () => {
    let subject: (_message: string, sender: Wallet) => Promise<any>;

    const testMessage = 'Hello world!';

    beforeEach(() => {
      subject = (_message: string, sender: Wallet) => context.exampleRegistry.connect(sender).setMessage(_message);
    });

    describe('works and', () => {
      const sender = actors.owner();

      it('emits the message changed event', async () => {
        await expect(subject(testMessage, sender))
          .to.emit(context.exampleRegistry, 'MessageChanged')
          .withArgs(testMessage, sender.address);
      });

      it('sets the message', async () => {
        await subject(testMessage, sender);
        expect(await context.exampleRegistry.message()).to.be.eq(testMessage);
      });
    });

    describe('fails when', () => {
      it('is not called by the owner', async () => {
        await expect(subject(testMessage, actors.anyone())).to.be.reverted;
      });
    });
  });
});
