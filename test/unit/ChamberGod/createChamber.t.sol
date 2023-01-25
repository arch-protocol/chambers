// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import {Test} from "forge-std/Test.sol";
import {ChamberGod} from "src/ChamberGod.sol";
import {ArrayUtils} from "src/lib/ArrayUtils.sol";

contract ChamberGodUnitCreateChamberTest is Test {
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
    address private validWizard;

    /*//////////////////////////////////////////////////////////////
                              SET UP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        validWizard = vm.addr(0x666);
        owner = vm.addr(0xA11c3);
        vm.prank(owner);
        god = new ChamberGod();
        vm.prank(owner);
        god.addWizard(validWizard);
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Creating a chamber with the proper params should work
     */
    function testCreateChamberShouldCreateProperly() public {
        _constituents = new address[](1);
        _constituents[0] = vm.addr(0x123);
        _quantities = new uint256[](1);
        _quantities[0] = 10e18;
        _managers = new address[](1);
        _managers[0] = address(owner);
        _wizards = new address[](1);
        _wizards[0] = validWizard;
        address chamber =
            god.createChamber(_name, _symbol, _constituents, _quantities, _wizards, _managers);
        assertEq(god.isChamber(chamber), true);
    }

    /**
     * [SUCCESS] Creating a chamber with the no wizards should work
     */
    function testCreateChamberWithoutWizardsShouldCreateProperly() public {
        _constituents = new address[](1);
        _constituents[0] = vm.addr(0x123);
        _quantities = new uint256[](1);
        _quantities[0] = 10e18;
        _managers = new address[](1);
        _managers[0] = address(owner);
        _wizards = new address[](0);
        address chamber =
            god.createChamber(_name, _symbol, _constituents, _quantities, _wizards, _managers);
        assertEq(god.isChamber(chamber), true);
    }

    /**
     * [SUCCESS] Create a Chamber without managers
     */
    function testCannotCreateChamberWithoutManagers() public {
        _constituents = new address[](1);
        _constituents[0] = vm.addr(0x123);
        _quantities = new uint256[](1);
        _quantities[0] = 10e18;
        _managers = new address[](0);
        _wizards = new address[](0);
        god.createChamber(_name, _symbol, _constituents, _quantities, _wizards, _managers);
    }

    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [REVERT] Should call createChamber() and revert the call because constituents length is 0
     */
    function testCannotCreateChamberWithoutConstituents() public {
        _constituents = new address[](0);
        _quantities = new uint256[](1);
        _quantities[0] = 10e18;
        _managers = new address[](1);
        _managers[0] = address(owner);
        _wizards = new address[](0);
        vm.expectRevert("Must have constituents");
        god.createChamber(_name, _symbol, _constituents, _quantities, _wizards, _managers);
    }

    /**
     * [REVERT] Should call createChamber() and revert the call because quantities length is 0
     */
    function testCannotCreateChamberWithoutQuantities() public {
        _constituents = new address[](1);
        _constituents[0] = vm.addr(0x123);
        _quantities = new uint256[](0);
        _managers = new address[](1);
        _managers[0] = address(owner);
        _wizards = new address[](0);
        vm.expectRevert("Elements lengths not equal");
        god.createChamber(_name, _symbol, _constituents, _quantities, _wizards, _managers);
    }

    /**
     * [REVERT] Should call createChamber() and revert the call because quantities length and
     * constituents length are different
     */
    function testCannotCreateChamberWithConstAndQtysLengthDiff() public {
        _constituents = new address[](1);
        _constituents[0] = vm.addr(0x123);
        _quantities = new uint256[](2);
        _quantities[0] = 1e18;
        _quantities[1] = 10e18;
        _managers = new address[](1);
        _managers[0] = address(owner);
        _wizards = new address[](0);
        vm.expectRevert("Elements lengths not equal");
        god.createChamber(_name, _symbol, _constituents, _quantities, _wizards, _managers);
    }

    /**
     * [REVERT] Should call createChamber() and revert the call because constituents
     * contains duplicate elements
     */
    function testCannotCreateChamberWithDuplicateConstituents() public {
        _constituents = new address[](3);
        _constituents[0] = vm.addr(0x123);
        _constituents[1] = vm.addr(0x123);
        _constituents[2] = vm.addr(0x32142);
        _quantities = new uint256[](3);
        _quantities[0] = 1e18;
        _quantities[1] = 10e18;
        _quantities[2] = 15e18;
        _managers = new address[](1);
        _managers[0] = address(owner);
        _wizards = new address[](0);
        vm.expectRevert("Constituents must be unique");
        god.createChamber(_name, _symbol, _constituents, _quantities, _wizards, _managers);
    }

    /**
     * [REVERT] Should call createChamber() and revert the call because constituents
     * contains a null address
     */
    function testCannotCreateChamberWithNullConstituent() public {
        _constituents = new address[](2);
        _constituents[0] = address(0);
        _constituents[1] = vm.addr(0x32142);
        _quantities = new uint256[](2);
        _quantities[0] = 1e18;
        _quantities[1] = 10e18;
        _managers = new address[](1);
        _managers[0] = address(owner);
        _wizards = new address[](0);
        vm.expectRevert("Constituent must not be null");
        god.createChamber(_name, _symbol, _constituents, _quantities, _wizards, _managers);
    }

    /**
     * [REVERT] Should call createChamber() and revert the call because quantities
     * contains a 0 value
     */
    function testCannotCreateChamberWithZeroQuantityForConstituent() public {
        _constituents = new address[](2);
        _constituents[0] = vm.addr(0x32142);
        _constituents[1] = vm.addr(0x123);
        _quantities = new uint256[](2);
        _quantities[0] = 0;
        _quantities[1] = 1e18;
        _managers = new address[](1);
        _managers[0] = address(owner);
        _wizards = new address[](0);
        vm.expectRevert("Quantity must be greater than 0");
        god.createChamber(_name, _symbol, _constituents, _quantities, _wizards, _managers);
    }

    /**
     * [REVERT] Should call createChamber() and revert the call because managers
     * contains a null address
     */
    function testCannotCreateChamberWithNullManager() public {
        _constituents = new address[](2);
        _constituents[0] = vm.addr(0x32142);
        _constituents[1] = vm.addr(0x123);
        _quantities = new uint256[](2);
        _quantities[0] = 10e18;
        _quantities[1] = 1e18;
        _managers = new address[](1);
        _managers[0] = address(0);
        _wizards = new address[](0);
        vm.expectRevert("Manager must not be null");
        god.createChamber(_name, _symbol, _constituents, _quantities, _wizards, _managers);
    }

    /**
     * [REVERT] Should call createChamber() and revert the call because wizards
     * contains a Wizard that is not in ChamberGod
     */
    function testCannotCreateChamberWithInvalidWizards() public {
        _constituents = new address[](2);
        _constituents[0] = vm.addr(0x32142);
        _constituents[1] = vm.addr(0x123);
        _quantities = new uint256[](2);
        _quantities[0] = 10e18;
        _quantities[1] = 1e18;
        _managers = new address[](1);
        _managers[0] = address(owner);
        _wizards = new address[](1);
        _wizards[0] = vm.addr(0x123123123);
        vm.expectRevert("Wizard not valid");
        god.createChamber(_name, _symbol, _constituents, _quantities, _wizards, _managers);
    }
}
