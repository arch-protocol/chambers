// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IChamber} from "src/interfaces/IChamber.sol";
import {IIssuerWizard} from "src/interfaces/IIssuerWizard.sol";
import {IssuerWizard} from "src/IssuerWizard.sol";
import {PreciseUnitMath} from "src/lib/PreciseUnitMath.sol";

contract IssuerWizardUnitIssueTest is Test {
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

    event ChamberTokenIssued(address indexed chamber, address indexed recipient, uint256 quantity);
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
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [REVERT] Calling issue() should revert if quantity is zero
     */
    function testCannotIssueQuantityZero() public {
        vm.expectRevert(bytes("Quantity must be greater than 0"));
        issuerWizard.issue(IChamber(chamberAddress), 0);
    }

    /**
     * [REVERT] Should call issue() and revert the call because Alice did not approve the issuerWizard to
     * transfer her tokens to the chamber before. Only one token is tested.
     */
    function testCannotIssueTokenNotApprovedBefore(uint256 quantityToMint, uint256 token1Quantity)
        public
    {
        vm.assume(quantityToMint > 0);
        vm.assume(quantityToMint < type(uint160).max);
        vm.assume(token1Quantity > 0);
        vm.assume(token1Quantity < type(uint64).max);
        uint256 requiredToken1Collateral = quantityToMint.preciseMulCeil(token1Quantity, 18);
        deal(token1, alice, requiredToken1Collateral);
        // Missing approve [here]

        address[] memory constituentsAddresses = new address[](1);
        constituentsAddresses[0] = token1;
        uint256 previousChamberBalance = IERC20(token1).balanceOf(chamberAddress);
        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(chamber.getConstituentsAddresses.selector),
            abi.encode(constituentsAddresses)
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
        vm.expectCall(
            token1,
            abi.encodeCall(
                IERC20(token1).transferFrom, (alice, chamberAddress, requiredToken1Collateral)
            )
        );
        vm.expectRevert();

        vm.prank(alice);
        issuerWizard.issue(IChamber(chamberAddress), quantityToMint);

        uint256 currentChamberBalance = IERC20(token1).balanceOf(chamberAddress);
        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(IERC20(address(chamber)).balanceOf.selector, alice),
            abi.encode(0)
        );
        assertEq(IERC20(address(chamber)).balanceOf(alice), 0);
        assertEq(currentChamberBalance, previousChamberBalance);
        assertEq(IERC20(token1).balanceOf(alice), requiredToken1Collateral);
    }

    /**
     * [REVERT] Should call issue() and revert the call because Alice did not approve the issuerWizard with
     * the minimum amount required to perform the mint. She has the balance, but the approve is not enough.
     */
    function testCannotIssueTokenNotApprovedWithRequiredAmount(
        uint256 quantityToMint,
        uint256 token1Quantity
    ) public {
        vm.assume(quantityToMint > 0);
        vm.assume(quantityToMint < type(uint160).max);
        vm.assume(token1Quantity > 0);
        vm.assume(token1Quantity < type(uint64).max);
        uint256 requiredToken1Collateral = quantityToMint.preciseMulCeil(token1Quantity, 18);
        deal(token1, alice, requiredToken1Collateral);
        vm.prank(alice);
        ERC20(token1).approve(issuerAddress, requiredToken1Collateral - 1); // 1 token1 is missing

        address[] memory constituentsAddresses = new address[](1);
        constituentsAddresses[0] = token1;
        uint256 previousChamberBalance = IERC20(token1).balanceOf(chamberAddress);
        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(chamber.getConstituentsAddresses.selector),
            abi.encode(constituentsAddresses)
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
        vm.expectCall(
            token1,
            abi.encodeCall(
                IERC20(token1).transferFrom, (alice, chamberAddress, requiredToken1Collateral)
            )
        );
        vm.expectRevert();

        vm.prank(alice);
        issuerWizard.issue(IChamber(chamberAddress), quantityToMint);

        uint256 currentChamberBalance = IERC20(token1).balanceOf(chamberAddress);
        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(IERC20(address(chamber)).balanceOf.selector, alice),
            abi.encode(0)
        );
        assertEq(IERC20(address(chamber)).balanceOf(alice), 0);
        assertEq(currentChamberBalance, previousChamberBalance);
        assertEq(IERC20(token1).balanceOf(alice), requiredToken1Collateral);
    }

    /**
     * [REVERT] Should call issue() and revert the call because Alice doesn't have enough balance in a token,
     * so she cannot mint the quantity specified.
     */
    function testCannotIssueNotEnoughBalanceFromSenderInAToken(
        uint256 quantityToMint,
        uint256 token1Quantity
    ) public {
        vm.assume(quantityToMint > 0);
        vm.assume(quantityToMint < type(uint160).max);
        vm.assume(token1Quantity > 0);
        vm.assume(token1Quantity < type(uint64).max);
        uint256 requiredToken1Collateral = quantityToMint.preciseMulCeil(token1Quantity, 18);
        deal(token1, alice, requiredToken1Collateral - 1); // 1 token1 missing
        vm.prank(alice);
        ERC20(token1).approve(issuerAddress, type(uint64).max); // Infinite approve

        address[] memory constituentsAddresses = new address[](1);
        constituentsAddresses[0] = token1;
        uint256 previousChamberBalance = IERC20(token1).balanceOf(chamberAddress);
        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(chamber.getConstituentsAddresses.selector),
            abi.encode(constituentsAddresses)
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
        vm.expectCall(
            token1,
            abi.encodeCall(
                IERC20(token1).transferFrom, (alice, chamberAddress, requiredToken1Collateral)
            )
        );
        vm.expectRevert();

        vm.prank(alice);
        issuerWizard.issue(IChamber(chamberAddress), quantityToMint);

        uint256 currentChamberBalance = IERC20(token1).balanceOf(chamberAddress);
        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(IERC20(address(chamber)).balanceOf.selector, alice),
            abi.encode(0)
        );
        assertEq(IERC20(address(chamber)).balanceOf(alice), 0);
        assertEq(currentChamberBalance, previousChamberBalance);
        assertEq(IERC20(token1).balanceOf(alice), requiredToken1Collateral - 1);
    }

    /**
     * [REVERT] Should call issue() and revert because Alice only had enough balance of token1,
     *  not token2. Approves are ok.
     */
    function testCannotIssueWithTwoConstituientsRevertOnSecondTransferFrom(
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
        uint256 requiredToken1Collateral = quantityToMint.preciseMulCeil(token1Quantity, 18);
        uint256 requiredToken2Collateral = quantityToMint.preciseMulCeil(token2Quantity, 18);
        deal(token1, alice, requiredToken1Collateral);
        deal(token2, alice, requiredToken2Collateral - 1); // 1 token2 missing
        vm.prank(alice);
        ERC20(token1).approve(issuerAddress, requiredToken1Collateral);
        vm.prank(alice);
        ERC20(token2).approve(issuerAddress, requiredToken2Collateral);
        uint256 previousToken1ChamberBalance = IERC20(token1).balanceOf(chamberAddress);
        uint256 previousToken2ChamberBalance = IERC20(token2).balanceOf(chamberAddress);

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
        vm.expectCall(
            token1,
            abi.encodeCall(
                IERC20(token1).transferFrom, (alice, chamberAddress, requiredToken1Collateral)
            )
        );
        vm.expectEmit(true, true, false, true, token1);
        emit Transfer(alice, chamberAddress, requiredToken1Collateral);
        vm.expectRevert();

        vm.prank(alice);
        issuerWizard.issue(IChamber(chamberAddress), quantityToMint);

        uint256 currentToken1ChamberBalance = IERC20(token1).balanceOf(chamberAddress);
        uint256 currentToken2ChamberBalance = IERC20(token2).balanceOf(chamberAddress);
        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(IERC20(address(chamber)).balanceOf.selector, alice),
            abi.encode(0)
        );
        assertEq(IERC20(address(chamber)).balanceOf(alice), 0);
        assertEq(currentToken1ChamberBalance, previousToken1ChamberBalance);
        assertEq(currentToken2ChamberBalance, previousToken2ChamberBalance);
        assertEq(IERC20(token1).balanceOf(alice), requiredToken1Collateral);
        assertEq(IERC20(token2).balanceOf(alice), requiredToken2Collateral - 1);
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should mint an *infinite* quantity amount of tokens if there are no constituents.
     * This scenario SHOULD NEVER happen, as other contracts won't let this occur
     */
    function testIssueWithZeroComponents(uint256 quantityToMint) public {
        vm.assume(quantityToMint > 0);
        address[] memory emptyArray = new address[](0);
        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(chamber.getConstituentsAddresses.selector),
            abi.encode(emptyArray)
        );
        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(ERC20(address(chamber)).decimals.selector),
            abi.encode(18)
        );
        vm.expectCall(chamberAddress, abi.encodeCall(chamber.mint, (address(this), quantityToMint)));
        vm.expectEmit(true, true, true, true, address(issuerWizard));
        emit ChamberTokenIssued(chamberAddress, address(this), quantityToMint);

        issuerWizard.issue(IChamber(chamberAddress), quantityToMint);
    }

    /**
     * [SUCCESS] Should mint an *infinite* quantity amount of tokens if all requiredConstituentsQuantities
     * are zero. This scenario SHOULD NEVER happen, as other contracts won't let this occur
     */
    function testIssueWithAllConstituentsQuantitiesInZero(uint256 quantityToMint) public {
        vm.assume(quantityToMint > 0);
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
            abi.encode(0)
        );
        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(chamber.getConstituentQuantity.selector, token2),
            abi.encode(0)
        );
        vm.expectCall(
            address(token1),
            abi.encodeCall(IERC20(token1).transferFrom, (address(this), chamberAddress, 0))
        );
        vm.expectCall(
            address(token2),
            abi.encodeCall(IERC20(token2).transferFrom, (address(this), chamberAddress, 0))
        );
        vm.expectCall(chamberAddress, abi.encodeCall(chamber.mint, (address(this), quantityToMint)));
        vm.expectEmit(true, true, true, true, issuerAddress);
        emit ChamberTokenIssued(chamberAddress, address(this), quantityToMint);
        issuerWizard.issue(IChamber(chamberAddress), quantityToMint);
    }

    /**
     * [SUCCESS] Should call issue() and mint the correct quantity of tokens to Alice, when she has the collateral,
     * and previously approved the issuerWizard to transfer her tokens. Only one constituent is tested
     */
    function testIssueWithOneConstituient(uint256 quantityToMint, uint256 token1Quantity) public {
        vm.assume(quantityToMint > 0);
        vm.assume(quantityToMint < type(uint160).max);
        vm.assume(token1Quantity > 0);
        vm.assume(token1Quantity < type(uint64).max);
        uint256 requiredToken1Collateral = quantityToMint.preciseMulCeil(token1Quantity, 18);
        deal(token1, alice, requiredToken1Collateral);
        vm.prank(alice);
        ERC20(token1).approve(issuerAddress, requiredToken1Collateral);
        address[] memory constituentsAddresses = new address[](1);
        constituentsAddresses[0] = token1;
        uint256 previousChamberBalance = IERC20(token1).balanceOf(chamberAddress);

        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(chamber.getConstituentsAddresses.selector),
            abi.encode(constituentsAddresses)
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
        vm.expectCall(
            token1,
            abi.encodeCall(
                IERC20(token1).transferFrom, (alice, chamberAddress, requiredToken1Collateral)
            )
        );
        vm.expectEmit(true, true, false, true, token1);
        emit Transfer(alice, chamberAddress, requiredToken1Collateral);
        vm.expectCall(
            chamberAddress, abi.encodeCall(IChamber(chamberAddress).mint, (alice, quantityToMint))
        );
        vm.expectEmit(true, true, true, true, issuerAddress);
        emit ChamberTokenIssued(chamberAddress, alice, quantityToMint);

        vm.prank(alice);
        issuerWizard.issue(IChamber(chamberAddress), quantityToMint);

        uint256 currentChamberBalance = IERC20(token1).balanceOf(chamberAddress);
        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(IERC20(address(chamber)).balanceOf.selector, alice),
            abi.encode(quantityToMint)
        );
        assertEq(IERC20(address(chamber)).balanceOf(alice), quantityToMint);
        assertEq(currentChamberBalance, previousChamberBalance + requiredToken1Collateral);
        assertEq(IERC20(token1).balanceOf(alice), 0);
    }

    /**
     * [SUCCESS] Should call issue() and mint the correct quantity of tokens to Alice, when she has the collateral,
     * and previously approved the issuerWizard to transfer her tokens. Two tokens are tested
     */
    function testIssueWithTwoConstituients(
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
        uint256 requiredToken1Collateral = quantityToMint.preciseMulCeil(token1Quantity, 18);
        uint256 requiredToken2Collateral = quantityToMint.preciseMulCeil(token2Quantity, 18);
        deal(token1, alice, requiredToken1Collateral);
        deal(token2, alice, requiredToken2Collateral);
        vm.prank(alice);
        ERC20(token1).approve(issuerAddress, requiredToken1Collateral);
        vm.prank(alice);
        ERC20(token2).approve(issuerAddress, requiredToken2Collateral);
        uint256 previousToken1ChamberBalance = IERC20(token1).balanceOf(chamberAddress);
        uint256 previousToken2ChamberBalance = IERC20(token2).balanceOf(chamberAddress);

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
        vm.expectCall(
            token1,
            abi.encodeCall(
                IERC20(token1).transferFrom, (alice, chamberAddress, requiredToken1Collateral)
            )
        );
        vm.expectEmit(true, true, false, true, token1);
        emit Transfer(alice, chamberAddress, requiredToken1Collateral);
        vm.expectCall(
            token2,
            abi.encodeCall(
                IERC20(token2).transferFrom, (alice, chamberAddress, requiredToken2Collateral)
            )
        );
        vm.expectEmit(true, true, false, true, token2);
        emit Transfer(alice, chamberAddress, requiredToken2Collateral);
        vm.expectCall(
            chamberAddress, abi.encodeCall(IChamber(chamberAddress).mint, (alice, quantityToMint))
        );
        vm.expectEmit(true, true, true, true, issuerAddress);
        emit ChamberTokenIssued(chamberAddress, alice, quantityToMint);

        vm.prank(alice);
        issuerWizard.issue(IChamber(chamberAddress), quantityToMint);

        uint256 currentToken1ChamberBalance = IERC20(token1).balanceOf(chamberAddress);
        uint256 currentToken2ChamberBalance = IERC20(token2).balanceOf(chamberAddress);
        vm.mockCall(
            chamberAddress,
            abi.encodeWithSelector(IERC20(address(chamber)).balanceOf.selector, alice),
            abi.encode(quantityToMint)
        );
        assertEq(IERC20(address(chamber)).balanceOf(alice), quantityToMint);
        assertEq(
            currentToken1ChamberBalance, previousToken1ChamberBalance + requiredToken1Collateral
        );
        assertEq(
            currentToken2ChamberBalance, previousToken2ChamberBalance + requiredToken2Collateral
        );
        assertEq(IERC20(token1).balanceOf(alice), 0);
        assertEq(IERC20(token2).balanceOf(alice), 0);
    }
}
