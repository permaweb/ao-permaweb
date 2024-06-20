/*
Install wallet.json
use aoconnect
publish any necessary source files using irys?
connect to processes
send action messages
check inbox for results
assert results
 */

import { connect } from "@permaweb/aoconnect";

const { result, results, message, spawn, monitor, unmonitor, dryrun } = connect(
    {
        // custom configs
    },
);

const processSrc = fs.readFileSync('src/ao-profile/registry.lua', 'utf-8')

const wallet = JSON.parse(
    readFileSync("/path/to/arweave/wallet.json").toString(),
);

// spawn
const processId = await spawn({
    // The Arweave TXID of the ao Module
    module: "module TXID",
    // The Arweave wallet address of a Scheduler Unit
    scheduler: "_GQ33BkPtZrqxA84vM8Zk-N2aO0toNNu_C-l-rawrBA",
    // A signer function containing your wallet
    signer: createDataItemSigner(wallet),
    /*
      Refer to a Processes' source code or documentation
      for tags that may effect its computation.
    */
    tags: [
        { name: "Your-Tag-Name-Here", value: "your-tag-value" },
        { name: "Another-Tag", value: "another-value" },
    ],
});
// wait until found on graphql

// evaluate lua code
await message({
    /*
      The arweave TXID of the process, this will become the "target".
      This is the process the message is ultimately sent to.
    */
    process: processId,
    // Tags that the process will use as input.
    tags: [
        { name: "Action", value: "Eval" },
    ],
    // A signer function used to build the message "signature"
    signer: createDataItemSigner(wallet),
    /*
      The "data" portion of the message
      If not specified a random string will be generated
    */
    data: processSrc,
})
    .then(console.log)
    .catch(console.error);
// message write handler

await message({
    /*
      The arweave TXID of the process, this will become the "target".
      This is the process the message is ultimately sent to.
    */
    process: processId,
    // Tags that the process will use as input.
    tags: [
        { name: "Action", value: "Write" },
    ],
    // A signer function used to build the message "signature"
    signer: createDataItemSigner(wallet),
    /*
      The "data" portion of the message
      If not specified a random string will be generated
    */
    data: {},
})
    .then(console.log)
    .catch(console.error);

// read handler
const result = await dryrun({
    process: processId,
    data: '',
    tags: [
        {name: 'Action', value: 'Read'},
});


