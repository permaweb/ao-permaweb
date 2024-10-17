import { test } from 'node:test'
import * as assert from 'node:assert'
import { SendFactory } from '../../utils/aos.helper.js'
import {getTag, logSendResult} from "../../utils/message.js";
import fs from 'node:fs'
import path from 'node:path'

const zoneSubscribeLuaPath = path.resolve('../subscribe-module/zone.lua');

const ZONE_ID = 'dWdBohXUJ22rfb8sSChdFh6oXJzbAtGe4tC6__52Zk4';
const ZONE_OWNER = "ADDRESS_R_CZLr2EkkwzIXP5A64QmtME6Bxa8bGmbzI";
const ANON_WALLET = "ADDRESS_ANON_r2EkkwzIXP5A64QmtME6Bxa8bGmbzI";

// Handlers
const H_SUBSCRIBER_UPDATE = "Zone-Subscriber.Update"
const H_SUBSCRIBER_REMOVE = "Zone-Subscriber.Remove"
const H_SUBSCRIBER_LIST = "Zone-Subscriber.List"

// Response Handlers
const H_SUBSCRIBER_UPDATE_ERROR = "Zone-Subscriber.Add-Error"
const H_SUBSCRIBER_REMOVE_ERROR = "Zone-Subscriber.Remove-Error"
const H_SUBSCRIBER_UPDATE_SUCCESS = "Zone-Subscriber.Add-Success"
const H_SUBSCRIBER_REMOVE_SUCCESS = "Zone-Subscriber.Remove-Success"
const H_SUBSCRIBER_LIST_SUCCESS = "Zone-Subscriber.List-Success"

const {Send} = SendFactory({processId: ZONE_ID, moduleId: '5555', defaultOwner: ZONE_OWNER, defaultFrom: ZONE_OWNER});
test("------------------------------BEGIN TEST------------------------------")
test("load zone subscribe test module", async () => {
    try {
        const code = fs.readFileSync(zoneSubscribeLuaPath, 'utf-8')
        const result = await Send({ From: ZONE_OWNER,
            Owner: ZONE_OWNER, Target: ZONE_ID, Action: "Eval", Data: code })
        logSendResult(result, "Load Source")
    } catch (error) {
        console.log(error)
    }
})

test("Should find initial subscribers", async () => {
    const result = await Send({From: ZONE_OWNER, Target: ZONE_ID, Action: H_SUBSCRIBER_LIST})
    logSendResult(result, "Find-No-Subs")
    assert.equal(getTag(result?.Messages[0], "Status"), "Success")
})

test("Should Add Subscriber", async () => {
    const inputData = { RegistryId: "1234", Actions: ["Hello"] }
    const result = await Send({ Target: ZONE_ID, From: ZONE_OWNER, Action: H_SUBSCRIBER_UPDATE, Data: JSON.stringify(inputData) })
    logSendResult(result, 'Subscriber add using update');
    assert.equal(getTag(result?.Messages[0], "Status"), "Success")
    const listResult = await Send({From: ZONE_OWNER, Target: ZONE_ID, Action: H_SUBSCRIBER_LIST})
    logSendResult(listResult, "Find-Two-Subs")
    assert.equal(getTag(listResult?.Messages[0], "Status"), "Success")
})

test("Should Update Subscriber", async () => {
    const inputData = { RegistryId: "1234", Actions: ["Hello", "Again"] }
    const result = await Send({ Target: ZONE_ID, From: ZONE_OWNER, Action: H_SUBSCRIBER_UPDATE, Data: JSON.stringify(inputData) })
    logSendResult(result, 'Subscriber add using update');
    assert.equal(getTag(result?.Messages[0], "Status"), "Success")
    const listResult = await Send({From: ZONE_OWNER, Target: ZONE_ID, Action: H_SUBSCRIBER_LIST})
    logSendResult(listResult, "Find-Two-Subs")
    assert.equal(getTag(listResult?.Messages[0], "Status"), "Success")
})

test("Rando Should Not Update Subscriber", async () => {
    const inputData = { RegistryId: "1234", Actions: ["Hello", "Again", "Hax"] }

    const result = await Send({ Target: ZONE_ID, From: ANON_WALLET, Action: H_SUBSCRIBER_UPDATE, Data: JSON.stringify(inputData) })
    logSendResult(result, 'Subscriber update from hacker');
    assert.equal(result?.Messages[0].Data, "Message is not trusted by this process!")
    const listResult = await Send({Target: ZONE_ID, Action: H_SUBSCRIBER_LIST})
    logSendResult(listResult, "Find-Hax-Subs")
    assert.equal(getTag(listResult?.Messages[0], "Status"), "Success")
})

test("Should Remove Subscriber", async () => {
    const inputData = { RegistryId: "1234" }
    const result = await Send({Target: ZONE_ID,  Action: H_SUBSCRIBER_REMOVE, Data: JSON.stringify(inputData)})
    logSendResult(result, "Remove 1234")
    assert.equal(getTag(result?.Messages[0], "Status"), "Success")
    const listResult = await Send({Target: ZONE_ID, Action: H_SUBSCRIBER_LIST})
    logSendResult(listResult, "Find-Hax-Subs")
    assert.equal(getTag(listResult?.Messages[0], "Status"), "Success")
})
