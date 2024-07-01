# AO Profile

## ⚠⚠ WARNING ⚠ ⚠ 

This concept is in very early development and experimentation phase, and as such, will be buggy and most likely evolve in ways that may not be supported without losing data or having to re-create profiles. The current version includes some base profile metadata, can store assets, and supports single wallet as an owner. 

## Overview

[AO Profile](profile.lua) is a protocol built on the permaweb designed to allow users to create an identity, interact with applications built on AO, operate as a smart wallet, and serve as a personal process. Instead of a wallet address owning assets or having uploads, the profile will encompass this information. This means that certain actions require first interacting with the profile, validating that a wallet has authorization to carry it out, and finally the profile will send a message onward to other processes, which can then validate its request. 

A separate [Profile Registry aggregation process](registry.lua) is used to keep track of the new profile processes that are created, as well as any updates. This registry process will serve as an all encompassing database that can be queried for profile data. You can read profile metadata directly from the AO Profile process, or from the registry. 

## Profile Metadata
| **Field**     | **Description**             |
|---------------|-----------------------------|
| **DisplayName** | Profile display name      |
| **Username**    | Profile username          |
| **Bio**         | Profile description       |
| **Avatar**      | Profile Avatar TXID       |
| **Banner**      | Profile Banner TXID       |

Sample output from AO: ```"Data": "{\"Assets\":[],\"Profile\":{\"DisplayName\":\"tom-ao-profile-1\",\"Bio\":\"hello ao\",\"Avatar\":\"LzBub_drZ3xOE2mn_HW5xDNDWJ2pe3zN6NUQkMc3-C0\",\"Banner\":\"hAjf58dmqS-mkRTwPvmVLRZBPC-oZK4H-uDAceZoSPk\",\"Username\":\"tom-ao\"}}"```

## Profile Handlers
| **Handler**           | **Description**                                                                        |
|-----------------------|----------------------------------------------------------------------------------------|
| **Info**              | Dry-runable, returns profile metadata and assets as JSON.                             |
| **Update-Profile**    | Accepts JSON in the data field to update profile metadata.                            |
| **Transfer**          | Allows a profile to transfer some quantity of an asset they own to another profile or address. |
| **Debit-Notice**      | Supports interactions with UCM, decreases asset count if marked for sale.             |
| **Credit-Notice**     | Supports interactions with UCM, decreases asset count if marked for sale.             |
| **Add-Uploaded-Asset**| Allows an AO Atomic Asset to be linked to a profile.  

## Profile Registry Handlers 

| **Handler**                | **Description**                                                                                                      |
|----------------------------|----------------------------------------------------------------------------------------------------------------------|
| **Prepare-Database**       | Prepares the database schema by creating tables `ao_profile_metadata` and `ao_profile_authorization` if they don't exist. |
| **Get-Metadata-By-ProfileIds** | Retrieves metadata for profiles based on the provided profile IDs. Returns metadata as JSON or sends an error message if input data is invalid. |
| **Get-Profiles-By-Address**| Retrieves associated profiles for a given wallet address from `ao_profile_authorization`. Returns profiles as JSON or an error if none are found. |
| **Update-Profile**         | Updates a profile's metadata or adds it if it doesn't exist. Links an authorized address if needed.                  |
| **Read-Metadata**          | (Debug) Prints all rows from the `ao_profile_metadata` table.                                                               |
| **Read-Authorization**     | (Debug) Prints all rows from the `ao_profile_authorization` table.                                                          |

## Creating a Profile process and setting metadata

AO Profile functions by spawning a new personal process for a user if they decide to make one. The wallet that spawns the profile is authorized to make changes to it. Prior to creating a process, you should check if the [wallet address already has any profiles](#by-wallet-address).

Here is an overview of actions that take place to create an AO Profile process and update the metadata:

1. A new process is spawned with the base AO module. ([Sample Code](https://github.com/permaweb/ao-bazar/blob/main/src/components/organisms/ProfileManage/ProfileManage.tsx#L156))
2. A Gateway GraphQL query is executed for the spawned transaction ID in order to find the resulting process ID. ([Sample Code](https://github.com/permaweb/ao-bazar/blob/main/src/components/organisms/ProfileManage/ProfileManage.tsx#L168))
3. The [profile.lua](profile.lua) source code is then loaded from Arweave, and sent to the process as an eval message. This loads the state and handlers into the process. ([Sample Code](https://github.com/permaweb/ao-bazar/blob/6ac0e3df68386535bb497445f6209b985845977b/src/components/organisms/ProfileManage/ProfileManage.tsx#L191))
4. Client collects Profile metadata in the [data object](https://github.com/permaweb/ao-bazar/blob/6ac0e3df68386535bb497445f6209b985845977b/src/components/organisms/ProfileManage/ProfileManage.tsx#L70), and [uploads a banner and cover image](https://github.com/permaweb/ao-bazar/blob/6ac0e3df68386535bb497445f6209b985845977b/src/components/organisms/ProfileManage/ProfileManage.tsx#L77). 
5. Finally, a message is sent to update the Profile metadata. ([Sample Code](https://github.com/permaweb/ao-bazar/blob/6ac0e3df68386535bb497445f6209b985845977b/src/components/organisms/ProfileManage/ProfileManage.tsx#L210)). 

## Fetching Profile metadata
### By Profile ID
If you have the Profile ID already, you can easily read the metadata directly from the Profile process via the `Info` handler. ([Sample Code](https://github.com/permaweb/ao-bazar/blob/6ac0e3df68386535bb497445f6209b985845977b/src/api/profiles.ts#L6))

### By Wallet Address 
If you have a wallet address, you can look up the profile(s) associated with it by interacting with the Profile Registry via the `Get-Profiles-By-Address` handler. ([Sample Code](https://github.com/permaweb/ao-bazar/blob/6ac0e3df68386535bb497445f6209b985845977b/src/api/profiles.ts#L40))

## Profile Registry process

The Profile Registry process collects and aggregates all profile metadata in a single database and its process ID is defined in all AO Profiles. Messages are sent from the Profiles to the Registry when any creations or edits to metadata occur, and can be trusted by the msg.From address which is the Profile ID. 

The overall process looks like:
1. A message is sent with an action of `Update-Profile` to the Profile process with the information that the creator provided. 
2. Once the Profile metadata is updated internally in the Profile Process, a new message is then sent to the Registry process to add or update the corresponding profile accordingly via its own `Update-Profile` handler. 
