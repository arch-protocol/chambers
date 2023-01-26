// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IChamber} from "src/interfaces/IChamber.sol";
import {IssuerWizard} from "src/IssuerWizard.sol";
import {Chamber} from "src/Chamber.sol";
import {ChamberFactory} from "test/utils/factories.sol";
import {PreciseUnitMath} from "src/lib/PreciseUnitMath.sol";

contract IssuerWizardIntegrationGetConstituentsQuantitiesForIssuanceTest is Test {
    using PreciseUnitMath for uint256;

    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/

    IssuerWizard public issuerWizard;
    ChamberFactory public chamberFactory;
    Chamber public globalChamber;
    address public issuerAddress;
    address public chamberAddress;
    address public chamberGodAddress = vm.addr(0x791782394);
    address public token1 = 0x2b591e99afE9f32eAA6214f7B7629768c40Eeb39; // HEX on ETH
    address public token2 = 0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e; // YFI on ETH
    address[] public globalConstituents = new address[](2);
    uint256[] public globalQuantities = new uint256[](2);

    event Transfer(address indexed from, address indexed to, uint256 value);

    /*//////////////////////////////////////////////////////////////
                              SET UP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        globalConstituents[0] = token1;
        globalConstituents[1] = token2;
        globalQuantities[0] = 1;
        globalQuantities[1] = 2;

        issuerWizard = new IssuerWizard(chamberGodAddress);
        issuerAddress = address(issuerWizard);

        address[] memory wizards = new address[](1);
        wizards[0] = issuerAddress;
        address[] memory managers = new address[](1);
        managers[0] = vm.addr(0x92837498ba);

        chamberFactory = new ChamberFactory(
          address(this),
          "name",
          "symbol",
          wizards,
          managers
        );

        globalChamber =
            chamberFactory.getChamberWithCustomTokens(globalConstituents, globalQuantities);

        vm.label(chamberGodAddress, "ChamberGod");
        vm.label(issuerAddress, "IssuerWizard");
        vm.label(address(globalChamber), "Chamber");
        vm.label(address(chamberFactory), "ChamberFactory");
        vm.label(token1, "HEX");
        vm.label(token2, "YFI");
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] The function getConstituentsQuantitiesForIssuance() should return
     * the correct amount of quantities
     */
    function testIssuerReturnsCorrectValuesOfQuantitiesForIssuance(
        uint256 quantityToMint,
        uint256 token1Quantity,
        uint256 token2Quantity
    ) public {
        vm.assume(quantityToMint > 0);
        vm.assume(quantityToMint < type(uint160).max);
        vm.assume(token1Quantity > 0);
        vm.assume(token1Quantity < type(uint64).max);
        vm.assume(token2Quantity > 0);
        vm.assume(token2Quantity < type(uint64).max);

        uint256[] memory testQuantities = new uint256[](2);
        testQuantities[0] = token1Quantity;
        testQuantities[1] = token2Quantity;

        Chamber chamber =
            chamberFactory.getChamberWithCustomTokens(globalConstituents, testQuantities);

        uint256[] memory expectedQuantities = new uint256[](2);
        expectedQuantities[0] = token1Quantity.preciseMulCeil(quantityToMint, 18);
        expectedQuantities[1] = token2Quantity.preciseMulCeil(quantityToMint, 18);
        uint256 previousChamberSupply = IERC20(address(chamber)).totalSupply();

        (address[] memory constituents, uint256[] memory requiredQuantities) = issuerWizard
            .getConstituentsQuantitiesForIssuance(IChamber(address(chamber)), quantityToMint);
        uint256 currentChamberSupply = IERC20(address(chamber)).totalSupply();
        uint256 thisBalance = IERC20(address(chamber)).balanceOf(address(this));

        assertEq(thisBalance, 0);
        assertEq(currentChamberSupply, previousChamberSupply);
        assertEq(requiredQuantities, expectedQuantities);
        assertEq(constituents, globalConstituents);
    }

    /**
     * [SUCCESS] The function getConstituentsQuantitiesForIssuance() should return
     * the correct amount of quantities, when quantityToMint is zero
     */
    function testIssuerReturnsCorrectValuesOfQuantitiesForIssuanceWithZeroQuantity(
        uint256 token1Quantity,
        uint256 token2Quantity
    ) public {
        vm.assume(token1Quantity > 0);
        vm.assume(token1Quantity < type(uint64).max);
        vm.assume(token2Quantity > 0);
        vm.assume(token2Quantity < type(uint64).max);

        uint256[] memory testQuantities = new uint256[](2);
        testQuantities[0] = token1Quantity;
        testQuantities[1] = token2Quantity;

        Chamber chamber =
            chamberFactory.getChamberWithCustomTokens(globalConstituents, testQuantities);

        uint256[] memory expectedQuantities = new uint256[](2);
        expectedQuantities[0] = 0;
        expectedQuantities[1] = 0;
        uint256 previousChamberSupply = IERC20(address(chamber)).totalSupply();

        (address[] memory constituents, uint256[] memory requiredQuantities) =
            issuerWizard.getConstituentsQuantitiesForIssuance(IChamber(address(chamber)), 0);
        uint256 currentChamberSupply = IERC20(address(chamber)).totalSupply();
        uint256 thisBalance = IERC20(address(chamber)).balanceOf(address(this));

        assertEq(thisBalance, 0);
        assertEq(currentChamberSupply, previousChamberSupply);
        assertEq(requiredQuantities, expectedQuantities);
        assertEq(constituents, globalConstituents);
    }

    /**
     * [SUCCESS] The function getConstituentsQuantitiesForIssuance() should return
     * empty arrays if the chamber has no contituents
     */
    function testIssuerReturnsCorrectValuesOfQuantitiesForIssuanceWithEmptyConstituents(
        uint256 quantityToMint
    ) public {
        vm.assume(quantityToMint > 0);

        address[] memory testContituents = new address[](0);
        uint256[] memory testQuantities = new uint256[](0);

        Chamber chamber = chamberFactory.getChamberWithCustomTokens(testContituents, testQuantities);

        address[] memory expectedContituents = new address[](0);
        uint256[] memory expectedQuantities = new uint256[](0);

        uint256 previousChamberSupply = IERC20(address(chamber)).totalSupply();

        (address[] memory constituents, uint256[] memory requiredQuantities) = issuerWizard
            .getConstituentsQuantitiesForIssuance(IChamber(address(chamber)), quantityToMint);
        uint256 currentChamberSupply = IERC20(address(chamber)).totalSupply();
        uint256 thisBalance = IERC20(address(chamber)).balanceOf(address(this));

        assertEq(thisBalance, 0);
        assertEq(currentChamberSupply, previousChamberSupply);
        assertEq(requiredQuantities, expectedQuantities);
        assertEq(constituents, expectedContituents);
    }
}
