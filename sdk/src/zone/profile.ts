import { connect, createDataItemSigner } from '@permaweb/aoconnect';

import { aoDryRun, aoSpawn } from '../common/ao';

import { ReadProfileArgs } from './types';

export async function readProfile(processId: string, keys: string[]) {
	try {
		// await aoDryRun( ... )
	} catch (e) {}
}

export async function updateProfile(processId: string, entries: { [key: string]: string }) {
	try {
		/*
            if len > 1
            await aoSend(
                action="PROFILE_SET"
                data=entries
            )
        */
	} catch (e) {
		console.error(e);
	}
}
