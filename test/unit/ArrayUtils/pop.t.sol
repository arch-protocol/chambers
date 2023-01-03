// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.13.0;

import "forge-std/Test.sol";
import {ArrayUtils} from "../../../src/lib/ArrayUtils.sol";

contract PopTest is Test {
    using ArrayUtils for address[];

    /*//////////////////////////////////////////////////////////////
                            VARIABLES
    //////////////////////////////////////////////////////////////*/

    address[] public myArray = new address[](5);
    address public address1 = vm.addr(0x01);
    address public address2 = vm.addr(0x02);
    address public address3 = vm.addr(0x03);
    address public address4 = vm.addr(0x04);
    address public address5 = vm.addr(0x05);

    /*//////////////////////////////////////////////////////////////
                              SET UP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        myArray[0] = address1;
        myArray[1] = address2;
        myArray[2] = address3;
        myArray[3] = address4;
        myArray[4] = address5;
    }

    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [REVERT] Should revert if the index is out of bounds
     */
    function testCannotPopIfIndexIsOutOfBounds() public {
        vm.expectRevert(bytes("Index must be < _array length"));
        myArray.pop(10);
    }

    /**
     * [REVERT] Should revert if the array is empty
     */
    function testCannotPopIfArrayIsEmpty() public {
        address[] memory emptyArray = new address[](0);
        vm.expectRevert(bytes("Index must be < _array length"));
        emptyArray.pop(0);
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should return the correct index, and true, when the element is at index 0
     */
    function testPopZeroIndex() public {
        address[] memory expectedArray = new address[](4);
        expectedArray[0] = address2;
        expectedArray[1] = address3;
        expectedArray[2] = address4;
        expectedArray[3] = address5;

        (address[] memory newArray, address deletedAddress) = myArray.pop(0);
        assertEq(newArray, expectedArray);
        assertEq(deletedAddress, address1);
    }

    /**
     * [SUCCESS] Should return the correct index, and true, when the element is in a middle index
     */
    function testPopMiddleIndex() public {
        address[] memory expectedArray = new address[](4);
        expectedArray[0] = address1;
        expectedArray[1] = address2;
        expectedArray[2] = address4;
        expectedArray[3] = address5;

        (address[] memory newArray, address deletedAddress) = myArray.pop(2);
        assertEq(newArray, expectedArray);
        assertEq(deletedAddress, address3);
    }

    /**
     * [SUCCESS] Should return the correct index, and true, when the element is in the last index
     */
    function testPopLastIndex() public {
        address[] memory expectedArray = new address[](4);
        expectedArray[0] = address1;
        expectedArray[1] = address2;
        expectedArray[2] = address3;
        expectedArray[3] = address4;

        (address[] memory newArray, address deletedAddress) = myArray.pop(4);
        assertEq(newArray, expectedArray);
        assertEq(deletedAddress, address5);
    }
}
