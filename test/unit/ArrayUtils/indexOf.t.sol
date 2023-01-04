// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.13.0;

import "forge-std/Test.sol";
import {ArrayUtils} from "../../../src/lib/ArrayUtils.sol";

contract ArrayUtilsUnitIndexOfTest is Test {
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
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should return the correct index, and true, when the element is at index 0
     */
    function testIndexOfZeroIndex() public {
        (uint256 index, bool present) = myArray.indexOf(address1);
        assertEq(index, 0);
        assertEq(present, true);
    }

    /**
     * [SUCCESS] Should return the correct index, and true, when the element is in a middle index
     */
    function testIndexOfMiddleIndex() public {
        (uint256 index, bool present) = myArray.indexOf(address3);
        assertEq(index, 2);
        assertEq(present, true);
    }

    /**
     * [SUCCESS] Should return the correct index, and true, when the element is in the last index
     */
    function testIndexOfLastIndex() public {
        (uint256 index, bool present) = myArray.indexOf(address5);
        assertEq(index, myArray.length - 1);
        assertEq(present, true);
    }

    /**
     * [SUCCESS] Should return 0 and false, when an element is not present
     */
    function testIndexOfElementNotPresent() public {
        (uint256 index, bool present) = myArray.indexOf(vm.addr(0x08123));
        assertEq(index, 0);
        assertEq(present, false);
    }

    /**
     * [SUCCESS] Should return 0 and false, when the array is empty
     */
    function testIndexOfEmptyArray() public {
        address[] memory emptyArray = new address[](0);
        (uint256 index, bool present) = emptyArray.indexOf(vm.addr(0x09923));
        assertEq(index, 0);
        assertEq(present, false);
    }
}
