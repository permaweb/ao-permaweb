import { aoCreateProcess, fetchProcessSrc } from 'common/ao';

import { AO, CONTENT_TYPES } from 'helpers/config';
import { AssetCreateArgsType } from 'helpers/types';

export async function createAsset(args: AssetCreateArgsType, wallet: any, callback: (status: any) => void) {
	if (!validateAssetArgs) throw new Error('Asset args are invalid');

	let processSrc: string | null = null;

	try {
		processSrc = await fetchProcessSrc(AO.assetSrc);

		if (processSrc) {
			processSrc = processSrc.replaceAll(`'<NAME>'`, args.title);
			processSrc = processSrc.replaceAll('<TICKER>', 'ATOMIC');
			processSrc = processSrc.replaceAll('<DENOMINATION>', '1');
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

function buildAssetTags(args: AssetCreateArgsType): { name: string; value: string }[] {
	const tags = [
		{ name: 'Title', value: args.title },
		{ name: 'Description', value: args.description },
		{ name: 'Type', value: args.type },
		{ name: 'Content-Type', value: args.contentType },
		{ name: 'Implements', value: 'ANS-110' },
		{ name: 'Date-Created', value: new Date().getTime().toString() },
	];

	args.topics.forEach((topic: string) => tags.push({ name: 'Topic', value: topic }));

	if (args.creator) {
		tags.push({ name: 'Creator', value: args.creator });
	}

	if (args.collectionId) {
		tags.push({ name: 'Collection', value: args.collectionId });
	}

	if (args.supply !== undefined) {
		tags.push({ name: 'Supply', value: args.supply.toString() });
	}

	if (args.transferable !== undefined) {
		tags.push({ name: 'Transferable', value: args.transferable.toString() });
	}

	return tags;
}

function validateAssetArgs(args: AssetCreateArgsType): boolean {
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
