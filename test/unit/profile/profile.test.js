import { test } from 'node:test'
import * as assert from 'node:assert'
import { SendFactory } from '../../../utils/aos.helper.js'
import fs from 'node:fs'
import {findMessageByTarget, logSendResult} from "../../../utils/message.js";

const Send = SendFactory();
const REGISTRY = 'kFYMezhjcPCZLr2EkkwzIXP5A64QmtME6Bxa8bGmbzI'
const AUTHORIZED_ADDRESS_A = 87654;
const AUTHORIZED_ADDRESS_B = 76543;
function getTag(msg, tagName) {
    return msg?.Tags?.find(t => t.name === tagName)?.value ?? null;
}

test('load source profile', async () => {
    const code = fs.readFileSync('./src/ao-profile/profile.lua', 'utf-8')
    const result = await Send({ Action: "Eval", Data: code })
})

test('should update', async () => {
    const updatedUserName = await Send({ Owner: AUTHORIZED_ADDRESS_A, From: AUTHORIZED_ADDRESS_A, Action: "Update-Profile", Data: JSON.stringify({ UserName: "Steve", DisplayName: "Steverino" }) })
    logSendResult(updatedUserName, "Update-Profile")
    const registryMessages = findMessageByTarget(updatedUserName.Messages, REGISTRY)
    assert.equal(getTag(updatedUserName?.Messages[0], "Status"), "Success")
})

test('should update with tags', async () => {
    const updatedUserName = await Send({ Action: "Update-Profile", DisplayName: "El Steverino" })
    logSendResult(updatedUserName, "Update-Profile")
    const registryMessages = findMessageByTarget(updatedUserName.Messages, REGISTRY)
    assert.equal(getTag(updatedUserName.Messages[1], "Status"), "Success")
})

// test('should get info', async () => {
//     const info = await Send({ Action: "Info" })
//     assert.equal(getProfileField(info.Messages[0], "Description"), "Terrible");
//     logMessage('info created timestamp', getProfileField(info.Messages[0], "DateCreated"))
//     logMessage('info updated timestamp', getProfileField(info.Messages[0], "DateUpdated"))
// })
