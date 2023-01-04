// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IChamber} from "../../../src/interfaces/IChamber.sol";
import {IssuerWizard} from "../../../src/IssuerWizard.sol";
import {Chamber} from "../../../src/Chamber.sol";
import {ChamberFactory} from "../../utils/factories.sol";
import {PreciseUnitMath} from "../../../src/lib/PreciseUnitMath.sol";

contract IssuerWizardIntegrationRedeemTest is Test {
    using PreciseUnitMath for uint256;

    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/

    IssuerWizard public issuerWizard;
    ChamberFactory public chamberFactory;
    Chamber public globalChamber;
    address public alice = vm.addr(0xe87809df12a1);
    address public issuerAddress;
    address public chamberAddress;
    address public chamberGodAddress = vm.addr(0x791782394);
    address public token1 = 0x2b591e99afE9f32eAA6214f7B7629768c40Eeb39; // HEX on ETH
    address public token2 = 0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e; // YFI on ETH
    address[] public globalConstituents = new address[](2);
    uint256[] public globalQuantities = new uint256[](2);

    event ChamberTokenRedeemed(
        address indexed chamber, address indexed recipient, uint256 quantity
    );
    event Transfer(address indexed from, address indexed to, uint256 value);

    /*//////////////////////////////////////////////////////////////
                              SET UP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        globalConstituents[0] = token1;
        globalConstituents[1] = token2;
        globalQuantities[0] = 1;
        globalQuantities[1] = 2;

        issuerWizard = new IssuerWizard();
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
        vm.label(alice, "Alice");
        vm.label(token1, "HEX");
        vm.label(token2, "YFI");
    }

    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [REVERT] Calling redeem() should revert if quantity to redeem is zero
     */
    function testCannotRedeemQuantityZero() public {
        uint256 previousChamberSupply = IERC20(address(globalChamber)).totalSupply();
        uint256 previousBalance = IERC20(address(globalChamber)).balanceOf(address(this));
        vm.expectRevert(bytes("Quantity must be greater than 0"));

        issuerWizard.redeem(IChamber(address(globalChamber)), 0);

        uint256 currentChamberSupply = IERC20(address(globalChamber)).totalSupply();
        uint256 currentBalance = IERC20(address(globalChamber)).balanceOf(address(this));

        assertEq(currentChamberSupply, previousChamberSupply);
        assertEq(currentBalance, previousBalance);
    }

    /**
     * [REVERT] Calling redeem() should revert if quantity to redeem is more than the actual balance
     */
    function testCannotRedeemQuantityIsLessThanBalance() public {
        uint256 quantityToRedeem = 20;
        deal(address(globalChamber), alice, quantityToRedeem - 1); // 1 Token missing

        uint256 previousChamberSupply = IERC20(address(globalChamber)).totalSupply();
        uint256 previousAliceBalance = IERC20(address(globalChamber)).balanceOf(alice);
        vm.expectRevert(bytes("Not enough balance to redeem"));

        vm.prank(alice);
        issuerWizard.redeem(IChamber(address(globalChamber)), quantityToRedeem);

        uint256 currentChamberSupply = IERC20(address(globalChamber)).totalSupply();
        uint256 currentAliceBalance = IERC20(address(globalChamber)).balanceOf(alice);

        assertEq(currentChamberSupply, previousChamberSupply);
        assertEq(currentAliceBalance, previousAliceBalance);
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCESS] Should burn an *infinite* amount of tokens without receiving any constituents,
     * when the constituents list in the chamber is empty. This scenario should not occur thanks
     * to validations in other contracts.
     */
    function testRedeemBurnInfiniteTokensWithEmptyContituents(uint256 quantityToRedeem) public {
        vm.assume(quantityToRedeem > 0);
        address[] memory testConstituents = new address[](0);
        uint256[] memory testQuantities = new uint256[](0);

        Chamber chamber =
            chamberFactory.getChamberWithCustomTokens(testConstituents, testQuantities);
        vm.prank(alice);
        issuerWizard.issue(IChamber(address(chamber)), quantityToRedeem);
        uint256 previousChamberSupply = chamber.totalSupply();

        vm.expectCall(address(chamber), abi.encodeCall(chamber.burn, (alice, quantityToRedeem)));
        vm.expectCall(address(chamber), abi.encodeCall(chamber.getConstituentsAddresses, ()));
        vm.expectEmit(true, true, false, true, address(chamber));
        emit Transfer(alice, address(0x0), quantityToRedeem);
        vm.expectEmit(true, true, false, true, address(issuerWizard));
        emit ChamberTokenRedeemed(address(chamber), alice, quantityToRedeem);
        vm.prank(alice);
        issuerWizard.redeem(IChamber(address(chamber)), quantityToRedeem);

        uint256 currentChamberSupply = IERC20(address(chamber)).totalSupply();
        uint256 currentAliceBalance = IERC20(address(chamber)).balanceOf(alice);

        assertEq(currentChamberSupply, previousChamberSupply - quantityToRedeem);
        assertEq(currentAliceBalance, 0);
    }

    /**
     * [SUCESS] Should burn an *infinite* amount of tokens without receiving any constituents,
     * when all constituents have zero as quantity. This scenario should not occur thanks
     * to validations in other contracts.
     */
    function testRedeemBurnInfiniteTokensWithZeroQuantityInContituents(uint256 quantityToRedeem)
        public
    {
        vm.assume(quantityToRedeem > 0);
        uint256[] memory testQuantities = new uint256[](2);
        testQuantities[0] = 0;
        testQuantities[1] = 0;

        Chamber chamber =
            chamberFactory.getChamberWithCustomTokens(globalConstituents, testQuantities);
        vm.prank(alice);
        issuerWizard.issue(IChamber(address(chamber)), quantityToRedeem);
        uint256 previousChamberSupply = chamber.totalSupply();

        vm.expectCall(address(chamber), abi.encodeCall(chamber.burn, (alice, quantityToRedeem)));
        vm.expectCall(address(chamber), abi.encodeCall(chamber.getConstituentsAddresses, ()));
        vm.expectEmit(true, true, false, true, address(chamber));
        emit Transfer(alice, address(0x0), quantityToRedeem);
        vm.expectEmit(true, true, false, true, address(issuerWizard));
        emit ChamberTokenRedeemed(address(chamber), alice, quantityToRedeem);
        vm.prank(alice);
        issuerWizard.redeem(IChamber(address(chamber)), quantityToRedeem);

        uint256 currentChamberSupply = IERC20(address(chamber)).totalSupply();
        uint256 currentAliceBalance = IERC20(address(chamber)).balanceOf(alice);

        assertEq(currentChamberSupply, previousChamberSupply - quantityToRedeem);
        assertEq(currentAliceBalance, 0);
    }

    /**
     * [SUCCESS] Should return the constituents to the msg.sender when the redeem() function
     * is executed under normal circumstances.
     */
    function testRedeemWithTwoConstituents(
        uint256 quantityToRedeem,
        uint256 token1Quantity,
        uint256 token2Quantity
    ) public {
        vm.assume(quantityToRedeem > 0);
        vm.assume(quantityToRedeem < type(uint160).max);
        vm.assume(token1Quantity > 0);
        vm.assume(token1Quantity < type(uint64).max);
        vm.assume(token2Quantity > 0);
        vm.assume(token2Quantity < type(uint64).max);

        uint256[] memory testQuantities = new uint256[](2);
        testQuantities[0] = token1Quantity;
        testQuantities[1] = token2Quantity;
        uint256 requiredToken1Collateral = quantityToRedeem.preciseMulCeil(token1Quantity, 18);
        uint256 requiredToken2Collateral = quantityToRedeem.preciseMulCeil(token2Quantity, 18);
        deal(token1, alice, requiredToken1Collateral);
        deal(token2, alice, requiredToken2Collateral);
        assertEq(IERC20(token1).balanceOf(address(alice)), requiredToken1Collateral);
        assertEq(IERC20(token2).balanceOf(address(alice)), requiredToken2Collateral);

        Chamber chamber =
            chamberFactory.getChamberWithCustomTokens(globalConstituents, testQuantities);
        vm.prank(alice);
        ERC20(token1).approve(issuerAddress, requiredToken1Collateral);
        vm.prank(alice);
        ERC20(token2).approve(issuerAddress, requiredToken2Collateral);
        vm.prank(alice);
        issuerWizard.issue(IChamber(address(chamber)), quantityToRedeem);
        uint256 previousChamberSupply = chamber.totalSupply();
        uint256 previousChamberToken1Balance = IERC20(token1).balanceOf(address(chamber));
        uint256 previousChamberToken2Balance = IERC20(token2).balanceOf(address(chamber));
        uint256 previousAliceToken1Balance = IERC20(token1).balanceOf(address(alice));
        uint256 previousAliceToken2Balance = IERC20(token2).balanceOf(address(alice));
        assertEq(previousChamberSupply, quantityToRedeem);
        assertEq(previousAliceToken1Balance, 0);
        assertEq(previousAliceToken2Balance, 0);
        assertEq(previousChamberToken1Balance, requiredToken1Collateral);
        assertEq(previousChamberToken2Balance, requiredToken2Collateral);
        vm.expectEmit(true, true, false, true, address(chamber));
        emit Transfer(alice, address(0x0), quantityToRedeem);
        vm.expectEmit(true, true, false, true, token1);
        emit Transfer(address(chamber), alice, requiredToken1Collateral);
        vm.expectEmit(true, true, false, true, token2);
        emit Transfer(address(chamber), alice, requiredToken2Collateral);
        vm.expectEmit(true, true, false, true, address(issuerWizard));
        emit ChamberTokenRedeemed(address(chamber), alice, quantityToRedeem);

        vm.prank(alice);
        issuerWizard.redeem(IChamber(address(chamber)), quantityToRedeem);

        uint256 currentChamberSupply = chamber.totalSupply();
        uint256 currentChamberToken1Balance = IERC20(token1).balanceOf(address(chamber));
        uint256 currentChamberToken2Balance = IERC20(token2).balanceOf(address(chamber));
        uint256 currentAliceToken1Balance = IERC20(token1).balanceOf(address(alice));
        uint256 currentAliceToken2Balance = IERC20(token2).balanceOf(address(alice));
        assertEq(currentChamberSupply, 0);
        assertEq(currentAliceToken1Balance, requiredToken1Collateral);
        assertEq(currentAliceToken2Balance, requiredToken2Collateral);
        assertEq(currentChamberToken1Balance, 0);
        assertEq(currentChamberToken2Balance, 0);
    }
}
