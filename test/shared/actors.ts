import { MockProvider } from 'ethereum-waffle';
import { Wallet } from 'ethers';

// User indexes:
export const WALLET_USER_INDEXES = {
  OWNER: 0,
  OTHER: 1,
};

export class ActorFixture {
  wallets: Wallet[];
  provider: MockProvider;

  constructor(wallets: Wallet[], provider: MockProvider) {
    (this.wallets = wallets), (this.provider = provider);
  }

  owner() {
    return this._getActor(WALLET_USER_INDEXES.OWNER);
  }

  deployer() {
    return this.owner();
  }

  other() {
    return this._getActor(WALLET_USER_INDEXES.OTHER);
  }

  anyone() {
    return this.other();
  }

  others(cnt: number) {
    if (cnt < 0) {
      throw new Error(`Invalid cnt: ${cnt}`);
    }
    return this.wallets.slice(WALLET_USER_INDEXES.OTHER, WALLET_USER_INDEXES.OTHER + cnt);
  }

  // Actual logic of fetching the wallet
  private _getActor(index: number): Wallet {
    if (index < 0) {
      throw new Error(`Invalid index: ${index}`);
    }
    const account = this.wallets[index];
    if (!account) {
      throw new Error(`Account ID ${index} could not be loaded`);
    }
    return account;
  }
}
