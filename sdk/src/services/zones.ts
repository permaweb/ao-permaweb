import { aoCreateProcess } from 'common/ao';

import { AO } from 'helpers/config';

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
