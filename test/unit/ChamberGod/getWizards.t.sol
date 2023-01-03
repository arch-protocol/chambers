// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17.0;

import {Test} from "forge-std/Test.sol";
import {ChamberGod} from "src/ChamberGod.sol";
import {ArrayUtils} from "src/lib/ArrayUtils.sol";

contract ChamberGodUnitGetWizardsTest is Test {
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
     * [SUCCESS] Get wizards array should work with non empty array
     */
    function testGetWizardsWithNonEmptyArrayShouldWork() public {
        address[] memory wizardsArray = new address[](1);
        address wizard = vm.addr(0x123);
        wizardsArray[0] = wizard;
        vm.prank(owner);
        god.addWizard(wizard);
        address[] memory addresses = god.getWizards();
        assertEq(addresses, wizardsArray);
    }

    /**
     * [SUCCESS] Get wizards array should work with empty array
     */
    function testGetWizardsWithEmptyArrayShouldWork() public {
        address[] memory emptyArray = new address[](0);
        address[] memory addresses = god.getWizards();
        assertEq(addresses, emptyArray);
    }
}
