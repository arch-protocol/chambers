// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
const { ethers } = require("ethers")
const axios = require("axios")
const encoder = new ethers.utils.AbiCoder()
const qs = require("qs")


async function main(amount, sellToken, buyToken){
  const qty = encoder.decode(["uint256"], amount)[0]
  const sellAddress = encoder.decode(["address"], sellToken)[0]
  const buyAddress = encoder.decode(["address"], buyToken)[0]
  const quoteUrl = `https://api.0x.org/swap/v1/quote?buyToken=${buyAddress}&sellToken=${sellAddress}&sellAmount=${qty.toString()}&slippagePercentage=0.001`
  try{
    const response = await axios.get(quoteUrl)
    const {data} = response
    const encodedData = encoder.encode(["bytes", "uint256", "address"], [data.data, data.buyAmount, data.to])
    process.stdout.write(encodedData)
  } catch(error) {
    console.log(error)
  }
}

const args = process.argv.slice(2)

if (args.length != 3) {
  console.log(`please supply the correct parameters:
    quantity sellToken buyToken
  `)
  process.exit(1)
}

main(args[0], args[1], args[2])