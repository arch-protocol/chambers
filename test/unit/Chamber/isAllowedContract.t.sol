// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import {Test} from "forge-std/Test.sol";
import {Chamber} from "src/Chamber.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {ArrayUtils} from "src/lib/ArrayUtils.sol";

contract ChamberUnitIsAllowedContractTest is Test {
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
    address private god;
    string private symbol = "WEB3";
    string private name = "Ethereum Universe";
    address private wizard;
    address private allowedContract;
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
        allowedContract = vm.addr(0x232232);
        constituents[0] = address(constituent);
        quantities[0] = 10e18;
        wizards[0] = wizard;
        managers[0] = manager;
        vm.prank(god);
        chamber = new Chamber(owner, name, symbol, constituents, quantities, wizards, managers);
        vm.mockCall(
            god,
            abi.encodeWithSignature("isAllowedContract(address)", allowedContract),
            abi.encode(true)
        );
        vm.prank(manager);
        chamber.addAllowedContract(allowedContract);
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] The function isWizard(address wizard) should return
     * true if the wizard is in Chamber
     */
    function testIsWizardInChamber() public {
        bool isAllowedContract = chamber.isAllowedContract(allowedContract);
        assertEq(isAllowedContract, true);
    }

    /**
     * [SUCCESS] The function isWizard(address wizard) should return
     * false if the wizard is not in Chamber
     */
    function testIsWizardNotInChamber() public {
        bool isAllowedContract = chamber.isAllowedContract(vm.addr(0x123456));
        assertEq(isAllowedContract, false);
    }
}
