import type { Config } from 'jest';

const config: Config = {
    preset: 'ts-jest',
    testEnvironment: 'node',
    testPathIgnorePatterns: ['/node_modules/', '/dist/', 'tests/Task2.spec.ts', 'tests/Task3.spec.ts', 'tests/Task4.spec.ts', 'tests/Task5.spec.ts'],
};

export default config;
