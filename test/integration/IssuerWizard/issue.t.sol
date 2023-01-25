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

contract IssuerWizardIntegrationIssueTest is Test {
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

    event ChamberTokenIssued(address indexed chamber, address indexed issuer, uint256 quantity);
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
        vm.label(alice, "Alice");
        vm.label(token1, "HEX");
        vm.label(token2, "YFI");
    }

    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [REVERT] Calling issue() should revert if quantity to mint is zero
     */
    function testCannotIssueQuantityZero() public {
        uint256 previousChamberSupply = IERC20(address(globalChamber)).totalSupply();
        vm.expectRevert(bytes("Quantity must be greater than 0"));

        issuerWizard.issue(IChamber(address(globalChamber)), 0);

        uint256 currentChamberSupply = IERC20(address(globalChamber)).totalSupply();
        assertEq(currentChamberSupply, previousChamberSupply);
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

        address[] memory testConstituents = new address[](1);
        testConstituents[0] = token1;
        uint256[] memory testQuantities = new uint256[](1);
        testQuantities[0] = token1Quantity;

        Chamber chamber =
            chamberFactory.getChamberWithCustomTokens(testConstituents, testQuantities);

        uint256 previousChamberBalance = IERC20(token1).balanceOf(address(chamber));
        uint256 previousChamberSupply = IERC20(address(chamber)).totalSupply();

        vm.expectCall(
            token1,
            abi.encodeCall(
                IERC20(token1).transferFrom, (alice, address(chamber), requiredToken1Collateral)
            )
        );
        vm.expectRevert();

        vm.prank(alice);
        issuerWizard.issue(IChamber(address(chamber)), quantityToMint);

        uint256 currentChamberBalance = IERC20(token1).balanceOf(address(chamber));
        uint256 currentChamberSupply = IERC20(address(chamber)).totalSupply();

        assertEq(chamber.balanceOf(alice), 0);
        assertEq(currentChamberBalance, previousChamberBalance);
        assertEq(currentChamberSupply, previousChamberSupply);
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

        address[] memory testConstituents = new address[](1);
        testConstituents[0] = token1;
        uint256[] memory testQuantities = new uint256[](1);
        testQuantities[0] = token1Quantity;

        Chamber chamber =
            chamberFactory.getChamberWithCustomTokens(testConstituents, testQuantities);

        uint256 previousChamberBalance = IERC20(token1).balanceOf(address(chamber));
        uint256 previousChamberSupply = IERC20(address(chamber)).totalSupply();
        vm.expectCall(
            token1,
            abi.encodeCall(
                IERC20(token1).transferFrom, (alice, address(chamber), requiredToken1Collateral)
            )
        );
        vm.expectRevert();

        vm.prank(alice);
        issuerWizard.issue(IChamber(address(chamber)), quantityToMint);

        uint256 currentChamberBalance = IERC20(token1).balanceOf(address(chamber));
        uint256 currentChamberSupply = IERC20(address(chamber)).totalSupply();

        assertEq(chamber.balanceOf(alice), 0);
        assertEq(currentChamberBalance, previousChamberBalance);
        assertEq(currentChamberSupply, previousChamberSupply);
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

        address[] memory testConstituents = new address[](1);
        testConstituents[0] = token1;
        uint256[] memory testQuantities = new uint256[](1);
        testQuantities[0] = token1Quantity;

        Chamber chamber =
            chamberFactory.getChamberWithCustomTokens(testConstituents, testQuantities);

        uint256 previousChamberBalance = IERC20(token1).balanceOf(address(chamber));
        uint256 previousChamberSupply = IERC20(address(chamber)).totalSupply();
        vm.expectCall(
            token1,
            abi.encodeCall(
                IERC20(token1).transferFrom, (alice, address(chamber), requiredToken1Collateral)
            )
        );
        vm.expectRevert();

        vm.prank(alice);
        issuerWizard.issue(IChamber(address(chamber)), quantityToMint);

        uint256 currentChamberBalance = IERC20(token1).balanceOf(address(chamber));
        uint256 currentChamberSupply = IERC20(address(chamber)).totalSupply();

        assertEq(chamber.balanceOf(alice), 0);
        assertEq(currentChamberBalance, previousChamberBalance);
        assertEq(currentChamberSupply, previousChamberSupply);
        assertEq(IERC20(token1).balanceOf(alice), requiredToken1Collateral - 1);
    }

    /**
     * [REVERT] Should call issue() and revert because Alice only had enough balance of token1,
     *  not token2. Approves are ok.
     */
    function testIssueWithTwoConstituientsRevertOnSecondTransferFrom(
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

        uint256[] memory testQuantities = new uint256[](2);
        testQuantities[0] = token1Quantity;
        testQuantities[1] = token2Quantity;

        Chamber chamber =
            chamberFactory.getChamberWithCustomTokens(globalConstituents, testQuantities);

        uint256 previousChamberBalanceToken1 = IERC20(token1).balanceOf(address(chamber));
        uint256 previousChamberBalanceToken2 = IERC20(token2).balanceOf(address(chamber));
        uint256 previousChamberSupply = IERC20(address(chamber)).totalSupply();

        vm.expectCall(
            token1,
            abi.encodeCall(
                IERC20(token1).transferFrom, (alice, address(chamber), requiredToken1Collateral)
            )
        );
        vm.expectEmit(true, true, false, true, token1);
        emit Transfer(alice, address(chamber), requiredToken1Collateral);
        vm.expectRevert();

        vm.prank(alice);
        issuerWizard.issue(IChamber(address(chamber)), quantityToMint);

        uint256 currentChamberBalanceToken1 = IERC20(token1).balanceOf(address(chamber));
        uint256 currentChamberBalanceToken2 = IERC20(token2).balanceOf(address(chamber));
        uint256 currentChamberSupply = IERC20(address(chamber)).totalSupply();

        assertEq(IERC20(address(chamber)).balanceOf(alice), 0);
        assertEq(currentChamberBalanceToken1, previousChamberBalanceToken1);
        assertEq(currentChamberBalanceToken2, previousChamberBalanceToken2);
        assertEq(currentChamberSupply, previousChamberSupply);
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

        address[] memory testConstituents = new address[](0);
        uint256[] memory testQuantities = new uint256[](0);

        Chamber chamber =
            chamberFactory.getChamberWithCustomTokens(testConstituents, testQuantities);

        vm.expectCall(
            address(chamber), abi.encodeCall(chamber.mint, (address(this), quantityToMint))
        );
        vm.expectEmit(true, true, true, true, address(issuerWizard));
        emit ChamberTokenIssued(address(chamber), address(this), quantityToMint);
        uint256 previousChamberSupply = IERC20(address(chamber)).totalSupply();

        issuerWizard.issue(IChamber(address(chamber)), quantityToMint);

        uint256 currentChamberSupply = IERC20(address(chamber)).totalSupply();
        uint256 thisBalance = IERC20(address(chamber)).balanceOf(address(this));

        assertEq(currentChamberSupply, previousChamberSupply + quantityToMint);
        assertEq(thisBalance, quantityToMint);
    }

    /**
     * [SUCCESS] Should mint an *infinite* quantity amount of tokens if all requiredConstituentsQuantities
     * are zero. This scenario SHOULD NEVER happen, as other contracts won't let this occur
     */
    function testIssueWithAllConstituentsQuantitiesInZero(uint256 quantityToMint) public {
        vm.assume(quantityToMint > 0);

        uint256[] memory testQuantities = new uint256[](2);
        testQuantities[0] = 0;
        testQuantities[1] = 0;

        Chamber chamber =
            chamberFactory.getChamberWithCustomTokens(globalConstituents, testQuantities);

        vm.expectCall(
            address(token1),
            abi.encodeCall(IERC20(token1).transferFrom, (address(this), address(chamber), 0))
        );
        vm.expectCall(
            address(token2),
            abi.encodeCall(IERC20(token1).transferFrom, (address(this), address(chamber), 0))
        );
        vm.expectCall(
            address(chamber), abi.encodeCall(chamber.mint, (address(this), quantityToMint))
        );
        vm.expectEmit(true, true, true, true, issuerAddress);
        emit ChamberTokenIssued(address(chamber), address(this), quantityToMint);
        uint256 previousChamberSupply = IERC20(address(chamber)).totalSupply();

        issuerWizard.issue(IChamber(address(chamber)), quantityToMint);

        uint256 currentChamberSupply = IERC20(address(chamber)).totalSupply();
        uint256 thisBalance = IERC20(address(chamber)).balanceOf(address(this));
        assertEq(currentChamberSupply, previousChamberSupply + quantityToMint);
        assertEq(thisBalance, quantityToMint);
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

        address[] memory testConstituents = new address[](1);
        testConstituents[0] = token1;
        uint256[] memory testQuantities = new uint256[](1);
        testQuantities[0] = token1Quantity;

        Chamber chamber =
            chamberFactory.getChamberWithCustomTokens(testConstituents, testQuantities);

        uint256 requiredToken1Collateral = quantityToMint.preciseMulCeil(token1Quantity, 18);
        deal(token1, alice, requiredToken1Collateral);
        vm.prank(alice);
        ERC20(token1).approve(issuerAddress, requiredToken1Collateral);

        uint256 previousChamberBalance = IERC20(token1).balanceOf(address(chamber));
        vm.expectCall(
            token1,
            abi.encodeCall(
                IERC20(token1).transferFrom, (alice, address(chamber), requiredToken1Collateral)
            )
        );
        vm.expectEmit(true, true, false, true, token1);
        emit Transfer(alice, address(chamber), requiredToken1Collateral);
        vm.expectCall(
            address(chamber),
            abi.encodeCall(IChamber(address(chamber)).mint, (alice, quantityToMint))
        );
        vm.expectEmit(true, true, true, true, issuerAddress);
        emit ChamberTokenIssued(address(chamber), alice, quantityToMint);
        uint256 previousChamberSupply = IERC20(address(chamber)).totalSupply();

        vm.prank(alice);
        issuerWizard.issue(IChamber(address(chamber)), quantityToMint);

        uint256 currentChamberBalance = IERC20(token1).balanceOf(address(chamber));
        uint256 currentChamberSupply = IERC20(address(chamber)).totalSupply();

        assertEq(currentChamberSupply, previousChamberSupply + quantityToMint);
        assertEq(chamber.balanceOf(alice), quantityToMint);
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

        uint256[] memory testQuantities = new uint256[](2);
        testQuantities[0] = token1Quantity;
        testQuantities[1] = token2Quantity;

        Chamber chamber =
            chamberFactory.getChamberWithCustomTokens(globalConstituents, testQuantities);

        uint256 requiredToken1Collateral = quantityToMint.preciseMulCeil(token1Quantity, 18);
        uint256 requiredToken2Collateral = quantityToMint.preciseMulCeil(token2Quantity, 18);
        deal(token1, alice, requiredToken1Collateral);
        deal(token2, alice, requiredToken2Collateral);
        vm.prank(alice);
        ERC20(token1).approve(issuerAddress, requiredToken1Collateral);
        vm.prank(alice);
        ERC20(token2).approve(issuerAddress, requiredToken2Collateral);
        uint256 previousToken1ChamberBalance = IERC20(token1).balanceOf(address(chamber));
        uint256 previousToken2ChamberBalance = IERC20(token2).balanceOf(address(chamber));
        uint256 previousChamberSupply = IERC20(address(chamber)).totalSupply();

        vm.expectCall(
            token1,
            abi.encodeCall(
                IERC20(token1).transferFrom, (alice, address(chamber), requiredToken1Collateral)
            )
        );
        vm.expectEmit(true, true, false, true, token1);
        emit Transfer(alice, address(chamber), requiredToken1Collateral);
        vm.expectCall(
            token2,
            abi.encodeCall(
                IERC20(token2).transferFrom, (alice, address(chamber), requiredToken2Collateral)
            )
        );
        vm.expectEmit(true, true, false, true, token2);
        emit Transfer(alice, address(chamber), requiredToken2Collateral);

        vm.expectCall(
            address(chamber),
            abi.encodeCall(IChamber(address(chamber)).mint, (alice, quantityToMint))
        );
        vm.expectEmit(true, true, true, true, issuerAddress);
        emit ChamberTokenIssued(address(chamber), alice, quantityToMint);

        vm.prank(alice);
        issuerWizard.issue(IChamber(address(chamber)), quantityToMint);

        uint256 currentToken1ChamberBalance = IERC20(token1).balanceOf(address(chamber));
        uint256 currentToken2ChamberBalance = IERC20(token2).balanceOf(address(chamber));
        uint256 currentChamberSupply = IERC20(address(chamber)).totalSupply();

        assertEq(currentChamberSupply, previousChamberSupply + quantityToMint);
        assertEq(chamber.balanceOf(alice), quantityToMint);
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
