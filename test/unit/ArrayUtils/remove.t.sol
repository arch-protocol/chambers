// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.13.0;

import "forge-std/Test.sol";
import {ArrayUtils} from "src/lib/ArrayUtils.sol";

contract ArrayUtilsUnitRemoveTest is Test {
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
    function testCannotRemoveIfElementIsNotInArray() public {
        vm.expectRevert(bytes("Address not in array"));
        myArray.remove(vm.addr(0x07123));
    }

    /**
     * [REVERT] Should revert if the array is empty
     */
    function testCannotRemoveIfArrayIsEmpty() public {
        address[] memory emptyArray = new address[](0);
        vm.expectRevert(bytes("Address not in array"));
        emptyArray.remove(vm.addr(0x07123));
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should return the correct index, and true, when the element is at index 0
     */
    function testRemoveElementAtZeroIndex() public {
        address[] memory expectedArray = new address[](4);
        expectedArray[0] = address2;
        expectedArray[1] = address3;
        expectedArray[2] = address4;
        expectedArray[3] = address5;

        address[] memory newArray = myArray.remove(address1);
        assertEq(newArray, expectedArray);
    }

    /**
     * [SUCCESS] Should return the correct index, and true, when the element is in a middle index
     */
    function testRemoveElementAtMiddleIndex() public {
        address[] memory expectedArray = new address[](4);
        expectedArray[0] = address1;
        expectedArray[1] = address2;
        expectedArray[2] = address4;
        expectedArray[3] = address5;

        address[] memory newArray = myArray.remove(address3);
        assertEq(newArray, expectedArray);
    }

    /**
     * [SUCCESS] Should return the correct index, and true, when the element is in the last index
     */
    function testRemoveElementAtLastIndex() public {
        address[] memory expectedArray = new address[](4);
        expectedArray[0] = address1;
        expectedArray[1] = address2;
        expectedArray[2] = address3;
        expectedArray[3] = address4;

        address[] memory newArray = myArray.remove(address5);
        assertEq(newArray, expectedArray);
    }
}
