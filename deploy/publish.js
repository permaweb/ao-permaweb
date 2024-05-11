// Deploy to AO
import { connect, createDataItemSigner } from '@permaweb/aoconnect'
import fs from 'fs'

const AOS = process.env.AOS
const lua = fs.readFileSync('../src/main.lua', 'utf-8')
const keyfile = process.env.KEYFILE
const jwk = JSON.parse(atob(keyfile))


async function main() {
  const { message, result } = connect()

  const messageId = await message({
    process: AOS,
    signer: createDataItemSigner(jwk),
    tags: [
      { name: 'Action', value: 'Eval' }
    ],
    data: lua
  })

  const res = await result({
    process: AOS,
    message: messageId
  })

  if (res?.Output?.data) {
    console.log('Successfully published AOS process ', messageId)
  } else {
    console.error(res?.Error || 'Unknown error occured deploying AOS')
  }
}

main()