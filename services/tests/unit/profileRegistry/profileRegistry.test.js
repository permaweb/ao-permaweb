import { test } from 'node:test'
import * as assert from 'node:assert'
import { SendFactory } from '../../utils/aos.helper.js'
import { inspect } from 'node:util';
import fs from 'node:fs'
import path from 'node:path'

import {findMessageByTag, getTag, logSendResult} from "../../utils/message.js";
const registryLuaPath = path.resolve('../profiles/registry.lua');

const PROFILE_A_USERNAME = "Steve";
const PROFILE_B_USERNAME = "Bob";
const PROFILE_REGISTRY_ID = 'dWdBohXUJ22rfb8sSChdFh6oXJzbAtGe4tC6__52Zk4';
const REGISTRY_OWNER = "ADDRESS_R_CZLr2EkkwzIXP5A64QmtME6Bxa8bGmbzI";
const PROFILE_BOB_ID = "PROFILE_B_CZLr2EkkwzIXP5A64QmtME6Bxa8bGmbzI";
const STEVE_PROFILE_ID = "PROFILE_A_CZLr2EkkwzIXP5A64QmtME6Bxa8bGmbzI";
const STEVE_WALLET = "ADDRESS_A_CZLr2EkkwzIXP5A64QmtME6Bxa8bGmbzI";
const BOB_WALLET = "ADDRESS_B_CZLr2EkkwzIXP5A64QmtME6Bxa8bGmbzI";
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
test("should read all metadata", async () => {
    const result = await Send({ Target: PROFILE_REGISTRY_ID, Tags: { Action: "Read-Metadata"}})
    logSendResult(result, "Read-Metadata")
    assert.equal(getTag(result?.Messages[0], "Status"), "Success")
})
// /*
//     TODO: write a migration test: new lua, migration handler by owner only, supports same methods
//  */
// test("STEVE should create profile A in registry from old profile code", async () => {
//     // recieve profile data via send from profile
//     const inputData = { AuthorizedAddress: STEVE_WALLET, UserName: PROFILE_A_USERNAME, DateCreated: 125555, DateUpdated: 125555 }
//     const result = await Send({ Target: PROFILE_REGISTRY_ID, From: STEVE_PROFILE_ID, Owner: STEVE_PROFILE_ID, Action: "Update-Profile", Data: JSON.stringify(inputData) })
//     logSendResult(result, 'Create-Profile-A');
//     assert.equal(getTag(result?.Messages[0], "Status"), "Success")
//     const readData = { ProfileId: STEVE_PROFILE_ID }
//     const readResult = await Send({Target: PROFILE_REGISTRY_ID, Action: "Read-Profile", Data: JSON.stringify(readData)})
//     logSendResult(readResult, "Read-Profile")
//     assert.equal(getTag(readResult?.Messages[0], "Status"), "Success")
//
//     const authResult = await Send({Action: "Read-Auth"})
//     logSendResult(authResult, "Read-Auth")
//     assert.equal(getTag(authResult?.Messages[0], "Status"), "Success")
// })
//
// test("BOB should create profile in registry v001", async () => {
//     // read the assigned create/update profile methods from user spawn
//     const inputData = { UserName: PROFILE_B_USERNAME, DateCreated: 125555, DateUpdated: 125555 }
//     const result = await Send({ Target: PROFILE_BOB_ID, From: BOB_WALLET, Owner: BOB_WALLET, Action: "Create-Profile", Data: JSON.stringify(inputData) })
//     logSendResult(result, 'Create-Profile-B');
//     assert.equal(getTag(result?.Messages[0], "Status"), "Success")
//     const readData = { ProfileId: PROFILE_BOB_ID }
//     const readResult = await Send({Action: "Read-Profile", Data: JSON.stringify(readData)})
//     logSendResult(readResult, "Read-Profile")
//     assert.equal(getTag(readResult?.Messages[0], "Status"), "Success")
// })
//
// test("should return no records if profile does not exist", async () => {
//     const inputData = { ProfileId: "PROFILE_C_CZLr2EkkwzIXP5A64QmtME6Bxa8GmbzI" }
//     const result = await Send({Action: "Read-Profile", Data: JSON.stringify(inputData)})
//     logSendResult(result, "Read-Profile")
//     assert.equal(getTag(result?.Messages[0], "Status"), "Error")
// })
//
// test("should update profile in registry from old profile code", async () => {
//     const inputData = { DisplayName: "Who", DateUpdated: 126666, DateCreated: 125555}
//     const result = await Send({ Target: PROFILE_REGISTRY_ID, From: STEVE_PROFILE_ID, Owner: STEVE_PROFILE_ID, AuthorizedAddress: STEVE_WALLET, Action: "Update-Profile", Data: JSON.stringify(inputData) })
//     logSendResult(result, 'Update-Profile-1');
//     assert.equal(getTag(result?.Messages[0], "Status"), "Success")
// })
//
// test("should update profile in registry v001", async () => {
//     const inputData = { DisplayName: "Who Else", DateUpdated: 126666 }
//     const result = await Send({ From: STEVE_WALLET, Owner: STEVE_WALLET, Target: STEVE_PROFILE_ID,  Action: "Update-Profile", Data: JSON.stringify(inputData) })
//     logSendResult(result, 'Update-Profile-1');
//     assert.equal(getTag(result?.Messages[0], "Status"), "Success")
// })
//
// test("should read all metadata", async () => {
//     const result = await Send({Action: "Read-Metadata"})
//     logSendResult(result, "Read-Metadata")
//     assert.equal(getTag(result?.Messages[0], "Status"), "Success")
// })
//
// test('should get metadata for profile ids', async () => {
//     const inputData = { ProfileIds: [STEVE_PROFILE_ID] }
//     const result = await Send({ Action: "Get-Metadata-By-ProfileIds", Data: JSON.stringify(inputData) }, )
//     // logSendResult(result, "Get-Metadata-By-ProfileIds")
//     const resultMessages = findMessageByTag(result.Messages, "Status");
//     assert.equal(getTag(resultMessages[0], "Status"), "Success")
//     const data = resultMessages[0].Data;
//     assert.equal(data.length > 0, true)
// })
//
// test("should read auth table", async () => {
//     const result = await Send({Action: "Read-Auth"})
//     logSendResult(result, "Read-Auth")
//     assert.equal(getTag(result?.Messages[0], "Status"), "Success")
// })
//
// test('should add, update, remove role', async () => {
//     const unauthFailAddResult = await Send({
//         Id: "1114",
//         From: BOB_WALLET,
//         Owner: BOB_WALLET,
//         Target: STEVE_PROFILE_ID,
//         Action: "Update-Role",
//         Data: JSON.stringify({Role: "Admin", Id: BOB_WALLET, Op: "Add"})
//     })
//     logSendResult(unauthFailAddResult, "Unauth-Fail-Role")
//     const statusMessages = findMessageByTag(unauthFailAddResult.Messages, "Status");
//     assert.equal(getTag(statusMessages[0], "Status"), "Error")
//
//     const roleAddResult = await Send({
//         Id: "1114",
//         From: STEVE_WALLET,
//         Owner: STEVE_WALLET,
//         Target: STEVE_PROFILE_ID,
//         Action: "Update-Role",
//         Data: JSON.stringify({Role: "Admin", Id: BOB_WALLET, Op: "Add"})
//     })
//     logSendResult(roleAddResult, "Add-Role")
//     // read role
//     const roleReadResultAdd = await Send({Action: "Read-Auth"})
//     logSendResult(roleReadResultAdd, "Read-Auth-After-Add")
//     assert.equal(getTag(roleReadResultAdd?.Messages[0], "Status"), "Success")
//     assert.equal(
//         JSON.parse(roleReadResultAdd.Messages[0].Data).find(r => r.CallerAddress === BOB_WALLET && r.ProfileId === STEVE_PROFILE_ID)['Role'],
//         "Admin"
//     )
//
//     const roleUpdateResult = await Send({
//         Id: "1114",
//         From: STEVE_WALLET,
//         Owner: STEVE_WALLET,
//         Target: STEVE_PROFILE_ID,
//         Action: "Update-Role",
//         Data: JSON.stringify({Role: "Contributor", Id: BOB_WALLET, Op: "Update"})
//     })
//     logSendResult(roleUpdateResult, "Update-Role")
//     // read role
//     const roleReadResultUpdate = await Send({Action: "Read-Auth"})
//     logSendResult(roleReadResultUpdate, "Read-Auth-After-Update")
//     assert.equal(getTag(roleReadResultUpdate?.Messages[0], "Status"), "Success")
//     assert.equal(
//         JSON.parse(roleReadResultUpdate.Messages[0].Data).find(r => r.CallerAddress === BOB_WALLET && r.ProfileId === STEVE_PROFILE_ID)['Role'],
//         "Contributor"
//     )
//
//     const roleDeleteResult = await Send({
//         Id: "1114",
//         From: STEVE_WALLET,
//         Owner: STEVE_WALLET,
//         Target: STEVE_PROFILE_ID,
//         Action: "Update-Role",
//         Data: JSON.stringify({Role: "Contributor", Id: BOB_WALLET, Op: "Delete"})
//     })
//     // logSendResult(roleDeleteResult, "Delete-Role")
//     // read role
//     const roleReadResultDelete = await Send({Action: "Read-Auth"})
//     logSendResult(roleReadResultDelete, "Read-Auth-After-Delete")
//     assert.equal(getTag(roleReadResultDelete?.Messages[0], "Status"), "Success")
//     assert.equal(
//         JSON.parse(roleReadResultDelete.Messages[0].Data).find(r => r.CallerAddress === BOB_WALLET && r.ProfileId === STEVE_PROFILE_ID),
//         undefined
//     )
// })
//
// // TODO add/remove from tables: languages, following, followed, topic-tags, locations, external_links, external_wallets
