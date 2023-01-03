// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.13.0;

import "forge-std/Test.sol";
import {ArrayUtils} from "../../../src/lib/ArrayUtils.sol";

contract HasDuplicateTest is Test {
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
     * [REVERT] Should revert if the array is empty
     */
    function testCannotHasDuplicateIfArrayIsEmpty() public {
        address[] memory emptyArray = new address[](0);
        vm.expectRevert(bytes("_array is empty"));
        emptyArray.hasDuplicate();
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should return false if the array has no duplicates
     */
    function testHasDuplicateFalseCase() public {
        bool result = myArray.hasDuplicate();
        assertEq(result, false);
    }

    /**
     * [SUCCESS] Should return true if the array has duplicates at index 0
     */
    function testHasDuplicateTrueCaseAtZeroIndex() public {
        myArray[1] = address1;
        bool result = myArray.hasDuplicate();
        assertEq(result, true);
    }

    /**
     * [SUCCESS] Should return true if the array has duplicates at middle index
     */
    function testHasDuplicateTrueCaseAtMiddleIndex() public {
        myArray[3] = address1;
        bool result = myArray.hasDuplicate();
        assertEq(result, true);
    }

    /**
     * [SUCCESS] Should return true if the array has duplicates at last index
     */
    function testHasDuplicateTrueCaseAtlastIndex() public {
        myArray[4] = address1;
        bool result = myArray.hasDuplicate();
        assertEq(result, true);
    }
}
