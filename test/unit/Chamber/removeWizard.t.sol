// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import {Test} from "forge-std/Test.sol";
import {Chamber} from "src/Chamber.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {ArrayUtils} from "src/lib/ArrayUtils.sol";

contract ChamberUnitRemoveWizardTest is Test {
    /*//////////////////////////////////////////////////////////////
                              LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using ArrayUtils for address[];

    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/

    Chamber private chamber;
    address private owner;
    address private manager;
    string private symbol = "WEB3";
    string private name = "Ethereum Universe";
    address private wizard;
    MockERC20 private constituent;
    address[] private constituents;
    uint256[] private quantities;
    address[] private wizards;
    address[] private managers;

    /*//////////////////////////////////////////////////////////////
                              SET UP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        constituents = new address[](1);
        quantities = new uint256[](1);
        wizards = new address[](1);
        managers = new address[](1);
        constituent = new MockERC20("Random constituent", "CONST", 18);
        owner = vm.addr(0x2);
        manager = vm.addr(0x3);
        wizard = vm.addr(0x4);
        constituents[0] = address(constituent);
        quantities[0] = 10e18;
        wizards[0] = wizard;
        managers[0] = manager;
        chamber = new Chamber(owner, name, symbol, constituents, quantities, wizards, managers);
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] The function removeWizard(address wizard) should remove
     * the wizard from the Chamber if caller is Manager and Wizard is in Chamber
     */
    function testRemoveWizardWithManager() public {
        bool validWizard = chamber.isWizard(wizard);
        assertEq(validWizard, true);
        vm.prank(manager);
        chamber.removeWizard(wizard);
        validWizard = chamber.isWizard(wizard);
        assertEq(validWizard, false);
    }

    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [REVERT] Should call removeWizard() as Manager and revert because wizard is
     * not in Chamber
     */
    function testCannotRemoveWizardNotInChamber() public {
        vm.expectRevert("Wizard not in chamber");
        vm.prank(manager);
        chamber.removeWizard(address(constituent));
    }

    /**
     * [REVERT] Should call removeWizard() and revert because caller is not Manager
     */
    function testCannotRemoveWizardOnlyManager() public {
        vm.expectRevert("Must be Manager");
        chamber.removeWizard(wizard);
    }
}
