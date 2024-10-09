import AoLoader from '@permaweb/ao-loader'
import fs from 'fs'

const wasmModuleFile = process.env.WASM || './AOS.wasm';
const wasmFormat = process.env.FORMAT || 'wasm32-unknown-emscripten'

export function SendFactory(envConfig = {}, format = wasmFormat, wasmFile = wasmModuleFile, ) {
    const aos = fs.readFileSync(wasmFile)
    let memory = null
    const Send = async function Send(DataItem, messageConfig = {}) {

        const { Tags = {}, ...Rest } = DataItem;
        const msg = Object.keys(Rest).reduce(function (di, k) {
            if (di[k]) {
                di[k] = Rest[k]
            } else {
                di.Tags = di.Tags.concat([{ name: k, value: Rest[k] }])
            }
            return di
        }, createMsg(envConfig, messageConfig))
        Object.entries(Tags).forEach(t => {
            const k = t[0];
            const v = t[1];
            msg.Tags.push({ name: k, value: v});
        })


        const handle = await AoLoader(aos, { format })
        const env = createEnv(envConfig)
        const result = await handle(memory, msg, env)
        if (result.Error) {
        return 'ERROR: ' + JSON.stringify(result.Error)
        }
        memory = result.Memory

        return { Messages: result.Messages, Spawns: result.Spawns, Output: result.Output, Assignments: result.Assignments }
    }
    return { Send }
}

// timestamp hack because Date.now() was not updating
let increment = 0;
function getTimestamp() {
  console.log(Date.now())
  return 1000000 + increment++;
}
function createMsg(env, messageConfig ) {
    const { moduleId, defaultOwner, defaultFrom } = env || {}
    const { messageId } = messageConfig || {};
  return {
    Id: messageId || "1234",
    Target: 'AOS',
    Owner: defaultOwner || 'FROMOWNER',
    From: defaultFrom || 'FROMOWNER',
    Data: `{ "testdata": true }`,
    Tags: [],
    'Block-Height': '1',
    Timestamp: getTimestamp(),
    Module: moduleId || '4567'
  }
}

function createEnv(env) {
    const { processId, moduleId } = env || {}
  return {
    Process: {
      Id: processId || '9876',
      Tags: [
        { name: 'Data-Protocol', value: 'ao' },
        { name: 'Variant', value: 'ao.TN.1' },
        { name: 'Type', value: 'Process' }
      ]
    },
    Module: {
      Id: moduleId || '4567',
      Tags: [
        { name: 'Data-Protocol', value: 'ao' },
        { name: 'Variant', value: 'ao.TN.1' },
        { name: 'Type', value: 'Module' }
      ]
    }
  }
}
