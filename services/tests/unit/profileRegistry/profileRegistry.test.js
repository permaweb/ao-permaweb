import { test } from 'node:test'
import * as assert from 'node:assert'
import { SendFactory } from '../../../utils/aos.helper.js'
import { inspect } from 'node:util';
import fs from 'node:fs'
import {findMessageByTag, getTag, logSendResult} from "../../../utils/message.js";

const PROFILE_A_USERNAME = "Steve";
const PROFILE_B_USERNAME = "Bob";
const PROFILE_B_ID = "PROFILE_B_CZLr2EkkwzIXP5A64QmtME6Bxa8bGmbzI";
const PROFILE_A_ID = "PROFILE_A_CZLr2EkkwzIXP5A64QmtME6Bxa8bGmbzI";
const AUTHORIZED_ADDRESS_A = "ADDRESS_A_CZLr2EkkwzIXP5A64QmtME6Bxa8bGmbzI";
const AUTHORIZED_ADDRESS_B = "ADDRESS_B_CZLr2EkkwzIXP5A64QmtME6Bxa8bGmbzI";
const {Send} = SendFactory();
test("------------------------------BEGIN TEST------------------------------")
test("load profileRegistry source", async () => {
    try {
        const code = fs.readFileSync('./profiles/registry.lua', 'utf-8')
        const result = await Send({ Action: "Eval", Data: code })
    } catch (error) {
        console.log(error)
    }
})

test("should prepare database", async () => {
    const preparedDb = await Send({Action: "Prepare-Database"})
})
test("should read all metadata", async () => {
    const result = await Send({Action: "Read-Metadata"})
    // logSendResult(result, "Read-Metadata")
    assert.equal(getTag(result?.Messages[0], "Status"), "Success")
})
/*
    TODO: write a migration test: new lua, migration handler by owner only, supports same methods
 */
test("should create profile A in registry v000", async () => {
    // recieve profile data via send from profile
    const inputData = { AuthorizedAddress: AUTHORIZED_ADDRESS_A, UserName: PROFILE_A_USERNAME, DateCreated: 125555, DateUpdated: 125555 }
    const result = await Send({ From: PROFILE_A_ID, Action: "Create-Profile", Data: JSON.stringify(inputData) })
    // logSendResult(result, 'Create-Profile-A');
    assert.equal(getTag(result?.Messages[0], "Status"), "Success")
    const readData = { ProfileId: PROFILE_A_ID }
    const readResult = await Send({Action: "Read-Profile", Data: JSON.stringify(readData)})
    logSendResult(readResult, "Read-Profile")
    assert.equal(getTag(readResult?.Messages[0], "Status"), "Success")
})

test("should create profile in registry v001", async () => {
    // read the assigned create/update profile methods from user spawn
    const inputData = { UserName: PROFILE_B_USERNAME, DateCreated: 125555, DateUpdated: 125555 }
    const result = await Send({ Id: PROFILE_B_ID, From: AUTHORIZED_ADDRESS_B, Action: "Create-Profile", Data: JSON.stringify(inputData) })
    logSendResult(result, 'Create-Profile-B');
    assert.equal(getTag(result?.Messages[0], "Status"), "Success")
    const readData = { ProfileId: PROFILE_B_ID }
    const readResult = await Send({Action: "Read-Profile", Data: JSON.stringify(readData)})
    logSendResult(readResult, "Read-Profile")
    assert.equal(getTag(readResult?.Messages[0], "Status"), "Success")
})

test("should return no records if profile does not exist", async () => {
    const inputData = { ProfileId: "PROFILE_C_CZLr2EkkwzIXP5A64QmtME6Bxa8GmbzI" }
    const result = await Send({Action: "Read-Profile", Data: JSON.stringify(inputData)})
    logSendResult(result, "Read-Profile")
    assert.equal(getTag(result?.Messages[0], "Status"), "Error")
})

