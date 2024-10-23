import { aoCreateProcess, aoDryRun, fetchProcessSrc } from 'common/ao';
import { getGQLData } from 'common/gql';

import { AO, CONTENT_TYPES, GATEWAYS, LICENSES, TAGS } from 'helpers/config';
import { AssetCreateArgsType, AssetType, GQLNodeResponseType, UDLicenseType } from 'helpers/types';
import { formatAddress, getTagValue } from 'helpers/utils';

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

export async function getAtomicAsset(args: { id: string }): Promise<AssetType | null> {
	try {
		const gqlResponse = await getGQLData({
			gateway: GATEWAYS.arweave,
			ids: [args.id],
			tagFilters: null,
			owners: null,
			cursor: null,
		});

		if (gqlResponse && gqlResponse.data.length) {
			let assetState: any = {
				name: null,
				ticker: null,
				denomination: null,
				logo: null,
				balances: null,
				transferable: null,
			};

			const asset = buildAsset(gqlResponse.data[0]);

			const processState = await aoDryRun({
				processId: asset.id,
				action: 'Info',
			});

			if (processState) {
				if (processState.Name || processState.name) {
					assetState.name = processState.Name || processState.name;
					asset.title = processState.Name || processState.name;
				}
				if (processState.Ticker || processState.ticker) assetState.ticker = processState.Ticker || processState.ticker;
				if (processState.Denomination || processState.denomination)
					assetState.denomination = processState.Denomination || processState.denomination;
				if (processState.Logo || processState.logo) assetState.logo = processState.Logo || processState.logo;
				if (processState.Balances) {
					assetState.balances = Object.fromEntries(
						Object.entries(processState.Balances).filter(([_, value]) => Number(value) !== 0)
					) as any;
				}
				if (processState.Transferable !== undefined) {
					assetState.transferable = processState.Transferable;
				} else {
					assetState.transferable = true;
				}
			}

			if (!assetState.balances) {
				try {
					const processBalances = await aoDryRun({
						processId: asset.id,
						action: 'Balances',
					});

					if (processBalances) assetState.balances = processBalances;
				} catch (e: any) {
					console.error(e);
				}
			}

			return { ...asset, ...assetState };
		}

		return null;
	} catch (e: any) {
		throw new Error(e.message || 'Error fetching atomic asset');
	}
}

export function buildAsset(element: GQLNodeResponseType): AssetType {
	let title =
		getTagValue(element.node.tags, TAGS.keys.title) ||
		getTagValue(element.node.tags, TAGS.keys.name) ||
		formatAddress(element.node.id, false);

	const asset = {
		id: element.node.id,
		title: title,
		description: getTagValue(element.node.tags, TAGS.keys.description),
		dateCreated: element.node.block
			? element.node.block.timestamp * 1000
			: element.node.timestamp
				? element.node.timestamp
				: getTagValue(element.node.tags, TAGS.keys.dateCreated)
					? Number(getTagValue(element.node.tags, TAGS.keys.dateCreated))
					: 0,
		blockHeight: element.node.block ? element.node.block.height : 0,
		creator: getTagValue(element.node.tags, TAGS.keys.creator) || '',
		renderWith: getTagValue(element.node.tags, TAGS.keys.renderWith),
		license: getTagValue(element.node.tags, TAGS.keys.license),
		udl: getLicense(element),
		thumbnail: getTagValue(element.node.tags, TAGS.keys.thumbnail),
		implementation: getTagValue(element.node.tags, TAGS.keys.implements),
		collectionId: getTagValue(element.node.tags, TAGS.keys.collectionId),
		collectionName: getTagValue(element.node.tags, TAGS.keys.collectionName),
		contentType: getTagValue(element.node.tags, TAGS.keys.contentType),
	}


	return asset;
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
