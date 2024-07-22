import {test} from 'node:test'
import * as assert from 'node:assert'
import {SendFactory} from '../../../utils/aos.helper.js'
import fs from 'node:fs'
import {findMessageByTag, findMessageByTagValue, logSendResult} from "../../../utils/message.js";

const REGISTRY = 'dWdBohXUJ22rfb8sSChdFh6oXJzbAtGe4tC6__52Zk4';
const STEVE_PROFILE_ID = "PROFILE_A_CZLr2EkkwzIXP5A64QmtME6Bxa8bGmbzI";
const STEVE_WALLET = "ADDRESS_A_CZLr2EkkwzIXP5A64QmtME6Bxa8bGmbzI";
const BOB_WALLET = "ADDRESS_B_CZLr2EkkwzIXP5A64QmtME6Bxa8bGmbzI";
const {Send} = SendFactory({processId: STEVE_PROFILE_ID, moduleId: '5555', defaultOwner: STEVE_WALLET, defaultFrom: STEVE_WALLET});

function getTag(msg, tagName) {
    return msg?.Tags?.find(t => t.name === tagName)?.value ?? null;
}

test('load source profile', async () => {
    const code = fs.readFileSync('./profiles/profile.lua', 'utf-8')
    const result = await Send({
        Owner: STEVE_WALLET,
        From: STEVE_WALLET,
        ProfileVersion: '0.0.1',
        Action: "Eval",
        Data: code
    })
})
test("------------------------------P V001 BEGIN TEST------------------------------")

test('should fail to update if from is not owner', async () => {
    const updateResult = await Send({
        Id: "1111",
        ProfileVersion: '0.0.1',
        From: BOB_WALLET,
        Owner: BOB_WALLET,
        Action: "Update-Profile",
        Data: JSON.stringify({UserName: "Steve", DisplayName: "Steverino"})
    })
    logSendResult(updateResult, "Update-Profile--Fail")
    // const registryMessages = findMessageByTarget(updateResult.Messages, REGISTRY)
    const statusMessages = findMessageByTag(updateResult.Messages, "Status");
    assert.equal(getTag(statusMessages[0], "Status"), "Error")
})
test("Steve's profile initialized using msg.Data", async () => {
    const updateResult = await Send({
        Id: "1112",
        ProfileVersion: '0.0.1',
        Owner: STEVE_WALLET,
        From: STEVE_WALLET,
        Action: "Update-Profile",
        Data: JSON.stringify({UserName: "Steve", DisplayName: "Steverino"})
    })
    logSendResult(updateResult, "Update-Profile--Pass")
    const statusMessages = findMessageByTag(updateResult.Messages, "Status");
    assert.equal(getTag(statusMessages[0], "Status"), "Success")
    assert.equal(updateResult.Assignments[0].Message, STEVE_PROFILE_ID)
    const info = await Send({Action: "Info", ProfileVersion: '0.0.1'})
    const dataMessage = findMessageByTagValue(info.Messages, "Action", "Read-Success");
    const dataString = dataMessage[0]?.Data;
    const data = JSON.parse(dataString);
    assert.equal(data?.Profile?.UserName, "Steve");
    assert.equal(data?.Profile?.DisplayName, "Steverino");
})

test("Steve's profile updated using Tags", async () => {
    const updateResult = await Send({
        Id: "1113",
        Owner: STEVE_WALLET,
        From: STEVE_WALLET,
        ProfileVersion: '0.0.10',
        Action: "Update-Profile",
        DisplayName: "El Steverino"
    })
    logSendResult(updateResult, "Update-Profile")
    const statusMessages = findMessageByTag(updateResult.Messages, "Status");
    assert.equal(getTag(statusMessages[0], "Status"), "Success")
    assert.equal(updateResult.Assignments[0].Message, "1113")
    const info = await Send({Action: "Info", ProfileVersion: '0.0.1'})
    // logSendResult(info, "Info")
    const dataMessage = findMessageByTagValue(info.Messages, "Action", "Read-Success");
    const dataString = dataMessage[0]?.Data;
    const data = JSON.parse(dataString);
    assert.equal(data?.Profile?.UserName, "Steve");
    assert.equal(data?.Profile?.DisplayName, "El Steverino");
})

test('should add, update, remove role', async () => {
    const unauthFailAddResult = await Send({
        Id: "1114",
        From: BOB_WALLET,
        ProfileVersion: '0.0.1',
        Action: "Update-Role",
        Data: JSON.stringify({Role: "Admin", Id: BOB_WALLET, Op: "Add"})
    })
    const statusMessages = findMessageByTag(unauthFailAddResult.Messages, "Status");
    assert.equal(getTag(statusMessages[0], "Status"), "Error")
    const unauthFailInfo = await Send({
        Action: "Info",
        ProfileVersion: '0.0.1',
        Owner: STEVE_WALLET,
        From: STEVE_WALLET,
    })
    assert.equal(JSON.parse(unauthFailInfo.Messages[0].Data)["Roles"].length, 1)

    const roleAddResult = await Send({
        Id: "1114",
        Owner: STEVE_WALLET,
        From: STEVE_WALLET,
        ProfileVersion: '0.0.1',
        Action: "Update-Role",
        Data: JSON.stringify({Role: "Admin", Id: BOB_WALLET, Op: "Add"})
    })
    // read role
    const info = await Send({Action: "Info", ProfileVersion: '0.0.1'})
    logSendResult(info, "Info1")
    assert.equal(
        JSON.parse(info.Messages[0].Data)["Roles"].find(r => r.Role === "Admin")['AddressOrProfile'],
        BOB_WALLET
    )
    const updateResult = await Send({
        Id: "1114",
        Owner: STEVE_WALLET,
        From: STEVE_WALLET,
        ProfileVersion: '0.0.1',
        Action: "Update-Role",
        Data: JSON.stringify({Role: "Contributor", Id: BOB_WALLET, Op: "Update"})
    })
    // logSendResult(updateResult, "Result2")
    const updateinfo = await Send({Action: "Info", ProfileVersion: '0.0.1'})
    logSendResult(updateinfo, "Info2")
    assert.equal(
        JSON.parse(updateinfo.Messages[0].Data)["Roles"].find(r => r.Role === "Contributor")['AddressOrProfile'],
        BOB_WALLET
    )
    const roleRemoveResult = await Send({
        Id: "1114",
        Owner: STEVE_WALLET,
        From: STEVE_WALLET,
        ProfileVersion: '0.0.1',
        Action: "Update-Role",
        Data: JSON.stringify({Id: BOB_WALLET, Op: "Delete"})
    })
    logSendResult(roleRemoveResult, "Info3 Rm")
    const removeInfo = await Send({Action: "Info", ProfileVersion: '0.0.1'})
    assert.equal(JSON.parse(removeInfo.Messages[0].Data)["Roles"].length, 1)
})

