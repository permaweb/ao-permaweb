# AO Atomic Asset

## Overview

Atomic assets are unique digital items stored on Arweave. Unlike traditional NFTs, the asset data is uploaded together with a smart contract in a single transaction which is inseparable and does not rely on external components.

## How it works
AO atomic assets follow the token spec designed for exchangeable tokens which can be found [here](https://ao.arweave.dev/#/). The creation of an atomic asset happens with these steps:

1. The [asset process handlers](https://arweave.net/y9VgAlhHThl-ZiXvzkDzwC5DEjfPegD6VAotpP3WRbs) are fetched from Arweave
2. Asset fields are replaced with the values submitted by the user
3. A new process is spawned, with the tags and asset data included
4. A message is sent to the newly created process with an action of 'Eval', which includes the process handlers
5. A message is sent to the profile that created the asset in order to add the new asset to its Assets table
