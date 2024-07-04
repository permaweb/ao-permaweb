import { test } from 'node:test'
import * as assert from 'node:assert'
import { SendFactory } from '../../../utils/aos.helper.js'
import fs from 'node:fs'
import {findMessageByTag, findMessageByTagValue, logSendResult} from "../../../utils/message.js";

const REGISTRY = 'kFYMezhjcPCZLr2EkkwzIXP5A64QmtME6Bxa8bGmbzI'
const PROFILE_A_ID = "PROFILE_A_CZLr2EkkwzIXP5A64QmtME6Bxa8bGmbzI";
const AUTHORIZED_ADDRESS_A = "ADDRESS_A_CZLr2EkkwzIXP5A64QmtME6Bxa8bGmbzI";
const AUTHORIZED_ADDRESS_B = "ADDRESS_B_CZLr2EkkwzIXP5A64QmtME6Bxa8bGmbzI";
const {Send} = SendFactory({ processId: PROFILE_A_ID, moduleId: '5555'});
function getTag(msg, tagName) {
    return msg?.Tags?.find(t => t.name === tagName)?.value ?? null;
}
test("------------------------------P V000 BEGIN TEST------------------------------")
test('load source profile', async () => {
    const code = fs.readFileSync('./profiles/profile.lua', 'utf-8')
    const result = await Send({ Owner: AUTHORIZED_ADDRESS_A, From: AUTHORIZED_ADDRESS_A, Action: "Eval", Data: code })
})

test('should fail to update if from is not owner', async () => {
    const updateResult = await Send({ Id: "1111", From: AUTHORIZED_ADDRESS_B, Action: "Update-Profile", Data: JSON.stringify({ UserName: "Steve", DisplayName: "Steverino" }) })
    // logSendResult(updateResult, "Update-Profile--Fail")
    // const registryMessages = findMessageByTarget(updateResult.Messages, REGISTRY)
    const statusMessages = findMessageByTag(updateResult.Messages, "Status");
    assert.equal(getTag(statusMessages[0], "Status"), "Error")
})
test('should update with data', async () => {
    const updateResult = await Send({ Id: "1112", From: AUTHORIZED_ADDRESS_A, Action: "Update-Profile", Data: JSON.stringify({ UserName: "Steve", DisplayName: "Steverino" }) })
    // logSendResult(updateResult, "Update-Profile--Pass")
    const statusMessages = findMessageByTag(updateResult.Messages, "Status");
    assert.equal(getTag(statusMessages[0], "Status"), "Success")
})

test('should update with tags', async () => {
    const updateResult = await Send({ Id: "1113", From: AUTHORIZED_ADDRESS_A, Action: "Update-Profile", DisplayName: "El Steverino" })
    // logSendResult(updateResult, "Update-Profile")
    const statusMessages = findMessageByTag(updateResult.Messages, "Status");
    assert.equal(getTag(statusMessages[0], "Status"), "Success")
})

test('should get info', async () => {
    const info = await Send({ Action: "Info" })
    // logSendResult(info, "Info")
    const dataMessage = findMessageByTagValue(info.Messages, "Action", "Read-Success");
    const dataString = dataMessage[0]?.Data;
    const data = JSON.parse(dataString);
    assert.equal(data?.Profile?.UserName, "Steve");
    assert.equal(data?.Profile?.DisplayName, "El Steverino");
})
