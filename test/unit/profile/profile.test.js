import { test } from 'node:test'
import * as assert from 'node:assert'
import { SendFactory } from '../../../utils/aos.helper.js'
import fs from 'node:fs'
import {findMessageByTag, findMessageByTarget, logSendResult} from "../../../utils/message.js";

const REGISTRY = 'kFYMezhjcPCZLr2EkkwzIXP5A64QmtME6Bxa8bGmbzI'
const AUTHORIZED_ADDRESS_A = "ADDRESS_A";
const AUTHORIZED_ADDRESS_B = "ADDRESS_B";
const {Send} = SendFactory();
function getTag(msg, tagName) {
    return msg?.Tags?.find(t => t.name === tagName)?.value ?? null;
}

test('load source profile', async () => {
    const code = fs.readFileSync('./src/ao-profile/profile.lua', 'utf-8')
    const result = await Send({ Owner: AUTHORIZED_ADDRESS_A, From: AUTHORIZED_ADDRESS_A, Action: "Eval", Data: code })
})

test('should fail to update if from is not owner', async () => {
    const updateResult = await Send({ From: AUTHORIZED_ADDRESS_B, Action: "Update-Profile", Data: JSON.stringify({ UserName: "Steve", DisplayName: "Steverino" }) })
    logSendResult(updateResult, "Update-Profile--Fail")
    // const registryMessages = findMessageByTarget(updateResult.Messages, REGISTRY)
    const statusMessages = findMessageByTag(updateResult.Messages, "Status");
    assert.equal(getTag(statusMessages[0], "Status"), "Error")
})
test('should update', async () => {
    const updateResult = await Send({ From: AUTHORIZED_ADDRESS_A, Action: "Update-Profile", Data: JSON.stringify({ UserName: "Steve", DisplayName: "Steverino" }) })
    logSendResult(updateResult, "Update-Profile--Pass")
    const statusMessages = findMessageByTag(updateResult.Messages, "Status");
    assert.equal(getTag(statusMessages[0], "Status"), "Success")
})

test('should update with tags', async () => {
    const updateResult = await Send({ From: AUTHORIZED_ADDRESS_A, Action: "Update-Profile", DisplayName: "El Steverino" })
    logSendResult(updateResult, "Update-Profile")
    const statusMessages = findMessageByTag(updateResult.Messages, "Status");
    assert.equal(getTag(statusMessages[0], "Status"), "Success")
})



// test('should get info', async () => {
//     const info = await Send({ Action: "Info" })
//     assert.equal(getProfileField(info.Messages[0], "Description"), "Terrible");
//     logMessage('info created timestamp', getProfileField(info.Messages[0], "DateCreated"))
//     logMessage('info updated timestamp', getProfileField(info.Messages[0], "DateUpdated"))

// })
