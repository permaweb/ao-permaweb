import { aoCreateProcess, aoDryRun, aoSend } from 'common/ao';

import { AO } from 'helpers/config';

// TODO: Add to registry
export async function createZone(wallet: any, callback: (status: any) => void): Promise<string | null> {
	try {
		const zoneId = await aoCreateProcess(
			{
				wallet: wallet,
				evalTxId: AO.src.zone,
			},
			(status) => callback(status),
		);
		return zoneId;
	} catch (e: any) {
		throw new Error(e);
	}
}

export async function updateZone(args: { zoneId: string, data: object }, wallet: any): Promise<string | null> {
	try {
		const mappedData = { entries: Object.entries(args.data).map(([key, value]) => ({ key, value })) };

		const zoneUpdateId = await aoSend({
			processId: args.zoneId,
			wallet: wallet,
			action: 'Update-Zone',
			data: mappedData
		});

		return zoneUpdateId;
	}
	catch (e: any) {
		throw new Error(e);
	}
}

export async function getZone(zoneId: string): Promise<{ store: object | null, assets: any } | null> {
	try {
		const processState = await aoDryRun({
			processId: zoneId,
			action: 'Info',
		});

		return processState
	}
	catch (e: any) {
		throw new Error(e);
	}
}