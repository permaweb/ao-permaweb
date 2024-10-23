import { createDataItemSigner, dryrun, message, result, results, spawn } from '@permaweb/aoconnect';

import { AO, GATEWAYS } from 'helpers/config';
import { getTxEndpoint } from 'helpers/endpoints';
import {
	MessageDryRunType,
	MessageResultType,
	MessageSendType,
	ProcessCreateType,
	ProcessSpawnType,
	TagType,
} from 'helpers/types';
import { getTagValue } from 'helpers/utils';

import { getGQLData } from './gql';

export const RETRY_COUNT = 200;

export async function aoSpawn(args: ProcessSpawnType): Promise<any> {
	const processId = await spawn({
		module: args.module,
		scheduler: args.scheduler,
		signer: createDataItemSigner(args.wallet),
		tags: args.tags,
		data: args.data,
	});

	return processId;
}

export async function aoSend(args: MessageSendType): Promise<any> {
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

export async function aoDryRun(args: MessageDryRunType): Promise<any> {
	try {
		const tags = [{ name: 'Action', value: args.action }];
		if (args.tags) tags.push(...args.tags);
		let dataPayload;
		if (typeof args.data === 'object') {
			dataPayload = JSON.stringify(args.data || {});
		} else if (typeof args.data === 'string') {
			// try to parse json and throw an error if it can't
			try {
				const jsonresult = JSON.parse(args.data);
			} catch (e) {
				console.error(e);
				throw new Error('Invalid JSON data');
			}
			dataPayload = args.data;
		}

		const response = await dryrun({
			process: args.processId,
			tags: tags,
			data: dataPayload,
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

export async function aoMessageResult(args: MessageResultType): Promise<any> {
	try {
		const { Messages } = await result({ message: args.messageId, process: args.processId });

		if (Messages && Messages.length) {
			const response: { [key: string]: any } = {};

			Messages.forEach((message: any) => {
				const action = getTagValue(message.Tags, 'Action') || args.action;

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

async function waitForProcess(processId: string, _setStatus?: (status: any) => void) {
	let retries = 0;

	while (retries < RETRY_COUNT) {
		await new Promise((r) => setTimeout(r, 2000));

		const gqlResponse = await getGQLData({
			gateway: GATEWAYS.goldsky,
			ids: [processId],
		});

		if (gqlResponse?.data?.length) {
			const foundProcess = gqlResponse.data[0].node.id;
			console.log(`Fetched transaction: ${foundProcess}`);
			return foundProcess;
		} else {
			console.log(`Transaction not found: ${processId}`);
			retries++;
			// setStatus && setStatus(`Retry: ${retries}`);
		}
	}

	// setStatus && setStatus('Error, not found');
	throw new Error(`Process not found, please try again`);
}

export async function fetchProcessSrc(txId: string): Promise<string> {
	try {
		const srcFetch = await fetch(getTxEndpoint(txId));
		return await srcFetch.text();
	} catch (e: any) {
		throw new Error(e);
	}
}

// TODO: Bootloader
// TODO: Handle fetch / modification
async function handleProcessEval(args: {
	processId: string;
	evalTxId: string | null;
	evalSrc: string | null;
	evalTags?: TagType[];
	wallet: any;
}): Promise<string | null> {
	let src: string | null = null;

	if (args.evalSrc) src = args.evalSrc;
	else if (args.evalTxId) src = await fetchProcessSrc(args.evalTxId);

	if (src) {
		try {
			const evalMessage = await aoSend({
				processId: args.processId,
				wallet: args.wallet,
				action: 'Eval',
				data: src,
				tags: args.evalTags || null,
				useRawData: true,
			});

			console.log(`Eval: ${evalMessage}`);

			const evalResult = await aoMessageResult({
				processId: args.processId,
				messageId: evalMessage,
				action: 'Eval',
			});

			return evalResult;
		} catch (e: any) {
			throw new Error(e);
		}
	}

	return null;
}

export async function aoCreateProcess(args: ProcessCreateType, statusCB?: (status: any) => void): Promise<string> {
	try {
		const spawnArgs: any = {
			module: args.module || AO.module,
			scheduler: args.scheduler || AO.scheduler,
			wallet: args.wallet,
		};

		if (args.spawnData) spawnArgs.data = args.spawnData;
		if (args.spawnTags) spawnArgs.tags = args.spawnTags;

		statusCB && statusCB(`Spawning process...`);
		const processId = await aoSpawn(spawnArgs);

		statusCB && statusCB(`Retrieving process...`);
		await waitForProcess(processId, statusCB);

		statusCB && statusCB(`Process retrieved!`);

		if (args.evalTxId || args.evalSrc) {
			statusCB && statusCB('Sending eval...');
			try {
				const evalResult = await handleProcessEval({
					processId: processId,
					evalTxId: args.evalTxId || null,
					evalSrc: args.evalSrc || null,
					evalTags: args.evalTags,
					wallet: args.wallet,
				});

				if (evalResult && statusCB) statusCB('Eval complete');
			} catch (e: any) {
				throw new Error(e);
			}
		}

		return processId;
	} catch (e: any) {
		throw new Error(e);
	}
}
