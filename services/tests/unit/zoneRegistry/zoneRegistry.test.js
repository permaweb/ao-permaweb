import { test } from 'node:test'
import * as assert from 'node:assert'
import { SendFactory } from '../../utils/aos.helper.js'
import fs from 'node:fs'
import path from 'node:path'


import {getTag, logSendResult} from "../../utils/message.js";
const registryLuaPath = path.resolve('../zone-registries/zone-registry.lua');
const PROFILE_REGISTRY_ID = 'dWdBohXUJ22rfb8sSChdFh6oXJzbAtGe4tC6__52Zk4';
const REGISTRY_OWNER = "ADDRESS_R_CZLr2EkkwzIXP5A64QmtME6Bxa8bGmbzI";
const ANON_WALLET = "ADDRESS_ANON_r2EkkwzIXP5A64QmtME6Bxa8bGmbzI";
const PROFILE_A_USERNAME = "Steve";
const PROFILE_B_USERNAME = "Bob";
const PROFILE_BOB_ID = "PROFILE_B_CZLr2EkkwzIXP5A64QmtME6Bxa8bGmbzI";
const STEVE_PROFILE_ID = "PROFILE_A_CZLr2EkkwzIXP5A64QmtME6Bxa8bGmbzI";
const STEVE_WALLET = "ADDRESS_A_CZLr2EkkwzIXP5A64QmtME6Bxa8bGmbzI";
const BOB_WALLET = "ADDRESS_B_CZLr2EkkwzIXP5A64QmtME6Bxa8bGmbzI";

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
test("should find no zone at missing wallet address", async () => {
    const inputData = { Address: STEVE_WALLET }
    const result = await Send({Action: "Get-Zones-For-User", Data: JSON.stringify(inputData)})
    logSendResult(result, "Find-No-Zones")
    assert.equal(getTag(result?.Messages[0], "Status"), "Error")
})

test("BOB should create zone in registry", async () => {
    // read the assigned create/update profile methods from user spawn
    const inputData = { UserName: PROFILE_B_USERNAME, DateCreated: 125555, DateUpdated: 125555 }
    const result = await Send({ Target: PROFILE_BOB_ID, From: BOB_WALLET, Owner: BOB_WALLET, Action: "Create-Zone", Data: JSON.stringify(inputData) })
    logSendResult(result, 'Create-Profile-B');
    assert.equal(getTag(result?.Messages[0], "Status"), "Success")
})

test("should find Bob's zone roles", async () => {
    const inputData = { Address: BOB_WALLET }
    const result = await Send({Action: "Get-Zones-For-User", Data: JSON.stringify(inputData)})
    logSendResult(result, "Find-Bob-Zone")
    assert.equal(getTag(result?.Messages[0], "Status"), "Success")
})

// create
// Zone-Metadata.Set
// Get-Z
