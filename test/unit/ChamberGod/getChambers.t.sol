// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17.0;

import {Test} from "forge-std/Test.sol";
import {ChamberGod} from "src/ChamberGod.sol";
import {ArrayUtils} from "src/lib/ArrayUtils.sol";

contract ChamberGodUnitGetChambersTest is Test {
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
     * [SUCCESS] Get chambers should work with created chambers
     */
    function testGetChamberWithChambersShouldWork() public {
        address[] memory chambersArray = new address[](1);
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
        chambersArray[0] = chamber;
        address[] memory chambers = god.getChambers();
        assertEq(chambers, chambersArray);
    }

    /**
     * [SUCCESS] Get chambers should work without created chambers
     */
    function testGetChamberWithNoChambersShouldWork() public {
        address[] memory emptyArray = new address[](0);
        address[] memory chambers = god.getChambers();
        assertEq(chambers, emptyArray);
    }
}
