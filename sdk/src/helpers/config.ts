export const AO = {
	module: 'bkjb55i07GUCUSWROtKK4HU1mBS_X0TyH3M5jMV6aPg',
	scheduler: '_GQ33BkPtZrqxA84vM8Zk-N2aO0toNNu_C-l-rawrBA',
	assetSrc: 'meNSj8psG3uQrV0Xcgo0NxeNqTmqg_Kthne8UuPhmSs',
};

export const CONTENT_TYPES: { [key: string]: { type: string; serialize: (data: any) => any } } = {
	'application/json': {
		type: 'application/json',
		serialize: (data: any) => JSON.stringify(data),
	},
};

export const GATEWAYS = {
	arweave: 'arweave.net',
	goldsky: 'arweave-search.goldsky.com',
};
