// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IChamber} from "src/interfaces/IChamber.sol";
import {IssuerWizard} from "src/IssuerWizard.sol";
import {PreciseUnitMath} from "src/lib/PreciseUnitMath.sol";

contract IssuerWizardUnitGetConstituentsQuantitiesForIssuanceTest is Test {
    using PreciseUnitMath for uint256;

    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/

    IChamber public chamber;
    IssuerWizard public issuerWizard;
    address public alice = vm.addr(0xe87809df12a1);
    address public issuerAddress;
    address public chamberAddress = vm.addr(0x827298ab928374ab);
    address public chamberGodAddress = vm.addr(0x791782394);
    address public token1 = 0x2b591e99afE9f32eAA6214f7B7629768c40Eeb39; // HEX on ETH
    address public token2 = 0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e; // YFI on ETH
    address[] public addresses = new address[](2);
    mapping(address => uint256) public constituentQuantities;

    event Transfer(address indexed from, address indexed to, uint256 value);

    /*//////////////////////////////////////////////////////////////
                              SET UP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        issuerWizard = new IssuerWizard();
        chamber = IChamber(chamberAddress);
        issuerAddress = address(issuerWizard);
        vm.label(chamberGodAddress, "ChamberGod");
        vm.label(issuerAddress, "IssuerWizard");
        vm.label(chamberAddress, "Chamber");
        vm.label(alice, "Alice");
        vm.label(token1, "LINK");
        vm.label(token2, "YFI");
        addresses[0] = token1;
        addresses[1] = token2;
        constituentQuantities[token1] = 1;
        constituentQuantities[token2] = 2;
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Mock call to Chamber interface getConstituentsAddresses() should work
     */
    function testIssuerReturnsCorrectConstituentsAddresses() public {
        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(IChamber.getConstituentsAddresses.selector),
            abi.encode(addresses)
        );
        address[] memory result = chamber.getConstituentsAddresses();
        assertEq(result, addresses);
    }

    /**
     * [SUCCESS] Mock call to Chamber interface getConstituentQuantity() should work
     */
    function testIssuerReturnsCorrectConstituentQuantityForAddress() public {
        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(IChamber.getConstituentQuantity.selector, token1),
            abi.encode(1)
        );
        assertEq(chamber.getConstituentQuantity(token1), 1);
    }

    /**
     * [SUCCESS] The function getConstituentsQuantitiesForIssuance() should return the correct amount
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
        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(chamber.getConstituentsAddresses.selector),
            abi.encode(addresses)
        );
        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(ERC20(address(chamber)).decimals.selector),
            abi.encode(18)
        );
        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(chamber.getConstituentQuantity.selector, token1),
            abi.encode(token1Quantity)
        );
        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(chamber.getConstituentQuantity.selector, token2),
            abi.encode(token2Quantity)
        );
        uint256[] memory expectedQuantities = new uint256[](2);
        expectedQuantities[0] = token1Quantity.preciseMulCeil(quantityToMint, 18);
        expectedQuantities[1] = token2Quantity.preciseMulCeil(quantityToMint, 18);
        (address[] memory constituents, uint256[] memory requiredQuantities) = issuerWizard
            .getConstituentsQuantitiesForIssuance(IChamber(chamberAddress), quantityToMint);
        assertEq(requiredQuantities, expectedQuantities);
        assertEq(constituents, addresses);
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

        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(chamber.getConstituentsAddresses.selector),
            abi.encode(addresses)
        );
        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(ERC20(address(chamber)).decimals.selector),
            abi.encode(18)
        );
        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(chamber.getConstituentQuantity.selector, token1),
            abi.encode(token1Quantity)
        );
        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(chamber.getConstituentQuantity.selector, token2),
            abi.encode(token2Quantity)
        );

        uint256[] memory expectedQuantities = new uint256[](2);
        expectedQuantities[0] = 0;
        expectedQuantities[1] = 0;

        (address[] memory constituents, uint256[] memory requiredQuantities) =
            issuerWizard.getConstituentsQuantitiesForIssuance(IChamber(chamberAddress), 0);

        assertEq(requiredQuantities, expectedQuantities);
        assertEq(constituents, addresses);
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

        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(chamber.getConstituentsAddresses.selector),
            abi.encode(testContituents)
        );
        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(ERC20(address(chamber)).decimals.selector),
            abi.encode(18)
        );
        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(chamber.getConstituentQuantity.selector, token1),
            abi.encode(0)
        );
        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(chamber.getConstituentQuantity.selector, token2),
            abi.encode(0)
        );

        address[] memory expectedContituents = new address[](0);
        uint256[] memory expectedQuantities = new uint256[](0);

        (address[] memory constituents, uint256[] memory requiredQuantities) = issuerWizard
            .getConstituentsQuantitiesForIssuance(IChamber(chamberAddress), quantityToMint);

        assertEq(requiredQuantities, expectedQuantities);
        assertEq(constituents, expectedContituents);
    }
}
