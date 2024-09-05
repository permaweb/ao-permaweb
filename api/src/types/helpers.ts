export type EntryOrderType = {
	DepositTxId: string;
	DateCreated: string;
	OriginalQuantity: string;
	Creator: string;
	Id: string;
	Token: string;
	Quantity: string;
	Price?: string;
};

export type OrderbookEntryType = {
	Pair: string[];
	Orders?: EntryOrderType[];
	PriceData?: {
		DominantToken: string;
		Vwap: string;
		MatchLogs: {
			Id: string;
			Quantity: string;
			Price: string;
		}[];
		Block: string;
	};
};

export type AssetStateType = {
	name: string | null;
	ticker: string | null;
	denomination: number | null;
	logo: string | null;
	transferable: boolean;
	balances: { [address: string]: string } | null;
};

export type AssetOrderType = {
	creator: string | null;
	dateCreated: string | null;
	id: string | null;
	originalQuantity: string | null;
	price?: string | null;
	quantity: string | null;
	token: string | null;
	currency: string | null;
};

export type LicenseValueType = {
	value: string;
	icon?: string;
	endText?: string;
};

export type LicenseType = {
	access: LicenseValueType | null;
	derivations: LicenseValueType | null;
	commercialUse: LicenseValueType | null;
	dataModelTraining: LicenseValueType | null;
	paymentMode: string | null;
	paymentAddress: string | null;
	currency: string | null;
};

export type AssetType = {
	data: {
		id: string;
		creator: string;
		title: string;
		description: string | null;
		dateCreated: number;
		blockHeight: number;
		renderWith: string | null;
		license: string | null;
		udl: LicenseType | null;
		thumbnail: string | null;
		implementation: string | null;
		collectionId?: string | null;
		collectionName?: string | null;
		contentType?: string | null;
	};
};

export type AssetDetailType = AssetType & {
	state?: AssetStateType;
	orders?: AssetOrderType[];
};

export type AOProfileType = {
	id: string;
	walletAddress: string;
	displayName: string | null;
	username: string | null;
	bio: string | null;
	avatar: string | null;
	banner: string | null;
	version: string | null;
};

export type ProfileHeaderType = AOProfileType;

export type RegistryProfileType = {
	id: string;
	avatar: string | null;
	username: string;
	bio?: string;
};

export type OwnerType = {
	address: string;
	profile: RegistryProfileType | null;
	ownerQuantity?: number;
	ownerPercentage?: number;
};

export type ListingType = AssetOrderType & { profile: RegistryProfileType };

export type CollectionManifestType = {
	type: string;
	items: string[];
};

export type CollectionMetricsType = {
	assetCount: number | null;
	floorPrice: number | null;
	percentageListed: number | null;
	defaultCurrency: string;
};

export type CollectionType = {
	id: string;
	title: string;
	description: string | null;
	creator: string;
	dateCreated: string;
	banner: string | null;
	thumbnail: string | null;
};

export type CollectionDetailType = CollectionType & {
	assetIds: string[];
	creatorProfile: ProfileHeaderType;
	metrics: CollectionMetricsType;
};

export type TagType = { name: string; value: string };

export type TagFilterType = { name: string; values: string[]; match?: string };

export enum WalletEnum {
	arConnect = 'arconnect',
	othent = 'othent',
}

export type RenderType = 'renderer' | 'raw';

export type ContentType = 'renderer' | any;

export type AssetRenderType = {
	url: string;
	type: RenderType;
	contentType: ContentType;
};

export type DateType = 'iso' | 'epoch';

export type FormFieldType = 'number' | 'password';

export type TabType = 'primary' | 'alt1';

export type AssetMarketActionOrderType = 'buy' | 'sell' | 'transfer';

export type ReduxActionType = {
	type: string;
	payload: any;
};

export type ValidationType = {
	status: boolean;
	message: string | null;
};

export type AssetSortType = 'high-to-low' | 'low-to-high' | 'recently-listed';

export type IdGroupType = { [index: string]: string[] };

export type ButtonType = 'primary' | 'alt1' | 'alt2' | 'alt3' | 'success' | 'warning';

export type SelectOptionType = { id: string; label: string };

export type UploadMethodType = 'default' | 'turbo';

export type NotificationType = {
	message: string;
	status: 'success' | 'warning';
};

export type AssetViewType = 'trading' | 'reading';

export type StreakType = { address: string; days: number; lastHeight: number; profile: RegistryProfileType | null };
