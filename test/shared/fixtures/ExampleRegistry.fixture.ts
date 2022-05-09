import { Fixture } from 'ethereum-waffle';
import { waffle } from 'hardhat';
import { ExampleRegistry, ExampleRegistry__factory } from '../../../typechain-types';
import { ActorFixture } from '../actors';
import { provider } from '../provider';

const { abi, bytecode } = ExampleRegistry__factory;

export type ExampleRegistryFixture = {
  exampleRegistry: ExampleRegistry;
  owner: string;
};

export const exampleRegistryFixture: Fixture<ExampleRegistryFixture> = async ([wallet]) => {
  const actors = new ActorFixture(provider.getWallets(), provider);

  const exampleRegistry = (await waffle.deployContract(wallet, {
    abi,
    bytecode,
  })) as ExampleRegistry;

  return {
    exampleRegistry,
    owner: actors.deployer().address,
  };
};
