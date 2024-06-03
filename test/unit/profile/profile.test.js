import { test } from 'node:test'
import * as assert from 'node:assert'
import { SendFactory } from '../../../utils/aos.helper.js'
import fs from 'node:fs'
import {findMessageByTarget, logSendResult} from "../../../utils/message.js";

const Send = SendFactory();
const REGISTRY = 'kFYMezhjcPCZLr2EkkwzIXP5A64QmtME6Bxa8bGmbzI'

function getTag(msg, tagName) {
    return msg?.Tags?.find(t => t.name === tagName)?.value ?? null;
}

test('load source profile', async () => {
    const code = fs.readFileSync('./src/profile.lua', 'utf-8')
    const result = await Send({ Action: "Eval", Data: code })
})

test('should update', async () => {
    const updatedUserName = await Send({ Action: "Update-Profile", Data: JSON.stringify({ UserName: "Steve" }) })
    logSendResult(updatedUserName, "Update-Profile")
    const registryMessages = findMessageByTarget(updatedUserName.Messages, REGISTRY)
    assert.equal(getTag(updatedUserName.Messages[1], "Status"), "Success")

    // const updatedDescription = await Send({ Action: "Update-Profile", Data: JSON.stringify({ Description: "Terrible" }) })
    // logMessage('updated2', updatedDescription.Messages[0])
    // assert.equal(getTag(updatedDescription.Messages[0], "Status"), "Success")
    //
    // const updatedBadField = await Send({ Action: "Update-Profile", Data: JSON.stringify({ Nonsense: "Terrible" }) })
    // assert.equal(getTag(updatedBadField.Messages[0], "Status"), "Error")
})

// test('should get info', async () => {
//     const info = await Send({ Action: "Info" })
//     assert.equal(getProfileField(info.Messages[0], "Description"), "Terrible");
//     logMessage('info created timestamp', getProfileField(info.Messages[0], "DateCreated"))
//     logMessage('info updated timestamp', getProfileField(info.Messages[0], "DateUpdated"))
// })
