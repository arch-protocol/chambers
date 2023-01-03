// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import {Test} from "forge-std/Test.sol";
import {Chamber} from "src/Chamber.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {ArrayUtils} from "src/lib/ArrayUtils.sol";

contract ChamberUnitAddAllowedContractTest is Test {
    /*//////////////////////////////////////////////////////////////
                              LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using ArrayUtils for address[];

    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/

    Chamber private chamber;
    address private owner;
    address private god;
    address private manager;
    string private symbol = "WEB3";
    string private name = "Ethereum Universe";
    address private wizard;
    address private newAllowedContract;
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
        newAllowedContract = vm.addr(0x232232);
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
     * [SUCCESS] The function addAllowedContract(address target) should add an allowedContract
     * to the Chamber if caller is manager and allowedContract is not allowed yet.
     */
    function testAddAllowedContractWithManager() public {
        vm.mockCall(
            god,
            abi.encodeWithSignature("isAllowedContract(address)", newAllowedContract),
            abi.encode(true)
        );
        bool isAllowedContract = chamber.isAllowedContract(newAllowedContract);
        assertEq(isAllowedContract, false);
        vm.prank(manager);
        chamber.addAllowedContract(newAllowedContract);
        isAllowedContract = chamber.isAllowedContract(newAllowedContract);
        assertEq(isAllowedContract, true);
    }

    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [REVERT] Should call addAllowedContract() as manager and revert because the contract
     * is already a allowed in the Chamber
     */
    function testCannotAddAllowedContractAlreadyAllowed() public {
        vm.mockCall(
            god,
            abi.encodeWithSignature("isAllowedContract(address)", newAllowedContract),
            abi.encode(true)
        );
        vm.prank(manager);
        chamber.addAllowedContract(newAllowedContract);

        vm.expectRevert("Contract already allowed");
        vm.prank(manager);
        chamber.addAllowedContract(newAllowedContract);
    }

    /**
     * [REVERT] Should call addAllowedContract() and revert because caller is
     * not manager of the Chamber
     */
    function testCannotAddManagerWithoutOwner() public {
        vm.expectRevert("Must be Manager");
        chamber.addAllowedContract(newAllowedContract);
    }

    /**
     * [REVERT] Should call addAllowedContract() and revert because caller is
     * a wizard and not manager of the chamber
     */
    function testCannotAddManagerWithWizard() public {
        vm.expectRevert("Must be Manager");
        vm.prank(wizard);
        chamber.addAllowedContract(newAllowedContract);
    }

    /**
     * [REVERT] Should call addAllowedContract() and revert because contract is
     * not allowed in god
     */
    function testCannotAddAllowedContractNotAllowedInGod() public {
        vm.mockCall(
            god,
            abi.encodeWithSignature("isAllowedContract(address)", newAllowedContract),
            abi.encode(false)
        );
        vm.expectRevert("Contract not allowed in ChamberGod");
        vm.prank(manager);
        chamber.addAllowedContract(newAllowedContract);
    }
}
