import {APICreateProcessType, APIDryRunType, APIResultType, APISendType, APISpawnType} from 'types/ao';
import { TagType } from 'types/helpers';

import { connect, createDataItemSigner, dryrun, message, result, results  } from '@permaweb/aoconnect';

import { getTagValue } from 'common/helpers';
import {GATEWAYS, getTxEndpoint} from "common";
import {getGQLData} from "common";

export const RETRY_COUNT = 200;
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
		let dataPayload;
		if (typeof(args.data) === "object") {
			dataPayload = JSON.stringify(args.data || {});
		} else if (typeof(args.data) === "string") {
			// try to parse json and throw an error if it can't
			try {
				const jsonresult = JSON.parse(args.data)
			} catch (e) {
				console.error(e);
				throw new Error("Invalid JSON data");
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

async function waitForProcess(processId: string, setStatus?: (status: any) => void) {
	let retries = 0;

	while (retries < RETRY_COUNT) {
		await new Promise((r) => setTimeout(r, 2000));

		const gqlResponse = await getGQLData({
			gateway: GATEWAYS.goldsky,
			ids: [processId],
		});

		if (gqlResponse?.data?.length) {
			const foundProcess = gqlResponse.data[0].node.id;
			console.log(`Fetched transaction -`, foundProcess);
			return foundProcess;
		} else {
			console.log(`Transaction not found -`, processId);
			retries++;
			setStatus && setStatus(`Retrying: ${retries}`);
		}
	}

	setStatus && setStatus("Error, not found");
	throw new Error(`Profile not found, please try again`);
}

export async function aoCreateProcess(args: APICreateProcessType, statusCB?: (status: any) => void): Promise<any> {
	try {
		const processSrcFetch = await fetch(getTxEndpoint(args.evalTxid));

		const processId = await aoSpawn({
			module: args.module,
			scheduler: args.scheduler,
			data: args.spawnData,
			tags: args.spawnTags,
			wallet: args.wallet
		})

		const src = await processSrcFetch.text()

		await waitForProcess(processId, statusCB)
		statusCB && statusCB("Spawned and found:" + processId)
		const evalMessage = await aoSend({
			processId,
			wallet: args.wallet,
			action: 'Eval',
			data: src,
			tags: args.evalTags,
			useRawData: true,
		})
		statusCB && statusCB("Eval sent")
		console.log('evalmsg', evalMessage)

		const evalResult = await aoMessageResult({
			processId: processId,
			messageId: evalMessage,
			messageAction: 'Eval',
		});
		statusCB && statusCB("Eval success")
		console.log(evalResult);

	} catch (e: unknown) {
		let message = '';
		if (e instanceof Error) {
			message = e.message;
		} else if (typeof e === "string" ) {
			message = e;
		} else {
			message = "Unknown error";
		}
		statusCB && statusCB(`Create failed: message: ${message}`)
	}
	// spawn
	// wait/fetch
	// eval
}
