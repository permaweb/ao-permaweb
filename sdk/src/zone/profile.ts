import { ReadProfileArgs } from 'types/profile';

import { connect, createDataItemSigner } from '@permaweb/aoconnect';

import { aoDryRun, aoSpawn } from '../common/ao';

export async function readMetadata(processId: string, keys: string[]) {
	try {
		// await aoDryRun( ... )
	} catch (e) {}
}

export async function updateMetadata(processId: string, entries: { [key: string]: string }) {
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
