import {test} from 'node:test'
import * as assert from 'node:assert'
import {SendFactory} from '../../../utils/aos.helper.js'
import fs from 'node:fs'
import {findMessageByTag, findMessageByTagValue, logSendResult} from "../../../utils/message.js";

const REGISTRY = 'dWdBohXUJ22rfb8sSChdFh6oXJzbAtGe4tC6__52Zk4';
const STEVE_PROFILE_ID = "PROFILE_A_CZLr2EkkwzIXP5A64QmtME6Bxa8bGmbzI";
const STEVE_WALLET = "ADDRESS_A_CZLr2EkkwzIXP5A64QmtME6Bxa8bGmbzI";
const BOB_WALLET = "ADDRESS_B_CZLr2EkkwzIXP5A64QmtME6Bxa8bGmbzI";
const RANDOM_COLLECTION = "oSFHRKZtszop4Vu1S7Wv1La41vgbcvt1QUxHU_zDN_U";
const {Send} = SendFactory({processId: STEVE_PROFILE_ID, moduleId: '5555', defaultOwner: STEVE_WALLET, defaultFrom: STEVE_WALLET});

function getTag(msg, tagName) {
    return msg?.Tags?.find(t => t.name === tagName)?.value ?? null;
}

test('load source profile', async () => {
    const code = fs.readFileSync('./profiles/profile.lua', 'utf-8')
    const result = await Send({
        Owner: STEVE_WALLET,
        From: STEVE_WALLET,
        Target: STEVE_PROFILE_ID,
        Action: "Eval",
        Data: code
    })
    logSendResult(result, "Load-Source")
})
test("------------------------------P V001 BEGIN TEST------------------------------")

test('should fail to update if from is not owner', async () => {
    const updateResult = await Send({
        Id: "1111",
        From: BOB_WALLET,
        Owner: BOB_WALLET,
        Target: STEVE_PROFILE_ID,
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
        Owner: STEVE_WALLET,
        From: STEVE_WALLET,
        Target: STEVE_PROFILE_ID,
        Tags: { Action: "Update-Profile" },
        Data: JSON.stringify({UserName: "Steve", DisplayName: "Steverino"})
    })
    logSendResult(updateResult, "Update-Profile--Pass")
    const statusMessages = findMessageByTag(updateResult.Messages, "Status");
    assert.equal(getTag(statusMessages[0], "Status"), "Success")
    assert.equal(updateResult.Assignments[0].Message, STEVE_PROFILE_ID)
    const info = await Send({Target: STEVE_PROFILE_ID, Action: "Info"})
    const dataMessage = findMessageByTagValue(info.Messages, "Action", "Read-Success");
    const dataString = dataMessage[0]?.Data;
    let data = {}
    if (dataString) {
        data = JSON.parse(dataString);
    }
    assert.equal(data?.Profile?.UserName, "Steve");
    assert.equal(data?.Profile?.DisplayName, "Steverino");
})

