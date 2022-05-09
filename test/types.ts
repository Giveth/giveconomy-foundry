import { createFixtureLoader } from 'ethereum-waffle';

export type LoadFixtureFunction = ReturnType<typeof createFixtureLoader>;
