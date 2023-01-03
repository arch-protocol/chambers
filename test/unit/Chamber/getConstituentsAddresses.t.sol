// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import {Test} from "forge-std/Test.sol";
import {Chamber} from "src/Chamber.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {ArrayUtils} from "src/lib/ArrayUtils.sol";

contract ChamberUnitGetConstituentsAddressesTest is Test {
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
        constituents = new address[](2);
        quantities = new uint256[](2);
        wizards = new address[](1);
        managers = new address[](1);
        constituent = new MockERC20("Random constituent", "CONST", 18);
        owner = vm.addr(0x2);
        manager = vm.addr(0x3);
        wizard = vm.addr(0x4);
        constituents[0] = address(constituent);
        constituents[1] = vm.addr(0xC01);
        quantities[0] = 10e18;
        quantities[1] = 1e18;
        wizards[0] = wizard;
        managers[0] = manager;
        chamber = new Chamber(owner, name, symbol, constituents, quantities, wizards, managers);
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] The function getConstituentsAddresses() should return
     * the adress of all the constituents in the Chamber
     */
    function testGetConstituentsAddresses() public {
        address[] memory chamberConstituents = chamber.getConstituentsAddresses();
        assertEq(chamberConstituents, constituents);
    }

    /**
     * [SUCCESS] The function getConstituentsAddresses() should return
     * the adress of all the constituents in the Chamber in the correct order
     */
    function testGetConstituentsAddressesInRightOrder() public {
        address[] memory chamberConstituents = chamber.getConstituentsAddresses();
        assertEq(chamberConstituents[0], address(constituent));
        assertEq(chamberConstituents[1], vm.addr(0xC01));
    }

    /**
     * [SUCCESS] The function getConstituentsAddresses() should return [] if Chamber has no constituents
     */
    function testGetConstituentsAddressesWhenChamberHasNoConstituents() public {
        uint256[] memory emptyUint = new uint256[](0);
        address[] memory emptyAddresses = new address[](0);
        chamber = new Chamber(owner, name, symbol, emptyAddresses, emptyUint, wizards, managers);
        address[] memory chamberConstituents = chamber.getConstituentsAddresses();
        assertEq(chamberConstituents, emptyAddresses);
    }
}