test("Steve's profile updated using Tags", async () => {
    const updateResult = await Send({
        Id: "1113",
        Owner: STEVE_WALLET,
        From: STEVE_WALLET,
        Target: STEVE_PROFILE_ID,
        Action: "Update-Profile",
        Tags: { "DisplayName": "El Steverino" },
    })
    logSendResult(updateResult, "Update-Profile")
    const statusMessages = findMessageByTag(updateResult.Messages, "Status");
    assert.equal(getTag(statusMessages[0], "Status"), "Success")
    assert.equal(updateResult.Assignments[0].Message, "1113")
    const info = await Send({Target: STEVE_PROFILE_ID, Action: "Info"})
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
        Owner: BOB_WALLET,
        Target: STEVE_PROFILE_ID,
        Action: "Update-Role",
        Data: JSON.stringify({Role: "Admin", Id: BOB_WALLET, Op: "Add"})
    })
    const statusMessages = findMessageByTag(unauthFailAddResult.Messages, "Status");
    assert.equal(getTag(statusMessages[0], "Status"), "Error")
    const unauthFailInfo = await Send({
        Action: "Info",
        Owner: STEVE_WALLET,
        From: STEVE_WALLET,
        Target: STEVE_PROFILE_ID
    })
    assert.equal(JSON.parse(unauthFailInfo.Messages[0].Data)["Roles"].length, 1)

    const roleAddResult = await Send({
        Id: "1114",
        Owner: STEVE_WALLET,
        From: STEVE_WALLET,
        Target: STEVE_PROFILE_ID,
        Action: "Update-Role",
        Data: JSON.stringify({Role: "Admin", Id: BOB_WALLET, Op: "Add"})
    })

    const roleAddInfo = await Send({        Owner: STEVE_WALLET,
        From: STEVE_WALLET, Action: "Info"})
    logSendResult(roleAddInfo, "Info1")
    assert.equal(
        JSON.parse(roleAddInfo.Messages[0].Data)["Roles"].find(r => r.Role === "Admin")['Id'],
        BOB_WALLET
    )
    const updateResult = await Send({
        Id: "1114",
        Owner: STEVE_WALLET,
        From: STEVE_WALLET,
        Target: STEVE_PROFILE_ID,
        Action: "Update-Role",
        Data: JSON.stringify({Role: "Contributor", Id: BOB_WALLET, Op: "Update"})
    })
    // logSendResult(updateResult, "Result2")
    const roleUpdateInfo = await Send({Action: "Info", ProfileVersion: '0.0.1'})
    logSendResult(roleUpdateInfo, "Info2")
    assert.equal(
        JSON.parse(roleUpdateInfo.Messages[0].Data)["Roles"].find(r => r.Role === "Contributor")['Id'],
        BOB_WALLET
    )
    const roleRemoveResult = await Send({
        Id: "1114",
        Owner: STEVE_WALLET,
        From: STEVE_WALLET,
        Target: STEVE_PROFILE_ID,
        Action: "Update-Role",
        Data: JSON.stringify({Id: BOB_WALLET, Op: "Delete"})
    })
    logSendResult(roleRemoveResult, "Info3 Rm")
    const roleRemoveInfo = await Send({Action: "Info", ProfileVersion: '0.0.1'})
    assert.equal(JSON.parse(roleRemoveInfo.Messages[0].Data)["Roles"].length, 1)

    const roleAddResultTags = await Send({
        Id: "1114",
        Owner: STEVE_WALLET,
        From: STEVE_WALLET,
        Target: STEVE_PROFILE_ID,
        Tags: { Role: "Admin",
            Id: BOB_WALLET,
            Op: "Add" },
        Action: "Update-Role",
    })

    const roleAddTagsInfo = await Send({Action: "Info"})
    // logSendResult(roleAddTagsInfo, "Info1 Add Role")
    assert.equal(
        JSON.parse(roleAddTagsInfo.Messages[0].Data)["Roles"].find(r => r.Role === "Admin")['Id'],
        BOB_WALLET
    )

    // update using tags
    const roleUpdateResultTags = await Send({
        Id: "1114",
        Owner: STEVE_WALLET,
        From: STEVE_WALLET,
        Target: STEVE_PROFILE_ID,
        Action: "Update-Role",
        Tags: {
            Role: "Contributor",
            Id: BOB_WALLET,
            Op: "Update"
        }
    })
    // logSendResult(updateResult, "Result2")
    const roleUpdateTagsInfo = await Send({Action: "Info"})
    // logSendResult(roleUpdateTagsInfo, "Info2 Update Role")
    assert.equal(
        JSON.parse(roleUpdateTagsInfo.Messages[0].Data)["Roles"].find(r => r.Role === "Contributor")['Id'],
        BOB_WALLET
    )

    const roleDeleteResultTags = await Send({
        Id: "1114",
        Owner: STEVE_WALLET,
        From: STEVE_WALLET,
        Target: STEVE_PROFILE_ID,
        Action: "Update-Role",
        Tags: {
            Id: BOB_WALLET,
            Op: "Delete"
        }

    })
    // logSendResult(roleRemoveResult, "Info3 Delete")
    const roleRemoveTagsInfo = await Send({Action: "Info"})
    assert.equal(JSON.parse(roleRemoveTagsInfo.Messages[0].Data)["Roles"].length, 1)
})

// -- needs to be fixed to include Creator tag / assigns
// test('add collection', async () => {
//     const collectionResult = await Send({
//         Id: "1111",
//         Owner: STEVE_WALLET,
//         From: STEVE_WALLET,
//         Target: RANDOM_COLLECTION,
//         Action: "Add-Collection",
//         Data: JSON.stringify({ Id: RANDOM_COLLECTION, Name: "A Collection"})
//     })
//     logSendResult(collectionResult, "Collection-Result")
//
// })
