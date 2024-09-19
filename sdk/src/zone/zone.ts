import {aoMessageResult, aoSend, aoSpawn} from '../common/ao';
import { APICreateZone } from '../types/zone';
import {getGQLData} from "../common/gql";
import {GATEWAYS} from "../common/helpers/config";

export async function createZone(args: APICreateZone, setStatus: (status: any) => void) {
	const spawnArgs = {
		module: args.module,
		scheduler: args.scheduler,
		wallet: args.wallet,
		tags: args.tags,
		data: args.data,
	}
	const processTxid = await aoSpawn(spawnArgs)

	type CreateStatus = { step: string, retries: number }
	const status = {
		step: "waiting",
		retries: 0
	}
	setStatus(status)

	console.log('Fetching profile process...');
	let fetchedAssetId: string = '';
	while (!fetchedAssetId) {
		setStatus(status)

		await new Promise((r) => setTimeout(r, 2000));
		const gqlResponse = await getGQLData({
			gateway: GATEWAYS.goldsky,
			ids: [processTxid],
			tagFilters: null,
			owners: null,
			cursor: null,
		});

		if (gqlResponse && gqlResponse.data.length) {
			console.log(`Fetched transaction -`, gqlResponse.data[0].node.id);
			fetchedAssetId = gqlResponse.data[0].node.id;
		} else {
			console.log(`Transaction not found -`, processTxid);
			status.retries++;
			if (status.retries >= 200) {
				status.step = "failed"
				setStatus(status);
				throw new Error(`Profile not found, please try again`);
			}
		}
	}

	if (fetchedAssetId) {
		console.log('Sending source eval...');
		const evalMessage = await aoSend({
			processId: processTxid,
			action: 'Eval',
			wallet: args.wallet,
			data: "srcdata...",
			tags: null,
		});

		console.log(evalMessage);

		const evalResult = await aoMessageResult({
			processId: processTxid,
			messageId: evalMessage,
			messageAction: 'Eval',
		});

		console.log(evalResult);

		await new Promise((r) => setTimeout(r, 1000));

		console.log('Updating profile data...');
		//
		// 	const updateMessageId = await aoSend({
		// 		processId: processId,
		// 		action: 'Update-Profile',
		// 		wallet: arProvider.wallet,
		// 		data: data,
		// 	});
		//
		// 	let updateResponse = await aoMessageResult({
		// 		processId: processId,
		// 		messageId: updateMessageId,
		// 		messageAction: 'Update-Profile',
		// 	});
		//
		// 	if (updateResponse && updateResponse['Profile-Success']) {
		// 		setProfileResponse({
		// 			message: `${language.profileCreated}!`,
		// 			status: 'success',
		// 		});
		// 		handleUpdate();
		// 	} else {
		// 		console.log(updateResponse);
		// 		setProfileResponse(language.errorUpdatingProfile);
		// 		setProfileResponse({
		// 			message: language.errorUpdatingProfile,
		// 			status: 'warning',
		// 		});
		// 	}
		// } else {
		// 	setProfileResponse({
		// 		message: language.errorUpdatingProfile,
		// 		status: 'warning',
		// 	});
		// }
	}
}
/*
export async function initZone() {
    // wait for zone
    // eval(big script)
    // return
}

export async function evalZone() {
    // eval monolithic script that includes apm
    // aoSend...
}

export async function getZone(wallet: string) {
    // graphql?
    // return zoneid
    return
}

export async function zoneAPMAdd() {
}

export async function zoneCapabilities() {
}

 */
