// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import "forge-std/Test.sol";

contract ChamberTestUtils is Test {
    /*//////////////////////////////////////////////////////////////
                              INTERNAL
    //////////////////////////////////////////////////////////////*/

    /**
     * Converts a bytes input to a string output, using hexadecimal base.
     *
     * @param buffer    Bytes to convert
     * @return          Hexadecimal string representation of the input
     */
    function bytesToHex(bytes memory buffer) public pure returns (string memory) {
        bytes memory output = new bytes(buffer.length * 2);
        bytes memory _base = "0123456789abcdef";

        for (uint256 i = 0; i < buffer.length; i++) {
            output[i * 2] = _base[uint8(buffer[i]) / _base.length];
            output[i * 2 + 1] = _base[uint8(buffer[i]) % _base.length];
        }

        return string(abi.encodePacked("0x", output));
    }

    /**
     * Get the 0x quotes based on 'buyAmount' for mint.
     *
     * @param _buyAmount    Required amount in tokens units to be bought.
     * @param _buyToken     Buy token address.
     * @param _sellToken    Token to be sold.
     *
     * @return quote        Quote used as call data for swaps.
     * @return sellAmount   Amount of sellToken to be used at the swap.
     */
    function getQuoteDataForMint(uint256 _buyAmount, address _buyToken, address _sellToken)
        internal
        returns (bytes memory quote, uint256 sellAmount)
    {
        string[] memory inputs = new string[](6);
        inputs[0] = "node";
        inputs[1] = "scripts/fetch-0x-quote.js";
        inputs[2] = bytesToHex(abi.encode(_buyAmount));
        inputs[3] = bytesToHex(abi.encode(address(_sellToken)));
        inputs[4] = bytesToHex(abi.encode(_buyToken));
        inputs[5] = bytesToHex(abi.encode(uint256(1)));
        bytes memory response = vm.ffi(inputs);
        (bytes[] memory quotesResponse, uint256 sellAmountResponse) =
            abi.decode(response, (bytes[], uint256));
        return (quotesResponse[0], sellAmountResponse);
    }

    /**
     * Get the 0x quotes based on 'sellAmount' for redeem.
     *
     * @param _sellAmount   Required amount in tokens units to be bought.
     * @param _sellToken    Token to be sold.
     * @param _buyToken     Buy token address.
     *
     * @return quote        Quote used as call data for swaps.
     * @return buyAmount    Amount of buyToken to be received after at the swap.
     */
    function getQuoteDataForRedeem(uint256 _sellAmount, address _sellToken, address _buyToken)
        internal
        returns (bytes memory quote, uint256 buyAmount)
    {
        string[] memory inputs = new string[](6);
        inputs[0] = "node";
        inputs[1] = "scripts/fetch-0x-quote.js";
        inputs[2] = bytesToHex(abi.encode(_sellAmount));
        inputs[3] = bytesToHex(abi.encode(address(_sellToken)));
        inputs[4] = bytesToHex(abi.encode(_buyToken));
        inputs[5] = bytesToHex(abi.encode(uint256(0)));
        bytes memory response = vm.ffi(inputs);
        (bytes[] memory quotesResponse, uint256 buyAmountResponse) =
            abi.decode(response, (bytes[], uint256));
        return (quotesResponse[0], buyAmountResponse);
    }

    function getCompleteQuoteData(address _sellToken, uint256 _sellAmount, address _buyToken)
        internal
        returns (bytes memory, uint256, address)
    {
        string[] memory inputs = new string[](5);
        inputs[0] = "node";
        inputs[1] = "scripts/fetch-full-0x-quote.js";
        inputs[2] = bytesToHex(abi.encode(_sellAmount));
        inputs[3] = bytesToHex(abi.encode(address(_sellToken)));
        inputs[4] = bytesToHex(abi.encode(_buyToken));
        bytes memory response = vm.ffi(inputs);
        (bytes memory quotesResponse, uint256 sellAmountResponse, address target) =
            abi.decode(response, (bytes, uint256, address));
        return (quotesResponse, sellAmountResponse, target);
    }
}