test("should read auth table", async () => {
    const result = await Send({Action: "Read-Auth"})
    logSendResult(result, "Read-Auth")
    assert.equal(getTag(result?.Messages[0], "Status"), "Success")
})

test("should update profile in registry v000", async () => {
    const inputData = { DisplayName: "Who", DateUpdated: 126666 }
    const result = await Send({ Target: PROFILE_A_ID, From: PROFILE_A_ID, AuthorizedAddress: AUTHORIZED_ADDRESS_A, Action: "Update-Profile", Data: JSON.stringify(inputData) })
    logSendResult(result, 'Update-Profile-1');
    assert.equal(getTag(result?.Messages[0], "Status"), "Success")
})

test("should update profile in registry v001", async () => {
    const inputData = { DisplayName: "Who Else", DateUpdated: 126666 }
    const result = await Send({ From: AUTHORIZED_ADDRESS_A, ProfileProcess: PROFILE_A_ID, Target: PROFILE_A_ID,  Action: "Update-Profile", Data: JSON.stringify(inputData) })
    logSendResult(result, 'Update-Profile-1');
    assert.equal(getTag(result?.Messages[0], "Status"), "Success")
})

test("should read all metadata", async () => {
    const result = await Send({Action: "Read-Metadata"})
    logSendResult(result, "Read-Metadata")
    assert.equal(getTag(result?.Messages[0], "Status"), "Success")
})

test('should get metadata for profile ids', async () => {
    const inputData = { ProfileIds: [PROFILE_A_ID] }
    const result = await Send({ Action: "Get-Metadata-By-ProfileIds", Data: JSON.stringify(inputData) }, )
    // logSendResult(result, "Get-Metadata-By-ProfileIds")
    const resultMessages = findMessageByTag(result.Messages, "Status");
    assert.equal(getTag(resultMessages[0], "Status"), "Success")
    const data = resultMessages[0].Data;
    assert.equal(data.length > 0, true)
})

test("should read auth table", async () => {
    const result = await Send({Action: "Read-Auth"})
    logSendResult(result, "Read-Auth")
    assert.equal(getTag(result?.Messages[0], "Status"), "Success")
})

test('should add, update, remove role', async () => {
    const unauthFailAddResult = await Send({
        Id: "1114",
        From: AUTHORIZED_ADDRESS_B,
        ProfileVersion: '0.0.1',
        ProfileProcess: PROFILE_A_ID,
        Action: "Update-Role",
        Data: JSON.stringify({Role: "Admin", Id: AUTHORIZED_ADDRESS_B, Op: "Add"})
    })
    logSendResult(unauthFailAddResult, "Unauth-Fail-Role")
    const statusMessages = findMessageByTag(unauthFailAddResult.Messages, "Status");
    assert.equal(getTag(statusMessages[0], "Status"), "Error")

    const roleAddResult = await Send({
        Id: "1114",
        From: AUTHORIZED_ADDRESS_A,
        ProfileVersion: '0.0.1',
        ProfileProcess: PROFILE_A_ID,
        Action: "Update-Role",
        Data: JSON.stringify({Role: "Admin", Id: AUTHORIZED_ADDRESS_B, Op: "Add"})
    })
    logSendResult(roleAddResult, "Add-Role")
    // read role
    const roleReadResultAdd = await Send({Action: "Read-Auth"})
    logSendResult(roleReadResultAdd, "Read-Auth-After-Add")
    assert.equal(getTag(roleReadResultAdd?.Messages[0], "Status"), "Success")
    assert.equal(
        JSON.parse(roleReadResultAdd.Messages[0].Data).find(r => r.CallerAddress === AUTHORIZED_ADDRESS_B && r.ProfileId === PROFILE_A_ID)['Role'],
        "Admin"
    )

    const roleUpdateResult = await Send({
        Id: "1114",
        From: AUTHORIZED_ADDRESS_A,
        ProfileVersion: '0.0.1',
        ProfileProcess: PROFILE_A_ID,
        Action: "Update-Role",
        Data: JSON.stringify({Role: "Contributor", Id: AUTHORIZED_ADDRESS_B, Op: "Update"})
    })
    logSendResult(roleUpdateResult, "Update-Role")
    // read role
    const roleReadResultUpdate = await Send({Action: "Read-Auth"})
    logSendResult(roleReadResultUpdate, "Read-Auth-After-Update")
    assert.equal(getTag(roleReadResultUpdate?.Messages[0], "Status"), "Success")
    assert.equal(
        JSON.parse(roleReadResultUpdate.Messages[0].Data).find(r => r.CallerAddress === AUTHORIZED_ADDRESS_B && r.ProfileId === PROFILE_A_ID)['Role'],
        "Contributor"
    )

    const roleDeleteResult = await Send({
        Id: "1114",
        From: AUTHORIZED_ADDRESS_A,
        ProfileVersion: '0.0.1',
        ProfileProcess: PROFILE_A_ID,
        Action: "Update-Role",
        Data: JSON.stringify({Role: "Contributor", Id: AUTHORIZED_ADDRESS_B, Op: "Delete"})
    })
    // logSendResult(roleDeleteResult, "Delete-Role")
    // read role
    const roleReadResultDelete = await Send({Action: "Read-Auth"})
    logSendResult(roleReadResultDelete, "Read-Auth-After-Delete")
    assert.equal(getTag(roleReadResultDelete?.Messages[0], "Status"), "Success")
    assert.equal(
        JSON.parse(roleReadResultDelete.Messages[0].Data).find(r => r.CallerAddress === AUTHORIZED_ADDRESS_B && r.ProfileId === PROFILE_A_ID),
        undefined
    )
})

