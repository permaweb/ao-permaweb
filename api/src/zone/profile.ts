import {ReadProfileArgs} from "./types";
import {aoDryRun, aoSpawn} from "../common/ao/ao";
import { connect, createDataItemSigner } from '@permaweb/aoconnect';

export async function readProfile(processId: string, keys: string[]) {
    try {
        // await aoDryRun( ... )
    } catch (e) {
    }
}

export async function updateProfile(processId: string, entries: {[key: string]: string}) {
    try {
        /*
            if len > 1
            await aoSend(
                action="PROFILE_SET"
                data=entries
            )
        */
    } catch (e) {
        console.error(e)
    }
}