// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import {Test} from "forge-std/Test.sol";
import {ChamberGod} from "src/ChamberGod.sol";
import {ArrayUtils} from "src/lib/ArrayUtils.sol";

contract ChamberGodUnitRemoveWizardTest is Test {
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
     * [SUCCESS] Removing a wizard with Owner should work
     */
    function testRemoveWizardWithOwnerShouldWork() public {
        address wizard = vm.addr(0x123);
        vm.prank(owner);
        god.addWizard(wizard);
        assertEq(god.isWizard(wizard), true);
        vm.prank(owner);
        god.removeWizard(wizard);
        assertEq(god.isWizard(wizard), false);
    }

    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [REVERT] Removing a wizard with non-owner should revert
     */
    function testRemoveWizardWithNonOwnerShouldRevert() public {
        address wizard = vm.addr(0x123);
        vm.prank(owner);
        god.addWizard(wizard);
        assertEq(god.isWizard(wizard), true);
        vm.expectRevert("UNAUTHORIZED");
        vm.prank(vm.addr(0x456));
        god.removeWizard(wizard);
    }

    /**
     * [REVERT] Removing a wizard that is not a wizard should revert
     */
    function testRemoveWizardThatIsNotWizardShouldRevert() public {
        address wizard = vm.addr(0x123);
        vm.prank(owner);
        vm.expectRevert("Wizard not valid");
        god.removeWizard(wizard);
    }
}
