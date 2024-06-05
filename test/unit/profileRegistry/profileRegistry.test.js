import { test } from 'node:test'
import * as assert from 'node:assert'
import { SendFactory } from '../../../utils/aos.helper.js'
import { inspect } from 'node:util';
import fs from 'node:fs'
import {getTag, logSendResult} from "../../../utils/message.js";

const Send = SendFactory();
const PROFILE_A_ID = 12345;
const PROFILE_A_USERNAME = "Steve";
const PROFILE_B_ID = 12346;
const PROFILE_B_USERNAME = "Bob";
const AUTHORIZED_ADDRESS_A = 87654;
const AUTHORIZED_ADDRESS_B = 76543;
test("load profileRegistry source", async () => {
    const code = fs.readFileSync('./src/registry.lua', 'utf-8')
    const result = await Send({ Action: "Eval", Data: code })
})

test("should prepare database", async () => {
    const preparedDb = await Send({Action: "Prepare-Database"})
})
/*
    TODO: write a migration test: new lua, migration handler by owner only, supports same methods
 */

test("should insert partial profile in registry", async () => {
    const inputData = { ProfileId: PROFILE_A_ID, UserName: PROFILE_A_USERNAME, DateCreated: 123456, AuthorizedCaller: { Address: AUTHORIZED_ADDRESS_A, Role: 'admin' } }
    const result = await Send({ Action: "Update-Profile", Data: JSON.stringify(inputData) })
    logSendResult(result, 'Update-Profile');
    assert.equal(getTag(result?.Messages[0], "Status"), "Success")
})

// test("should add delegated addresses to auth table", async () => {
//     // Update-Profile data Data = [ { Address: x, Role: y } ]
// })

test("should count 1 profile", async () => {
    const result = await Send({Action: "Count-Profiles"})
    logSendResult(result, "Count-Profiles")
    assert.equal(getTag(result?.Messages[0], "Status"), "Success")
})

test("should read all metadata", async () => {
    const result = await Send({Action: "Read-Metadata"})
    logSendResult(result, "Read-Metadata")
    assert.equal(getTag(result?.Messages[0], "Status"), "Success")
})

test("should insert another profile in registry using tags", async () => {
    const inputData = { AuthorizedCaller: { Address: AUTHORIZED_ADDRESS_A, Role: 'admin' }}
    const result = await Send({ Action: "Update-Profile",  ProfileId: PROFILE_B_ID, UserName: PROFILE_B_USERNAME, DateCreated: 125555, Data: JSON.stringify(inputData) })
    logSendResult(result, 'Update-Profile');
    assert.equal(getTag(result?.Messages[0], "Status"), "Success")
})

test("should count 2 profiles", async () => {
    const result = await Send({Action: "Count-Profiles"})
    logSendResult(result, "Count-Profiles")
    assert.equal(getTag(result?.Messages[0], "Status"), "Success")
})

test("should update profile 2 in registry", async () => {
    const inputData = { ProfileId: PROFILE_B_ID, DisplayName: 'The Dude', DateUpdated: 125888, AuthorizedCaller: { Address: AUTHORIZED_ADDRESS_B, Role: 'admin' }}
    const result = await Send({ Action: "Update-Profile", Data: JSON.stringify(inputData) })
    logSendResult(result, 'Update-Profile');
    assert.equal(getTag(result?.Messages[0], "Status"), "Success")
})

test("should read metadata again", async () => {
    const result = await Send({Action: "Read-Metadata"})
    logSendResult(result, "Read-Metadata")
    assert.equal(getTag(result?.Messages[0], "Status"), "Success")
})

test("should read first profile", async () => {
    const inputData = { ProfileId: PROFILE_A_ID }
    const result = await Send({Action: "Read-Profile", Data: JSON.stringify(inputData)})
    logSendResult(result, "Read-Profile")
    assert.equal(getTag(result?.Messages[0], "Status"), "Success")
})

test("should read auth table", async () => {
    const result = await Send({Action: "Read-Auth"})
    logSendResult(result, "Read-Auth")
    assert.equal(getTag(result?.Messages[0], "Status"), "Success")
})

// TODO add/remove from tables: languages, following, followed, topic-tags, locations, external_links, external_wallets
