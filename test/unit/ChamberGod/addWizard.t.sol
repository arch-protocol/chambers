// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import {Test} from "forge-std/Test.sol";
import {ChamberGod} from "src/ChamberGod.sol";
import {ArrayUtils} from "src/lib/ArrayUtils.sol";

contract ChamberGodUnitAddWizardTest is Test {
    /*//////////////////////////////////////////////////////////////
                              LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using ArrayUtils for address[];

    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/

    ChamberGod private god;
    address private owner;
    address[] private _constituents;
    uint256[] private _quantities;
    address[] private _wizards;
    address[] private _managers;
    string private _name = "Chamber V1";
    string private _symbol = "CHAMBER";

    /*//////////////////////////////////////////////////////////////
                              SET UP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        owner = vm.addr(0xA11c3);
        vm.prank(owner);
        god = new ChamberGod();
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Adding a wizard with Owner should work
     */
    function testAddWizardWithOwnerShouldWork() public {
        address wizard = vm.addr(0x123);
        vm.prank(owner);
        god.addWizard(wizard);
        assertEq(god.isWizard(wizard), true);
    }

    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [REVERT] Adding a wizard with non-owner should revert
     */
    function testAddWizardWithNonOwnerShouldRevert() public {
        address wizard = vm.addr(0x123);
        vm.expectRevert("UNAUTHORIZED");
        vm.prank(vm.addr(0x456));
        god.addWizard(wizard);
    }

    /**
     * [REVERT] Adding a wizard that is already a wizard should revert
     */
    function testAddWizardThatIsAlreadyWizardShouldRevert() public {
        address wizard = vm.addr(0x123);
        vm.prank(owner);
        god.addWizard(wizard);
        vm.expectRevert("Wizard already in ChamberGod");
        vm.prank(owner);
        god.addWizard(wizard);
    }

    /**
     * [REVERT] Adding a wizard with address(0) should revert
     */
    function testAddWizardWithAddressZeroShouldRevert() public {
        vm.expectRevert("Must be a valid wizard");
        vm.prank(owner);
        god.addWizard(address(0));
    }
}
