import { readFileSync } from 'fs';

import { createAtomicAsset, createZone, getAtomicAsset, getZone } from '@permaweb/sdk';

function expect(actual: any) {
	return {
		toBeDefined: () => {
			if (actual === undefined) {
				throw new Error(`Expected value to be defined, but it was undefined`);
			}
			console.log('\x1b[32m%s\x1b[0m', 'Success: Value is defined');
		},
		toHaveProperty: (prop: string) => {
			if (!(prop in actual)) {
				throw new Error(`Expected object to have property '${prop}', but it was not found`);
			}
			console.log('\x1b[32m%s\x1b[0m', `Success: Object has property '${prop}'`);
		},
		toEqualType: (expected: any) => {
			const actualType = typeof actual;
			const expectedType = typeof expected;

			if (actualType !== expectedType) {
				throw new Error(`Type mismatch: expected ${expectedType}, but got ${actualType}`);
			}

			if (actualType === 'object' && actual !== null && expected !== null) {
				if (Array.isArray(actual) !== Array.isArray(expected)) {
					throw new Error(`Type mismatch: expected ${Array.isArray(expected) ? 'array' : 'object'}, but got ${Array.isArray(actual) ? 'array' : 'object'}`);
				}
			}
			console.log('\x1b[32m%s\x1b[0m', `Success: Types match (${actualType})`);
		},
		toEqual: (expected: any) => {
			const actualType = typeof actual;
			const expectedType = typeof expected;

			if (actualType !== expectedType) {
				throw new Error(`Type mismatch: expected ${expectedType}, but got ${actualType}`);
			}

			if (actualType === 'object' && actual !== null && expected !== null) {
				const actualKeys = Object.keys(actual);
				const expectedKeys = Object.keys(expected);

				if (actualKeys.length !== expectedKeys.length) {
					throw new Error(`Object key count mismatch: expected ${expectedKeys.length}, but got ${actualKeys.length}`);
				}

				for (const key of actualKeys) {
					if (!(key in expected)) {
						throw new Error(`Expected object is missing key: ${key}`);
					}
					expect(actual[key]).toEqual(expected[key]);
				}
			} else if (actual !== expected) {
				throw new Error(`Value mismatch: expected ${expected}, but got ${actual}`);
			}
			console.log('\x1b[32m%s\x1b[0m', 'Success: Values are equal');
		},
	};
}

function logTest(message: string) {
    console.log('\x1b[33m%s\x1b[0m', `\n${message}`);
}

function logError(message: string) {
	console.error('\x1b[31m%s\x1b[0m', `Error (${message})`);
}

async function runTests() {
	try {
		console.log('Running tests...');
		const wallet = JSON.parse(readFileSync('./wallets/wallet.json', 'utf-8'));

		logTest('Testing atomic asset creation...');
		const assetId = await createAtomicAsset({
			title: 'Test Asset',
			description: 'This is a test atomic asset',
			type: 'article',
			topics: ['test', 'atomic', 'asset'],
			contentType: 'text/plain',
			data: '1234',
			creator: 'testCreator',
			collectionId: 'testCollection123',
			supply: 100,
			denomination: 1,
			transferable: true
		}, wallet, (status: any) => console.log(`Callback: ${status}`));

		expect(assetId).toBeDefined();
		expect(assetId).toEqualType('string');
		
		logTest('Testing atomic asset fetch...');
		const asset = await getAtomicAsset(assetId);

		expect(asset).toBeDefined();
		expect(asset.id).toEqual(assetId);
		expect(asset.title).toEqual('Test Asset');
		expect(asset.description).toEqual('This is a test atomic asset');

		logTest('Testing zone creation...');
		const zoneId = await createZone(wallet, (status: any) => console.log(`Callback: ${status}`));

		expect(zoneId).toBeDefined();
		expect(zoneId).toEqualType('string');

		logTest('Testing zone fetch...');
		const zone = await getZone(zoneId);

		expect(zone).toBeDefined();
		expect(zone).toEqual({ store: [], assets: [] })

		console.log('All tests passed successfully!');
	} catch (error) {
		logError((error as Error).message);
	}
}

runTests();