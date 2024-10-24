export const AO = {
	module: 'bkjb55i07GUCUSWROtKK4HU1mBS_X0TyH3M5jMV6aPg',
	scheduler: '_GQ33BkPtZrqxA84vM8Zk-N2aO0toNNu_C-l-rawrBA',
	src: {
		asset: 'KnGqTZnqT-vCMiOJfZaFrLj_ur6pxs3iuQuf7WnhYIw',
		zone: 'LEQTJbnBK0DlL41GQor01u2g061WTbni7L6Q6iyywIo'
	}
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

export const LICENSES = {
	udl: {
		label: 'Universal Data License',
		address: 'dE0rmDfl9_OWjkDznNEXHaSO_JohJkRolvMzaCroUdw'
	},
};

export const TAGS = {
	keys: {
		access: 'Access-Fee',
		avatar: 'Avatar',
		banner: 'Banner',
		collectionId: 'Collection-Id',
		collectionName: 'Collection-Name',
		commericalUse: 'Commercial-Use',
		contentType: 'Content-Type',
		creator: 'Creator',
		currency: 'Currency',
		dataModelTraining: 'Data-Model-Training',
		dataProtocol: 'Data-Protocol',
		dateCreated: 'Date-Created',
		derivations: 'Derivations',
		description: 'Description',
		displayName: 'Display-Name',
		handle: 'Handle',
		implements: 'Implements',
		initialOwner: 'Initial-Owner',
		license: 'License',
		name: 'Name',
		paymentAddress: 'Payment-Address',
		paymentMode: 'Payment-Mode',
		profileIndex: 'Profile-Index',
		protocolName: 'Protocol-Name',
		renderWith: 'Render-With',
		thumbnail: 'Thumbnail',
		title: 'Title',
		topic: 'Topic',
		type: 'Type',
	}
};