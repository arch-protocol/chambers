// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.13.0;

import "forge-std/Test.sol";
import {ArrayUtils} from "src/lib/ArrayUtils.sol";

contract ArrayUtilsUnitContainsTest is Test {
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
     * [SUCCESS] Should return true if the element exists in the array, at index 0
     */
    function testContainsTrueCaseAtZeroIndex() public {
        bool result = myArray.contains(address1);
        assertEq(result, true);
    }

    /**
     * [SUCCESS] Should return true if the element exists in the array, at middle index
     */
    function testContainsTrueCaseAtMiddleIndex() public {
        bool result = myArray.contains(address3);
        assertEq(result, true);
    }

    /**
     * [SUCCESS] Should return true if the element exists in the array, at final index
     */
    function testContainsTrueCaseAtLastIndex() public {
        bool result = myArray.contains(address5);
        assertEq(result, true);
    }

    /**
     * [SUCCESS] Should return false if the element does exists in the array
     */
    function testContainsFalseCase() public {
        bool result = myArray.contains(vm.addr(0x019823));
        assertEq(result, false);
    }

    /**
     * [SUCCESS] Should return false if the element does exists in the array
     */
    function testContainsFalseCaseWithEmptyArray() public {
        address[] memory emptyArray = new address[](0);
        bool result = emptyArray.contains(vm.addr(0x019823));
        assertEq(result, false);
    }
}
