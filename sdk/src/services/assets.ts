import { aoCreateProcess, aoDryRun, fetchProcessSrc } from 'common/ao';
import { getGQLData } from 'common/gql';

import { AO, CONTENT_TYPES, GATEWAYS, LICENSES, TAGS } from 'helpers/config';
import { AssetCreateArgsType, AssetDetailType, AssetHeaderType, AssetStateType, GQLNodeResponseType, UDLicenseType } from 'helpers/types';
import { formatAddress, getTagValue } from 'helpers/utils';

// TODO: Render-With
// TODO: Thumbnail
// TODO: License
export async function createAtomicAsset(args: AssetCreateArgsType, wallet: any, callback: (status: any) => void) {
	if (!validateAssetCreateArgs(args)) throw new Error('Invalid arguments passed for atomic asset creation');

	let processSrc: string | null = null;

	try {
		processSrc = await fetchProcessSrc(AO.src.asset);

		if (processSrc) {
			processSrc = processSrc.replaceAll(`'<NAME>'`, args.title);
			processSrc = processSrc.replaceAll('<TICKER>', 'ATOMIC');

			processSrc = processSrc.replaceAll('<DENOMINATION>', args.denomination ? args.denomination.toString() : '1');
			processSrc = processSrc.replaceAll('<BALANCE>', args.supply ? args.supply.toString() : '1');

			if (args.creator) processSrc = processSrc.replaceAll('<CREATOR>', args.creator);
			if (args.collectionId) processSrc = processSrc.replaceAll('<COLLECTION>', args.collectionId);
			if (!args.transferable) processSrc = processSrc.replace('Transferable = true', 'Transferable = false');
		}
	} catch (e: any) {
		throw new Error(e);
	}

	const tags = buildAssetTags(args);
	const data = CONTENT_TYPES[args.contentType]?.serialize(args.data) ?? args.data;

	try {
		const assetId = await aoCreateProcess(
			{
				spawnData: data,
				spawnTags: tags,
				wallet: wallet,
				evalSrc: processSrc,
			},
			(status) => callback(status),
		);
		return assetId;
	} catch (e: any) {
		throw new Error(e);
	}
}

// TODO: Get assets
// TODO: Get ids by address

export async function getAtomicAsset(id: string): Promise<AssetDetailType | null> {
	try {
		const gqlResponse = await getGQLData({
			gateway: GATEWAYS.arweave,
			ids: [id],
			tagFilters: null,
			owners: null,
			cursor: null,
		});

		if (gqlResponse && gqlResponse.data.length) {
			const asset: AssetHeaderType = buildAsset(gqlResponse.data[0]);
			
			let state: AssetStateType = {
				ticker: null,
				denomination: null,
				balances: null,
				transferable: null
			}

			const processState = await aoDryRun({
				processId: asset.id,
				action: 'Info',
			});

			if (processState) {
				if (processState.Name || processState.name) {
					asset.title = processState.Name || processState.name;
				}
				if (processState.Ticker || processState.ticker) state.ticker = processState.Ticker || processState.ticker;
				if (processState.Denomination || processState.denomination)
					state.denomination = processState.Denomination || processState.denomination;
				if (processState.Logo || processState.logo) asset.thumbnail = processState.Logo || processState.logo;
				if (processState.Balances) {
					state.balances = Object.fromEntries(
						Object.entries(processState.Balances).filter(([_, value]) => Number(value) !== 0)
					) as any;
				}
				if (processState.Transferable !== undefined) {
					state.transferable = processState.Transferable;
				} else {
					state.transferable = true;
				}
			}

			if (!state.balances) {
				try {
					const processBalances = await aoDryRun({
						processId: asset.id,
						action: 'Balances',
					});

					if (processBalances) state.balances = processBalances;
				} catch (e: any) {
					console.error(e);
				}
			}

			return { ...asset, ...state };
		}

		return null;
	} catch (e: any) {
		throw new Error(e.message || 'Error fetching atomic asset');
	}
}

