import AoLoader from '@permaweb/ao-loader'
import fs from 'fs'

const wasmModuleFile = process.env.WASM || './AOS.wasm';
const wasmFormat = process.env.FORMAT || 'wasm32-unknown-emscripten'

export function SendFactory(format = wasmFormat, wasmFile = wasmModuleFile) {
    const aos = fs.readFileSync(wasmFile)
    let memory = null
    return async function Send(DataItem) {
        const msg = Object.keys(DataItem).reduce(function (di, k) {
        if (di[k]) {
            di[k] = DataItem[k]
        } else {
            di.Tags = di.Tags.concat([{ name: k, value: DataItem[k] }])
        }
        return di
        }, createMsg())

        const handle = await AoLoader(aos, { format })
        const env = createEnv()

        const result = await handle(memory, msg, env)
        if (result.Error) {
        return 'ERROR: ' + JSON.stringify(result.Error)
        }
        memory = result.Memory

        return { Messages: result.Messages, Spawns: result.Spawns, Output: result.Output, Assignments: result.Assignments }
    }
}

// timestamp hack because Date.now() was not updating
let increment = 0;
function getTimestamp() {
  console.log(Date.now())
  return 1000000 + increment++;
}
function createMsg() {
  return {
    Id: '1234',
    Target: 'AOS',
    Owner: 'OWNER',
    From: 'OWNER',
    Data: '1984',
    Tags: [],
    'Block-Height': '1',
    Timestamp: getTimestamp(),
    Module: '4567'
  }
}

function createEnv() {
  return {
    Process: {
      Id: '9876',
      Tags: [
        { name: 'Data-Protocol', value: 'ao' },
        { name: 'Variant', value: 'ao.TN.1' },
        { name: 'Type', value: 'Process' }
      ]
    },
    Module: {
      Id: '4567',
      Tags: [
        { name: 'Data-Protocol', value: 'ao' },
        { name: 'Variant', value: 'ao.TN.1' },
        { name: 'Type', value: 'Module' }
      ]
    }
  }
}
