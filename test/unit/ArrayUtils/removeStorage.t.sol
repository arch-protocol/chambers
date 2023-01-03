// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.13.0;

import "forge-std/Test.sol";
import {ArrayUtils} from "../../../src/lib/ArrayUtils.sol";

contract RemoveStorageTest is Test {
    using ArrayUtils for address[];

    /*//////////////////////////////////////////////////////////////
                            VARIABLES
    //////////////////////////////////////////////////////////////*/

    address[] myArray;
    address[] emptyArray;
    address public address1 = vm.addr(0x01);
    address public address2 = vm.addr(0x02);
    address public address3 = vm.addr(0x03);
    address public address4 = vm.addr(0x04);
    address public address5 = vm.addr(0x05);

    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [REVERT] Should revert if element is not in array
     */
    function testCannotRemoveStorageIfElementIsNotInArray() public {
        myArray = new address[](1);
        myArray[0] = address1;
        vm.expectRevert(bytes("Address not in array"));
        myArray.removeStorage(vm.addr(0x07123));
    }

    /**
     * [REVERT] Should revert if the array is empty
     */
    function testCannotRemoveStorageIfArrayIsEmpty() public {
        emptyArray = new address[](0);
        vm.expectRevert(bytes("Address not in array"));
        emptyArray.removeStorage(vm.addr(0x07123));
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should return the correct index, and true, when the element is at index 0
     */
    function testRemoveStorageElementAtZeroIndex() public {
        myArray = new address[](5);
        myArray[0] = address1;
        myArray[1] = address2;
        myArray[2] = address3;
        myArray[3] = address4;
        myArray[4] = address5;

        myArray.removeStorage(address1);
        assertEq(myArray.length, 4);
        assertEq(myArray[0], address5);
        assertEq(myArray[1], address2);
        assertEq(myArray[2], address3);
        assertEq(myArray[3], address4);
    }

    /**
     * [SUCCESS] Should return the correct index, and true, when the element is in a middle index
     */
    function testRemoveStorageElementAtMiddleIndex() public {
        myArray = new address[](5);
        myArray[0] = address1;
        myArray[1] = address2;
        myArray[2] = address3;
        myArray[3] = address4;
        myArray[4] = address5;

        myArray.removeStorage(address3);
        assertEq(myArray.length, 4);
        assertEq(myArray[0], address1);
        assertEq(myArray[1], address2);
        assertEq(myArray[2], address5);
        assertEq(myArray[3], address4);
    }

    /**
     * [SUCCESS] Should return the correct index, and true, when the element is in the last index
     */
    function testRemoveStorageElementAtLastIndex() public {
        myArray = new address[](5);
        myArray[0] = address1;
        myArray[1] = address2;
        myArray[2] = address3;
        myArray[3] = address4;
        myArray[4] = address5;

        myArray.removeStorage(address5);
        assertEq(myArray.length, 4);
        assertEq(myArray[0], address1);
        assertEq(myArray[1], address2);
        assertEq(myArray[2], address3);
        assertEq(myArray[3], address4);
    }
}
