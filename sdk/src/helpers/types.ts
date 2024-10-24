export type ProcessSpawnType = {
	module: string;
	scheduler: string;
	data: any;
	tags: TagType[];
	wallet: any;
};

export type ProcessCreateType = {
	module?: string;
	scheduler?: string;
	spawnData?: any;
	spawnTags?: TagType[];
	evalTags?: TagType[];
	evalTxId?: string;
	evalSrc?: string;
	wallet: any;
};

export type MessageSendType = {
	processId: string;
	wallet: any;
	action: string;
	tags?: TagType[] | null;
	data?: any;
	useRawData?: boolean;
};

export type MessageResultType = {
	messageId: string;
	processId: string;
	action: string;
};

export type MessageDryRunType = {
	processId: string;
	action: string;
	tags?: TagType[] | null;
	data?: string | object;
};

export type AssetCreateArgsType = {
	title: string;
	description: string;
	type: string;
	topics: string[];
	contentType: string;
	data: any;
	creator?: string;
	collectionId?: string;
	supply?: number;
	denomination?: number;
	transferable?: boolean;
};

export type AssetHeaderType = {
	id: string;
	owner: string | null;
	creator: string | null;
	title: string | null;
	description: string | null;
	type: string | null;
	topics: string[] | null;
	implementation: string | null;
	contentType: string | null;
	renderWith: string | null;
	thumbnail: string | null;
	udl: UDLicenseType | null;
	collectionId: string | null;
	dateCreated: number | null;
	blockHeight: number | null;
};

export type AssetStateType = {
	ticker: string | null;
	denomination: string | null;
	balances: { [key: string]: string } | null;
	transferable: boolean | null;
}

export type AssetDetailType = AssetHeaderType & AssetStateType;

export type UDLicenseType = {
	access: UDLicenseValueType | null;
	derivations: UDLicenseValueType | null;
	commercialUse: UDLicenseValueType | null;
	dataModelTraining: UDLicenseValueType | null;
	paymentMode: string | null;
	paymentAddress: string | null;
	currency: string | null;
};

export type UDLicenseValueType = {
	value: string | null;
	icon?: string;
	endText?: string;
};

export type BaseGQLArgsType = {
	ids?: string[] | null;
	tagFilters?: TagFilterType[] | null;
	owners?: string[] | null;
	cursor?: string | null;
	paginator?: number;
	minBlock?: number;
	maxBlock?: number;
};

export type GQLArgsType = { gateway: string } & BaseGQLArgsType;

export type QueryBodyGQLArgsType = BaseGQLArgsType & { gateway?: string; queryKey?: string };

export type BatchGQLArgsType = {
	gateway: string;
	entries: { [queryKey: string]: BaseGQLArgsType };
};

export type GQLNodeResponseType = {
	cursor: string | null;
	node: {
		id: string;
		tags: TagType[];
		data: {
			size: string;
			type: string;
		};
		owner: {
			address: string;
		};
		block: {
			height: number;
			timestamp: number;
		};
	};
};

export type GQLResponseType = {
	count: number;
	nextCursor: string | null;
	previousCursor: string | null;
};

export type DefaultGQLResponseType = {
	data: GQLNodeResponseType[];
} & GQLResponseType;

export type BatchAGQLResponseType = { [queryKey: string]: DefaultGQLResponseType };

export type TagType = { name: string; value: string };

export type TagFilterType = { name: string; values: string[]; match?: string };
