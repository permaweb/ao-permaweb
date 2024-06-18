import { test } from 'node:test'
import * as assert from 'node:assert'
import { SendFactory } from '../../utils/aos.helper.js'
import { inspect } from 'node:util';
import fs from 'node:fs'
import {findMessageByTag, getTag, logSendResult} from "../../utils/message.js";
import {findMessageByTagValue} from "../../utils/message.js";

const PROFILE_A_ID = "12345";
const PROFILE_A_USERNAME = "Steve";
const PROFILE_B_ID = "12346";
const PROFILE_B_USERNAME = "Bob";
const AUTHORIZED_ADDRESS_A = "ADDRESS_A";
const AUTHORIZED_ADDRESS_B = "ADDRESS_B";
const ProfileProcess = SendFactory( { processId: PROFILE_A_ID, moduleId: '7777'});
const SendProfile = ProfileProcess.Send;
const RegistryProcess = SendFactory({ processId: '6666', moduleId: '5555'});
const SendRegistry = RegistryProcess.Send;

test("------------------------------BEGIN TEST------------------------------")
test("load profileRegistry source", async () => {
    try {
        const code = fs.readFileSync('src/ao-profile/registry.lua', 'utf-8')
        const result = await SendRegistry({ Owner: AUTHORIZED_ADDRESS_A, From: AUTHORIZED_ADDRESS_A, Action: "Eval", Data: code })
    } catch (error) {
        console.log(error)
    }
})

test('load source profile', async () => {
    const code = fs.readFileSync('./src/ao-profile/profile.lua', 'utf-8')
    const result = await SendProfile({ Owner: AUTHORIZED_ADDRESS_A, From: AUTHORIZED_ADDRESS_A, Action: "Eval", Data: code })
})

test("should prepare database", async () => {
    const preparedDb = await SendRegistry({From: AUTHORIZED_ADDRESS_A, Action: "Prepare-Database"})
})

test('should insert', async () => {
    const updateResult = await SendProfile({ Id: "1112", From: AUTHORIZED_ADDRESS_A, Action: "Update-Profile", Data: JSON.stringify({ UserName: "Steve", DisplayName: "Steverino" }) })
    logSendResult(updateResult, "Update-Profile--Pass")
    const statusMessages = findMessageByTag(updateResult.Messages, "Status");
    assert.equal(getTag(statusMessages[0], "Status"), "Success")

    const createMessages = findMessageByTagValue(updateResult.Messages, "Action", "Create-Profile");
    console.log('data', JSON.parse(createMessages[0].Data))
    const newMessage = { Id: "1114", From:  PROFILE_A_ID, Action: "Create-Profile", Data: JSON.stringify(JSON.parse(createMessages[0].Data)) }
    const registryResult = await SendRegistry(newMessage)
    logSendResult(registryResult, "Update-Profile--Create")
})

test('should update and assign', async () => {
    const message = { Id: "1116", From: AUTHORIZED_ADDRESS_A, Action: "Update-Profile", DisplayName: "El Steverino" }
    const updateResult = await SendProfile(message)
    logSendResult(updateResult, "Update-Profile")
    const statusMessages = findMessageByTag(updateResult.Messages, "Status");
    assert.equal(getTag(statusMessages[0], "Status"), "Success")
    assert.equal(updateResult.Assignments[0].Message, message.Id)
    const registryResult = await SendRegistry({ Action: "Read-Profile", Data: JSON.stringify({ ProfileId: message.Id }) })
})