// test("should add delegated addresses to auth table", async () => {
//     // Update-Profile data Data = [ { Address: x, Role: y } ]
// })

// test("should count 1 profile", async () => {
//     const result = await Send({Action: "Count-Profiles"})
//     logSendResult(result, "Count-Profiles")
//     assert.equal(getTag(result?.Messages[0], "Status"), "Success")
// })



//
// test("should insert another profile in registry using tags", async () => {
//     const result = await Send({ From: PROFILE_B_ID, Action: "Update-Profile",  ProfileId: PROFILE_B_ID, UserName: PROFILE_B_USERNAME, DateCreated: 125555, Data: JSON.stringify(inputData) })
//     logSendResult(result, 'Update-Profile');
//     assert.equal(getTag(result?.Messages[0], "Status"), "Success")
// })
//
// test("should count 2 profiles", async () => {
//     const result = await Send({Action: "Count-Profiles"})
//     logSendResult(result, "Count-Profiles")
//     assert.equal(getTag(result?.Messages[0], "Status"), "Success")
// })
//
// test("should update profile 2 in registry", async () => {
//     const inputData = { ProfileId: PROFILE_B_ID, DisplayName: 'The Dude', DateUpdated: 125888, AuthorizedCaller: { Address: AUTHORIZED_ADDRESS_B, Role: 'admin' }}
//     const result = await Send({ Action: "Update-Profile", Data: JSON.stringify(inputData) })
//     logSendResult(result, 'Update-Profile');
//     assert.equal(getTag(result?.Messages[0], "Status"), "Success")
// })
//
// test("should read metadata again", async () => {
//     const result = await Send({Action: "Read-Metadata"})
//     logSendResult(result, "Read-Metadata")
//     assert.equal(getTag(result?.Messages[0], "Status"), "Success")
// })
//
// test("should read first profile", async () => {
//     const inputData = { ProfileId: PROFILE_A_ID }
//     const result = await Send({Action: "Read-Profile", Data: JSON.stringify(inputData)})
//     logSendResult(result, "Read-Profile")
//     assert.equal(getTag(result?.Messages[0], "Status"), "Success")
// })
//


// TODO add/remove from tables: languages, following, followed, topic-tags, locations, external_links, external_wallets
