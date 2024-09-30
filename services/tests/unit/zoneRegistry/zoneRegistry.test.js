import { test } from 'node:test'
import { SendFactory } from '../../utils/aos.helper.js'
import fs from 'node:fs'
import path from 'node:path'

import {logSendResult} from "../../utils/message.js";
const registryLuaPath = path.resolve('../zone/zone-registry.lua');
const PROFILE_REGISTRY_ID = 'dWdBohXUJ22rfb8sSChdFh6oXJzbAtGe4tC6__52Zk4';
const REGISTRY_OWNER = "ADDRESS_R_CZLr2EkkwzIXP5A64QmtME6Bxa8bGmbzI";
const ANON_WALLET = "ADDRESS_ANON_r2EkkwzIXP5A64QmtME6Bxa8bGmbzI";

const {Send} = SendFactory({processId: PROFILE_REGISTRY_ID, moduleId: '5555', defaultOwner: ANON_WALLET, defaultFrom: ANON_WALLET});
test("------------------------------BEGIN TEST------------------------------")
test("load profileRegistry source", async () => {
    try {
        const code = fs.readFileSync(registryLuaPath, 'utf-8')
        const result = await Send({ From: REGISTRY_OWNER,
            Owner: REGISTRY_OWNER, Target: PROFILE_REGISTRY_ID, Action: "Eval", Data: code })
        logSendResult(result, "Load Source")
    } catch (error) {
        console.log(error)
    }
})

test("should prepare database", async () => {
    const preparedDb = await Send({
        From: REGISTRY_OWNER,
        Owner: REGISTRY_OWNER,
        Target: PROFILE_REGISTRY_ID,
        Id: "1111",
        Tags: {
            Action: "Prepare-Database"
        }
    })
    logSendResult(preparedDb, "Prepare-Database")
})


// create
// Zone-Metadata.Set
// Get-Z
