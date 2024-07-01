# AO Collections

## Overview
[AO Collections](collection.lua) are designed to allow users to group atomic assets together.

## How it works
The creation of a collection happens with these steps:

1. The [collection process handlers](https://arweave.net/e15eooIt86VjB1IDRjOMedwmtmicGtKkNWSnz8GyV4k) are fetched from Arweave.
2. Collection fields are replaced with the values submitted by the user.
3. A new process is spawned, with the collection tags.
4. A message is sent to the newly created process with an action of 'Eval', which includes the process handlers.
5. A message is sent to a collection registry which contains information on all created collections.
