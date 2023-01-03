// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import {Test} from "forge-std/Test.sol";
import {Chamber} from "src/Chamber.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {ArrayUtils} from "src/lib/ArrayUtils.sol";

contract ChamberUnitAddWizardTest is Test {
    /*//////////////////////////////////////////////////////////////
                              LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using ArrayUtils for address[];

    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/

    Chamber private chamber;
    address private god;
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
        god = vm.addr(0x5);
        constituents[0] = address(constituent);
        quantities[0] = 10e18;
        wizards[0] = wizard;
        managers[0] = manager;
        vm.prank(god);
        chamber = new Chamber(owner, name, symbol, constituents, quantities, wizards, managers);
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] The function addWizard(address wizard) should add the wizard to the Chamber
     * if caller is Manager, Wizard is not in Chamber and it is validated in ChamberGod
     */
    function testAddWizardWithManager() public {
        address someWizard = vm.addr(0x123123);
        vm.mockCall(god, abi.encodeWithSignature("isWizard(address)", someWizard), abi.encode(true));
        vm.prank(manager);
        chamber.addWizard(someWizard);

        address[] memory chamberWizards = chamber.getWizards();
        assertEq(chamberWizards[1], vm.addr(0x123123));
    }

    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [REVERT] Should call addWizard() and revert because caller is not Manager
     */
    function testCannotAddWizardWithoutManager() public {
        vm.expectRevert("Must be Manager");
        chamber.addWizard(vm.addr(0x123123));
    }

    /**
     * [REVERT] Should call addWizard() and revert because wizard is already in Chamber
     */
    function testCannotAddWizardAlreadyInChamber() public {
        vm.expectRevert("Wizard already in Chamber");
        vm.mockCall(god, abi.encodeWithSignature("isWizard(address)", wizard), abi.encode(true));
        vm.prank(manager);
        chamber.addWizard(wizard);
    }

    /**
     * [REVERT] Should call addWizard() and revert because wizard is not validated in ChamberGod
     */
    function testCannotAddWizardNotValidated() public {
        address someWizard = vm.addr(0x123123);
        vm.mockCall(
            god, abi.encodeWithSignature("isWizard(address)", someWizard), abi.encode(false)
        );
        vm.expectRevert("Wizard not validated in ChamberGod");
        vm.prank(manager);
        chamber.addWizard(someWizard);
    }
}
