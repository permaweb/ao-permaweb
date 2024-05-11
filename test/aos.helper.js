import AoLoader from '@permaweb/ao-loader'
import fs from 'fs'

const aos = fs.readFileSync(process.env.WASM || './AOS.wasm')
const format = process.env.WASM == './AOS-SQLITE.wasm' ? 'wasm32-unknown-emscripten2' : 'wasm32-unknown-emscripten'
let memory = null

export async function Send(DataItem) {

  const msg = Object.keys(DataItem).reduce(function (di, k) {
    if (di[k]) {
      di[k] = DataItem[k]
    } else {
      di.Tags.concat([{ name: k, value: DataItem[k] }])
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

  return result.Output?.data
}

function createMsg() {
  return {
    Id: '1234',
    Target: 'AOS',
    Owner: 'OWNER',
    From: 'OWNER',
    Data: '1984',
    Tags: [{ name: 'Action', value: 'Eval' }],
    'Block-Height': '1',
    Timestamp: Date.now(),
    Module: '4567'
  }
}

function createEnv() {
  return {
    Process: {
      Id: '9876',
      Tags: []
    },
    Module: {
      Id: '4567',
      Tags: [

      ]
    }
  }
}