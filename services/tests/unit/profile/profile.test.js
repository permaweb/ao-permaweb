import { test } from 'node:test'
import * as assert from 'node:assert'
import { SendFactory } from '../../../utils/aos.helper.js'
import fs from 'node:fs'
import {findMessageByTag, findMessageByTagValue, logSendResult} from "../../../utils/message.js";

const REGISTRY = 'dWdBohXUJ22rfb8sSChdFh6oXJzbAtGe4tC6__52Zk4';
const PROFILE_A_ID = "PROFILE_A_ID";
const AUTHORIZED_ADDRESS_A = "ADDRESS_A";
const AUTHORIZED_ADDRESS_B = "ADDRESS_B";
const {Send} = SendFactory({ processId: PROFILE_A_ID, moduleId: '5555'});
function getTag(msg, tagName) {
    return msg?.Tags?.find(t => t.name === tagName)?.value ?? null;
}

test('load source profile', async () => {
    const code = fs.readFileSync('./src/ao-profile/profile.lua', 'utf-8')
    const result = await Send({ Owner: AUTHORIZED_ADDRESS_A, From: AUTHORIZED_ADDRESS_A, ProfileVersion: '0.0.1', Action: "Eval", Data: code })
})
test("------------------------------P V001 BEGIN TEST------------------------------")

test('should fail to update if from is not owner', async () => {
    const updateResult = await Send({ Id: "1111", ProfileVersion: '0.0.1', From: AUTHORIZED_ADDRESS_B, Action: "Update-Profile", Data: JSON.stringify({ UserName: "Steve", DisplayName: "Steverino" }) })
    logSendResult(updateResult, "Update-Profile--Fail")
    // const registryMessages = findMessageByTarget(updateResult.Messages, REGISTRY)
    const statusMessages = findMessageByTag(updateResult.Messages, "Status");
    assert.equal(getTag(statusMessages[0], "Status"), "Error")
})
test('should create initial metadata with data, create tx message to registry', async () => {
    const updateResult = await Send({ Id: "1112", ProfileVersion: '0.0.1', From: AUTHORIZED_ADDRESS_A, Action: "Update-Profile", Data: JSON.stringify({ UserName: "Steve", DisplayName: "Steverino" }) })
    logSendResult(updateResult, "Update-Profile--Pass")
    const statusMessages = findMessageByTag(updateResult.Messages, "Status");
    assert.equal(getTag(statusMessages[0], "Status"), "Success")
    assert.equal(updateResult.Assignments[0].Message, PROFILE_A_ID)
})

test('should update with tags', async () => {
    const updateResult = await Send({ Id: "1113", From: AUTHORIZED_ADDRESS_A, ProfileVersion: '0.0.10', Action: "Update-Profile", DisplayName: "El Steverino" })
    logSendResult(updateResult, "Update-Profile")
    const statusMessages = findMessageByTag(updateResult.Messages, "Status");
    assert.equal(getTag(statusMessages[0], "Status"), "Success")
    assert.equal(updateResult.Assignments[0].Message, "1113")
})

test('should get info', async () => {
    const info = await Send({ Action: "Info", ProfileVersion: '0.0.1' })
    logSendResult(info, "Info")
    const dataMessage = findMessageByTagValue(info.Messages, "Action", "Read-Success");
    const dataString = dataMessage[0]?.Data;
    const data = JSON.parse(dataString);
    assert.equal(data?.Profile?.UserName, "Steve");
    assert.equal(data?.Profile?.DisplayName, "El Steverino");
})
