// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
const { ethers } = require("ethers")
const axios = require("axios")
const encoder = new ethers.utils.AbiCoder()
const qs = require("qs")


async function main(amount, sellToken, buyToken, isMint){
  const qty = encoder.decode(["uint256"], amount)[0]
  const sellAddress = encoder.decode(["address"], sellToken)[0]
  const buyAddress = encoder.decode(["address"], buyToken)[0]
  const mint = (encoder.decode(["uint256"], isMint)[0]).toString()
  const operationType = mint === '1' ? "buyAmount": "sellAmount"
  const quoteUrl = `https://api.0x.org/swap/v1/quote?buyToken=${buyAddress}&sellToken=${sellAddress}&${operationType}=${qty.toString()}&slippagePercentage=0.001`
  try{
    const response = await axios.get(quoteUrl)
    const {data} = response
    const amount = mint === '1' ? data.sellAmount: data.buyAmount
    const encodedData = encoder.encode(["bytes[]", "uint256"], [[data.data], amount])
    process.stdout.write(encodedData)
  } catch(error) {
    console.log(error)
  }
}

const args = process.argv.slice(2)

if (args.length != 4) {
  console.log(`please supply the correct parameters:
    quantity sellToken buyToken isMint
  `)
  process.exit(1)
}

main(args[0], args[1], args[2], args[3])