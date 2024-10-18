import { aoCreateProcess } from 'common/ao';

export async function createAsset(args: {
	title: string;
	description: string;
	topics: string[];
	data: any;
	contentType: string;
	supply?: number;
	wallet: any
}) {
	try {
		const assetId = await aoCreateProcess(
			{
				module: 'bkjb55i07GUCUSWROtKK4HU1mBS_X0TyH3M5jMV6aPg',
				scheduler: '_GQ33BkPtZrqxA84vM8Zk-N2aO0toNNu_C-l-rawrBA',
				// spawnData: new Buffer(uint8Array.buffer),
				spawnData: args.data,
				spawnTags: [
					{ name: 'Content-Type', value: 'application/json' },
					// { name: 'Creator', value: arProvider.profile.id }, // TODO
					{ name: 'Title', value: args.title },
					{ name: 'Description', value: args.title },
					{ name: 'Type', value: 'Article' },
					{ name: 'Implements', value: 'ANS-110' },
					{ name: 'Date-Created', value: new Date().getTime().toString() },
					// { name: 'Action', value: 'Add-Uploaded-Asset' }, // TODO
				],
				evalTags: [],
				wallet: args.wallet,
				evalTxid: 'meNSj8psG3uQrV0Xcgo0NxeNqTmqg_Kthne8UuPhmSs',
			},
			(status) => console.log(status)
		);
		return assetId;
	}
	catch (e: any) {
		throw new Error(e);
	}
}