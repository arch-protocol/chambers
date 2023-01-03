// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import {Test} from "forge-std/Test.sol";
import {Chamber} from "src/Chamber.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {ArrayUtils} from "src/lib/ArrayUtils.sol";

contract ChamberUnitAddManagerTest is Test {
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
     * [SUCCESS] The function addManager(address manager) should add manager to the Chamber
     * if caller is Owner and Manager is not in Chamber
     */
    function testAddManagerWithOwner() public {
        address newManager = vm.addr(0x23232);
        bool isManager = chamber.isManager(newManager);
        assertEq(isManager, false);
        vm.prank(owner);
        chamber.addManager(newManager);
        isManager = chamber.isManager(newManager);
        assertEq(isManager, true);
    }

    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [REVERT] Should call addManager() as Owner and revert because the manager
     * is already a manager in the Chamber
     */
    function testCannotAddManagerAlreadyInChamber() public {
        vm.expectRevert("Already manager");
        vm.prank(owner);
        chamber.addManager(manager);
    }

    /**
     * [REVERT] Should call addManager() and revert because caller is
     * not Owner of the Chamber
     */
    function testCannotAddManagerWithoutOwner() public {
        vm.expectRevert("UNAUTHORIZED");
        chamber.addManager(vm.addr(0x123123));
    }

    /**
     * [REVERT] Should call addManager() and revert because caller is
     * a Manager and not Owner of the Chamber
     */
    function testCannotAddManagerWithManager() public {
        vm.expectRevert("UNAUTHORIZED");
        vm.prank(manager);
        chamber.addManager(vm.addr(0x123123));
    }
}