export function buildAsset(element: GQLNodeResponseType): AssetHeaderType {
	const asset = {
		id: element.node.id,
		owner: element.node.owner.address,
		creator: getTagValue(element.node.tags, TAGS.keys.creator),
		title: getTitle(element),
		description: getTagValue(element.node.tags, TAGS.keys.description),
		type: getTagValue(element.node.tags, TAGS.keys.type),
		topics: getTopics(element),
		implementation: getTagValue(element.node.tags, TAGS.keys.implements),
		contentType: getTagValue(element.node.tags, TAGS.keys.contentType),
		renderWith: getTagValue(element.node.tags, TAGS.keys.renderWith),
		thumbnail: getTagValue(element.node.tags, TAGS.keys.thumbnail),
		udl: getLicense(element),
		collectionId: getTagValue(element.node.tags, TAGS.keys.collectionId),
		dateCreated: getDateCreated(element),
		blockHeight: element.node.block ? element.node.block.height : 0,
	}

	return asset;
}

function getTitle(element: GQLNodeResponseType): string {
    return getTagValue(element.node.tags, TAGS.keys.title) ||
           getTagValue(element.node.tags, TAGS.keys.name) ||
           formatAddress(element.node.id, false);
}

function getTopics(element: GQLNodeResponseType): string[] {
	return element.node.tags
		.filter(tag => tag.name.includes(TAGS.keys.topic.toLowerCase()))
		.map(tag => tag.value);
}


function getDateCreated(element: GQLNodeResponseType): number {
    if (element.node.block) {
        return element.node.block.timestamp * 1000;
    }

    const dateCreatedTag = getTagValue(element.node.tags, TAGS.keys.dateCreated);
    if (dateCreatedTag) {
        return Number(dateCreatedTag);
    }
    
    return 0;
}

function getLicense(element: GQLNodeResponseType): UDLicenseType | null {
	const license = getTagValue(element.node.tags, TAGS.keys.license);

	if (license && license === LICENSES.udl.address) {
		return {
			access: { value: getTagValue(element.node.tags, TAGS.keys.access) },
			derivations: { value: getTagValue(element.node.tags, TAGS.keys.derivations) },
			commercialUse: { value: getTagValue(element.node.tags, TAGS.keys.commericalUse) },
			dataModelTraining: { value: getTagValue(element.node.tags, TAGS.keys.dataModelTraining) },
			paymentMode: getTagValue(element.node.tags, TAGS.keys.paymentMode),
			paymentAddress: getTagValue(element.node.tags, TAGS.keys.paymentAddress),
			currency: getTagValue(element.node.tags, TAGS.keys.currency),
		};
	}
	return null;
}

function buildAssetTags(args: AssetCreateArgsType): { name: string; value: string }[] {
	const tags = [
		{ name: TAGS.keys.title, value: args.title },
		{ name: TAGS.keys.description, value: args.description },
		{ name: TAGS.keys.type, value: args.type },
		{ name: TAGS.keys.contentType, value: args.contentType },
		{ name: TAGS.keys.implements, value: 'ANS-110' },
		{ name: TAGS.keys.dateCreated, value: new Date().getTime().toString() },
	];

	args.topics.forEach((topic: string) => tags.push({ name: TAGS.keys.topic, value: topic }));

	if (args.creator) {
		tags.push({ name: TAGS.keys.creator, value: args.creator });
	}

	if (args.collectionId) {
		tags.push({ name: TAGS.keys.collectionId, value: args.collectionId });
	}

	return tags;
}

function validateAssetCreateArgs(args: AssetCreateArgsType): boolean {
	if (typeof args !== 'object' || args === null) return false;

	const requiredFields = ['title', 'description', 'type', 'topics', 'contentType', 'data'];
	for (const field of requiredFields) {
		if (!(field in args)) return false;
	}

	if (typeof args.title !== 'string' || args.title.trim() === '') return false;
	if (typeof args.description !== 'string') return false;
	if (typeof args.type !== 'string' || args.type.trim() === '') return false;
	if (!Array.isArray(args.topics) || args.topics.length === 0) return false;
	if (typeof args.contentType !== 'string' || args.contentType.trim() === '') return false;
	if (args.data === undefined || args.data === null) return false;

	if ('creator' in args && typeof args.creator !== 'string') return false;
	if ('collectionId' in args && typeof args.collectionId !== 'string') return false;
	if ('supply' in args && (typeof args.supply !== 'number' || args.supply <= 0)) return false;
	if ('transferable' in args && typeof args.transferable !== 'boolean') return false;

	return true;
}
