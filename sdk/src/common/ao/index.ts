import { APIDryRunType, APIResultType, APISendType, APISpawnType } from 'types/ao';
import { TagType } from 'types/helpers';

import { connect, createDataItemSigner, dryrun, message, result, results } from '@permaweb/aoconnect';

import { getTagValue } from '../utils';

export async function aoSpawn(args: APISpawnType): Promise<any> {
	const aos = connect();
	
	const processId = await aos.spawn({
		module: args.module,
		scheduler: args.scheduler,
		signer: createDataItemSigner(args.wallet),
		tags: args.tags,
		data: JSON.stringify(args.data),
	});

	return processId;
}

export async function aoSend(args: APISendType): Promise<any> {
	try {
		const tags: TagType[] = [{ name: 'Action', value: args.action }];
		if (args.tags) tags.push(...args.tags);

		const data = args.useRawData ? args.data : JSON.stringify(args.data);

		const txId = await message({
			process: args.processId,
			signer: createDataItemSigner(args.wallet),
			tags: tags,
			data: data,
		});

		return txId;
	} catch (e) {
		console.error(e);
	}
}

export async function aoDryRun(args: APIDryRunType): Promise<any> {
	try {
		const tags = [{ name: 'Action', value: args.action }];
		if (args.tags) tags.push(...args.tags);
		let data = JSON.stringify(args.data || {});

		const response = await dryrun({
			process: args.processId,
			tags: tags,
			data: data,
		});

		if (response.Messages && response.Messages.length) {
			if (response.Messages[0].Data) {
				return JSON.parse(response.Messages[0].Data);
			} else {
				if (response.Messages[0].Tags) {
					return response.Messages[0].Tags.reduce((acc: any, item: any) => {
						acc[item.name] = item.value;
						return acc;
					}, {});
				}
			}
		}
	} catch (e) {
		console.error(e);
	}
}

export async function aoMessageResult(args: APIResultType): Promise<any> {
	try {
		const { Messages } = await result({ message: args.messageId, process: args.processId });

		if (Messages && Messages.length) {
			const response: { [key: string]: any } = {};

			Messages.forEach((message: any) => {
				const action = getTagValue(message.Tags, 'Action') || args.messageAction;

				let responseData = null;
				const messageData = message.Data;

				if (messageData) {
					try {
						responseData = JSON.parse(messageData);
					} catch {
						responseData = messageData;
					}
				}

				const responseStatus = getTagValue(message.Tags, 'Status');
				const responseMessage = getTagValue(message.Tags, 'Message');

				response[action] = {
					id: args.messageId,
					status: responseStatus,
					message: responseMessage,
					data: responseData,
				};
			});

			return response;
		} else return null;
	} catch (e) {
		console.error(e);
	}
}

// TODO: Remove unnecessary handler arg / get correct responses
export async function aoMessageResults(args: {
	processId: string;
	wallet: any;
	action: string;
	tags: TagType[] | null;
	data: any;
	responses?: string[];
	handler?: string;
}): Promise<any> {
	try {
		const tags = [{ name: 'Action', value: args.action }];
		if (args.tags) tags.push(...args.tags);

		await message({
			process: args.processId,
			signer: createDataItemSigner(args.wallet),
			tags: tags,
			data: JSON.stringify(args.data),
		});

		await new Promise((resolve) => setTimeout(resolve, 1000));

		const messageResults = await results({
			process: args.processId,
			sort: 'DESC',
			limit: 100,
		});

		if (messageResults && messageResults.edges && messageResults.edges.length) {
			const response: any = {};

			for (const result of messageResults.edges) {
				if (result.node && result.node.Messages && result.node.Messages.length) {
					const resultSet: any[] = [args.action];
					if (args.responses) resultSet.push(...args.responses);

					for (const message of result.node.Messages) {
						const action = getTagValue(message.Tags, 'Action');

						if (action) {
							let responseData = null;
							const messageData = message.Data;

							if (messageData) {
								try {
									responseData = JSON.parse(messageData);
								} catch {
									responseData = messageData;
								}
							}

							const responseStatus = getTagValue(message.Tags, 'Status');
							const responseMessage = getTagValue(message.Tags, 'Message');

							if (action === 'Action-Response') {
								const responseHandler = getTagValue(message.Tags, 'Handler');
								if (args.handler && args.handler === responseHandler) {
									response[action] = {
										status: responseStatus,
										message: responseMessage,
										data: responseData,
									};
								}
							} else {
								if (resultSet.indexOf(action) !== -1) {
									response[action] = {
										status: responseStatus,
										message: responseMessage,
										data: responseData,
									};
								}
							}

							if (Object.keys(response).length === resultSet.length) break;
						}
					}
				}
			}

			return response;
		}

		return null;
	} catch (e) {
		console.error(e);
	}
}
