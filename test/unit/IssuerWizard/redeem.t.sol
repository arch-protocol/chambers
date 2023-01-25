// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IChamber} from "src/interfaces/IChamber.sol";
import {IChamberGod} from "src/interfaces/IChamberGod.sol";
import {IIssuerWizard} from "src/interfaces/IIssuerWizard.sol";
import {IssuerWizard} from "src/IssuerWizard.sol";
import {PreciseUnitMath} from "src/lib/PreciseUnitMath.sol";

contract IssuerWizardUnitRedeemTest is Test {
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
    address[] public globalConstituents = new address[](2);
    mapping(address => uint256) public constituentQuantities;

    event ChamberTokenRedeemed(
        address indexed chamber, address indexed recipient, uint256 quantity
    );
    event Transfer(address indexed from, address indexed to, uint256 value);

    /*//////////////////////////////////////////////////////////////
                              SET UP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        issuerWizard = new IssuerWizard(chamberGodAddress);
        chamber = IChamber(chamberAddress);
        issuerAddress = address(issuerWizard);
        vm.label(chamberGodAddress, "ChamberGod");
        vm.label(issuerAddress, "IssuerWizard");
        vm.label(chamberAddress, "Chamber");
        vm.label(alice, "Alice");
        vm.label(token1, "LINK");
        vm.label(token2, "YFI");
        globalConstituents[0] = token1;
        globalConstituents[1] = token2;
        constituentQuantities[token1] = 1;
        constituentQuantities[token2] = 2;
    }

    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [REVERT] Calling redeem() should revert if the chamber is not in the chambers list at
     * chamberGod.
     */
    function testCannotIssueChamberNotCreatedByGod() public {
        vm.mockCall(
            chamberGodAddress,
            abi.encodeWithSelector(
                IChamberGod(chamberGodAddress).isChamber.selector, address(chamber)
            ),
            abi.encode(false)
        );
        vm.expectRevert(bytes("Target chamber not valid"));
        issuerWizard.redeem(IChamber(chamberAddress), 0);
    }

    /**
     * [REVERT] Calling redeem() should revert if quantity to redeem is zero
     */

    function testCannotRedeemQuantityZero() public {
        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(IERC20(address(chamber)).totalSupply.selector),
            abi.encode(0)
        );
        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(IERC20(address(chamber)).balanceOf.selector, (address(this))),
            abi.encode(0)
        );
        uint256 previousChamberSupply = IERC20(chamberAddress).totalSupply();
        uint256 previousBalance = IERC20(chamberAddress).balanceOf(address(this));
        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(IERC20(address(chamber)).balanceOf.selector, (address(this))),
            abi.encode(0)
        );
        vm.mockCall(
            chamberGodAddress,
            abi.encodeWithSelector(
                IChamberGod(chamberGodAddress).isChamber.selector, address(chamber)
            ),
            abi.encode(true)
        );
        vm.expectRevert(bytes("Quantity must be greater than 0"));

        issuerWizard.redeem(IChamber(chamberAddress), 0);

        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(IERC20(address(chamber)).totalSupply.selector),
            abi.encode(0)
        );
        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(IERC20(address(chamber)).balanceOf.selector, (address(this))),
            abi.encode(0)
        );
        uint256 currentChamberSupply = IERC20(chamberAddress).totalSupply();
        uint256 currentBalance = IERC20(chamberAddress).balanceOf(address(this));

        assertEq(currentChamberSupply, previousChamberSupply);
        assertEq(currentBalance, previousBalance);
    }

    /**
     * [REVERT] Calling redeem() should revert if quantity to redeem is more than the actual balance
     */
    function testCannotRedeemQuantityIsLessThanBalance() public {
        uint256 quantityToRedeem = 20;
        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(IERC20(address(chamber)).totalSupply.selector),
            abi.encode(0)
        );
        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(IERC20(address(chamber)).balanceOf.selector, (alice)),
            abi.encode(quantityToRedeem - 1)
        );
        uint256 previousChamberSupply = IERC20(chamberAddress).totalSupply();
        uint256 previousAliceBalance = IERC20(chamberAddress).balanceOf(alice);
        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(IERC20(address(chamber)).balanceOf.selector, (alice)),
            abi.encode(quantityToRedeem - 1)
        );
        vm.mockCall(
            chamberGodAddress,
            abi.encodeWithSelector(
                IChamberGod(chamberGodAddress).isChamber.selector, address(chamber)
            ),
            abi.encode(true)
        );
        vm.expectRevert(bytes("Not enough balance to redeem"));

        vm.prank(alice);
        issuerWizard.redeem(IChamber(chamberAddress), quantityToRedeem);

        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(IERC20(address(chamber)).totalSupply.selector),
            abi.encode(0)
        );
        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(IERC20(address(chamber)).balanceOf.selector, (alice)),
            abi.encode(quantityToRedeem - 1)
        );
        uint256 currentChamberSupply = IERC20(chamberAddress).totalSupply();
        uint256 currentAliceBalance = IERC20(chamberAddress).balanceOf(alice);

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

        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(IERC20(address(chamber)).totalSupply.selector),
            abi.encode(quantityToRedeem)
        );
        uint256 previousChamberSupply = IERC20(address(chamber)).totalSupply();

        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(IERC20(address(chamber)).balanceOf.selector, alice),
            abi.encode(quantityToRedeem)
        );
        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(chamber.burn.selector, alice, quantityToRedeem),
            abi.encode()
        );
        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(chamber.getConstituentsAddresses.selector),
            abi.encode(testConstituents)
        );
        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(ERC20(address(chamber)).decimals.selector),
            abi.encode(18)
        );
        vm.mockCall(
            chamberGodAddress,
            abi.encodeWithSelector(
                IChamberGod(chamberGodAddress).isChamber.selector, address(chamber)
            ),
            abi.encode(true)
        );
        vm.expectCall(chamberAddress, abi.encodeCall(IERC20(address(chamber)).balanceOf, (alice)));
        vm.expectCall(chamberAddress, abi.encodeCall(chamber.burn, (alice, quantityToRedeem)));
        vm.expectCall(chamberAddress, abi.encodeCall(chamber.getConstituentsAddresses, ()));
        vm.expectEmit(true, true, false, true, address(issuerWizard));
        emit ChamberTokenRedeemed(chamberAddress, alice, quantityToRedeem);

        vm.prank(alice);
        issuerWizard.redeem(chamber, quantityToRedeem);

        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(IERC20(address(chamber)).totalSupply.selector),
            abi.encode(0)
        );
        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(IERC20(address(chamber)).balanceOf.selector, alice),
            abi.encode(0)
        );
        uint256 currentChamberSupply = IERC20(chamberAddress).totalSupply();
        uint256 currentAliceBalance = IERC20(chamberAddress).balanceOf(alice);

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

        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(IERC20(address(chamber)).totalSupply.selector),
            abi.encode(quantityToRedeem)
        );
        uint256 previousChamberSupply = IERC20(address(chamber)).totalSupply();

        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(IERC20(address(chamber)).balanceOf.selector, alice),
            abi.encode(quantityToRedeem)
        );
        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(chamber.burn.selector, alice, quantityToRedeem),
            abi.encode()
        );
        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(chamber.getConstituentsAddresses.selector),
            abi.encode(globalConstituents)
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
        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(chamber.withdrawTo.selector, token1, alice, 0),
            abi.encode()
        );
        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(chamber.withdrawTo.selector, token2, alice, 0),
            abi.encode()
        );
        vm.mockCall(
            chamberGodAddress,
            abi.encodeWithSelector(
                IChamberGod(chamberGodAddress).isChamber.selector, address(chamber)
            ),
            abi.encode(true)
        );
        vm.expectCall(chamberAddress, abi.encodeCall(chamber.burn, (alice, quantityToRedeem)));
        vm.expectCall(chamberAddress, abi.encodeCall(chamber.getConstituentsAddresses, ()));
        vm.expectEmit(true, true, false, true, address(issuerWizard));
        emit ChamberTokenRedeemed(chamberAddress, alice, quantityToRedeem);

        vm.prank(alice);
        issuerWizard.redeem(IChamber(chamberAddress), quantityToRedeem);

        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(IERC20(address(chamber)).totalSupply.selector),
            abi.encode(0)
        );
        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(IERC20(address(chamber)).balanceOf.selector, alice),
            abi.encode(0)
        );
        uint256 currentChamberSupply = IERC20(chamberAddress).totalSupply();
        uint256 currentAliceBalance = IERC20(chamberAddress).balanceOf(alice);

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

        uint256 requiredToken1Collateral = quantityToRedeem.preciseMulCeil(token1Quantity, 18);
        uint256 requiredToken2Collateral = quantityToRedeem.preciseMulCeil(token2Quantity, 18);
        deal(token1, chamberAddress, requiredToken1Collateral);
        deal(token2, chamberAddress, requiredToken2Collateral);
        assertEq(IERC20(token1).balanceOf(chamberAddress), requiredToken1Collateral);
        assertEq(IERC20(token2).balanceOf(chamberAddress), requiredToken2Collateral);

        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(IERC20(address(chamber)).totalSupply.selector),
            abi.encode(quantityToRedeem)
        );
        uint256 previousChamberSupply = IERC20(address(chamber)).totalSupply();
        uint256 previousChamberToken1Balance = IERC20(token1).balanceOf(chamberAddress);
        uint256 previousChamberToken2Balance = IERC20(token2).balanceOf(chamberAddress);
        uint256 previousAliceToken1Balance = IERC20(token1).balanceOf(alice);
        uint256 previousAliceToken2Balance = IERC20(token2).balanceOf(alice);
        assertEq(previousChamberSupply, quantityToRedeem);
        assertEq(previousAliceToken1Balance, 0);
        assertEq(previousAliceToken2Balance, 0);
        assertEq(previousChamberToken1Balance, requiredToken1Collateral);
        assertEq(previousChamberToken2Balance, requiredToken2Collateral);

        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(IERC20(address(chamber)).balanceOf.selector, alice),
            abi.encode(quantityToRedeem)
        );
        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(chamber.burn.selector, alice, quantityToRedeem),
            abi.encode()
        );
        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(chamber.getConstituentsAddresses.selector),
            abi.encode(globalConstituents)
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
        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(
                chamber.withdrawTo.selector, token1, alice, requiredToken1Collateral
            ),
            abi.encode()
        );
        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(
                chamber.withdrawTo.selector, token2, alice, requiredToken2Collateral
            ),
            abi.encode()
        );
        vm.mockCall(
            chamberGodAddress,
            abi.encodeWithSelector(
                IChamberGod(chamberGodAddress).isChamber.selector, address(chamber)
            ),
            abi.encode(true)
        );
        vm.expectCall(chamberAddress, abi.encodeCall(chamber.burn, (alice, quantityToRedeem)));
        vm.expectCall(chamberAddress, abi.encodeCall(chamber.getConstituentsAddresses, ()));
        vm.expectEmit(true, true, false, true, address(issuerWizard));
        emit ChamberTokenRedeemed(chamberAddress, alice, quantityToRedeem);

        vm.prank(alice);
        issuerWizard.redeem(IChamber(chamberAddress), quantityToRedeem);
        vm.prank(chamberAddress);
        IERC20(token1).transfer(alice, requiredToken1Collateral);
        vm.prank(chamberAddress);
        IERC20(token2).transfer(alice, requiredToken2Collateral);

        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(IERC20(address(chamber)).totalSupply.selector),
            abi.encode(0)
        );
        uint256 currentChamberSupply = IERC20(address(chamber)).totalSupply();
        uint256 currentChamberToken1Balance = IERC20(token1).balanceOf(chamberAddress);
        uint256 currentChamberToken2Balance = IERC20(token2).balanceOf(chamberAddress);
        uint256 currentAliceToken1Balance = IERC20(token1).balanceOf(alice);
        uint256 currentAliceToken2Balance = IERC20(token2).balanceOf(alice);
        assertEq(currentChamberSupply, 0);
        assertEq(currentAliceToken1Balance, requiredToken1Collateral);
        assertEq(currentAliceToken2Balance, requiredToken2Collateral);
        assertEq(currentChamberToken1Balance, 0);
        assertEq(currentChamberToken2Balance, 0);
    }
}
