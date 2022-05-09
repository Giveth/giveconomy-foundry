import { MockProvider } from 'ethereum-waffle';
import { ActorFixture } from '../shared';

/**
 * HelperCommands is a utility that abstracts away lower-level ethereum details
 * so that we can focus on core business logic.
 *
 * Each helper function should be a `HelperTypes.CommandFunction`
 */
export class HelperCommands {
  actors: ActorFixture;
  provider: MockProvider;

  constructor(provider, actors) {
    this.provider = provider;
    this.actors = actors;
  }
}
