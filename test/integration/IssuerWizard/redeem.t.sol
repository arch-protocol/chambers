// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IChamber} from "src/interfaces/IChamber.sol";
import {IssuerWizard} from "src/IssuerWizard.sol";
import {Chamber} from "src/Chamber.sol";
import {ChamberGod} from "src/ChamberGod.sol";
import {PreciseUnitMath} from "src/lib/PreciseUnitMath.sol";

contract IssuerWizardIntegrationRedeemTest is Test {
    using PreciseUnitMath for uint256;

    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/

    IssuerWizard public issuerWizard;
    Chamber public globalChamber;
    ChamberGod public chamberGod;
    address public alice = vm.addr(0xe87809df12a1);
    address public issuerAddress;
    address public chamberAddress;
    address public chamberGodAddress = address(chamberGod);
    address public token1 = 0x2b591e99afE9f32eAA6214f7B7629768c40Eeb39; // HEX on ETH
    address public token2 = 0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e; // YFI on ETH
    address public usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC on ETH
    address[] public globalConstituents = new address[](2);
    uint256[] public globalQuantities = new uint256[](2);
    address[] public wizards = new address[](1);
    address[] public managers = new address[](1);

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
        chamberGod = new ChamberGod();
        issuerWizard = new IssuerWizard(address(chamberGod));
        issuerAddress = address(issuerWizard);

        chamberGod.addWizard(issuerAddress);

        wizards[0] = issuerAddress;
        managers[0] = vm.addr(0x92837498ba);

        globalChamber = Chamber(
            chamberGod.createChamber(
                "name", "symbol", globalConstituents, globalQuantities, wizards, managers
            )
        );

        vm.label(chamberGodAddress, "ChamberGod");
        vm.label(issuerAddress, "IssuerWizard");
        vm.label(address(globalChamber), "Chamber");
        vm.label(alice, "Alice");
        vm.label(token1, "HEX");
        vm.label(token2, "YFI");
    }

    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [REVERT] Calling redeem() should revert if chamber has not been created by ChamberGod
     */
    function testCannotIssueChamberNotCreatedByGod() public {
        address fakeChamber = vm.addr(0x123456);
        uint256 previousChamberSupply = IERC20(address(globalChamber)).totalSupply();
        vm.expectRevert(bytes("Chamber invalid"));

        issuerWizard.redeem(IChamber(address(fakeChamber)), 0);

        uint256 currentChamberSupply = IERC20(address(globalChamber)).totalSupply();
        assertEq(currentChamberSupply, previousChamberSupply);
    }

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

    /**
     * [REVERT] Should revert because the amount of redemption is not enough to get at least 1 wei of
     * some constituent out of the chamber
     */
    function testCannotRedeemWithTwoConstituentsWhenAmountIsTooLow(
        uint256 quantityToRedeem,
        uint256 token1Quantity,
        uint256 token2Quantity
    ) public {
        vm.assume(token1Quantity > 0);
        vm.assume(token1Quantity < 1 ether);
        vm.assume(token2Quantity > 0);
        vm.assume(token2Quantity < 1 ether);
        vm.assume(quantityToRedeem > 0);
        vm.assume(quantityToRedeem < 1 ether / token1Quantity);
        vm.assume(quantityToRedeem < 1 ether / token2Quantity);

        uint256[] memory testQuantities = new uint256[](2);
        testQuantities[0] = token1Quantity;
        testQuantities[1] = token2Quantity;
        uint256 requiredToken1Collateral = quantityToRedeem.preciseMulCeil(token1Quantity, 18);
        uint256 requiredToken2Collateral = quantityToRedeem.preciseMulCeil(token2Quantity, 18);
        deal(token1, alice, requiredToken1Collateral);
        deal(token2, alice, requiredToken2Collateral);
        assertEq(IERC20(token1).balanceOf(address(alice)), requiredToken1Collateral);
        assertEq(IERC20(token2).balanceOf(address(alice)), requiredToken2Collateral);

        Chamber chamber = Chamber(
            chamberGod.createChamber(
                "name", "symbol", globalConstituents, testQuantities, wizards, managers
            )
        );
        vm.prank(alice);
        ERC20(token1).approve(issuerAddress, requiredToken1Collateral);
        vm.prank(alice);
        ERC20(token2).approve(issuerAddress, requiredToken2Collateral);

        vm.prank(alice);
        issuerWizard.issue(IChamber(address(chamber)), quantityToRedeem);

        assertEq(chamber.totalSupply(), quantityToRedeem);
        assertEq(IERC20(token1).balanceOf(address(alice)), 0);
        assertEq(IERC20(token2).balanceOf(address(alice)), 0);
        assertEq(IERC20(token1).balanceOf(address(chamber)), requiredToken1Collateral);
        assertEq(IERC20(token2).balanceOf(address(chamber)), requiredToken2Collateral);

        vm.prank(alice);
        vm.expectRevert(bytes("Redeem amount too low"));
        issuerWizard.redeem(IChamber(address(chamber)), quantityToRedeem);

        assertEq(chamber.totalSupply(), quantityToRedeem);
        assertGe(IERC20(token1).balanceOf(address(chamber)), requiredToken1Collateral);
        assertGe(IERC20(token2).balanceOf(address(chamber)), requiredToken2Collateral);
        assertGe(IERC20(token1).balanceOf(address(alice)), 0);
        assertGe(IERC20(token2).balanceOf(address(alice)), 0);
    }

    /**
     * [REVERT] Should revert because the minted amount was performed with FULL overcollateralization. In
     * other words, all USDC put in the chamber is over-collateral, not legit-collateral. So every redeem
     * amount will fail, as its not enough to get even 1 wei of USDC out.
     */
    function testCannotRedeemUSDCWhenMintWasOvercollateralized(
        uint256 quantityToMint,
        uint256 quantityToRedeem,
        uint256 requiredUsdc
    ) public {
        vm.assume(requiredUsdc > 0);
        vm.assume(requiredUsdc < 1 ether);
        vm.assume(quantityToMint > 0);
        vm.assume(quantityToMint < 1 ether / requiredUsdc); // Limit of full overcollateralization
        vm.assume(quantityToRedeem > 0);
        vm.assume(quantityToRedeem < quantityToMint);

        address[] memory usdcAsConstituent = new address[](1);
        usdcAsConstituent[0] = usdc;
        uint256[] memory usdcQuantity = new uint256[](1);
        usdcQuantity[0] = requiredUsdc;
        uint256 requiredUsdcCollateral = quantityToMint.preciseMulCeil(requiredUsdc, 18);

        deal(usdc, alice, requiredUsdcCollateral);
        assertEq(IERC20(usdc).balanceOf(address(alice)), requiredUsdcCollateral);

        Chamber chamber = Chamber(
            chamberGod.createChamber(
                "name", "symbol", usdcAsConstituent, usdcQuantity, wizards, managers
            )
        );
        vm.prank(alice);
        ERC20(usdc).approve(issuerAddress, requiredUsdcCollateral);

        // This is a forced mint, as the quantityToMint is less than 1e18, so we enter over-collateralization terriroty
        vm.prank(alice);
        issuerWizard.issue(IChamber(address(chamber)), quantityToMint);
        assertEq(chamber.totalSupply(), quantityToMint);
        assertEq(IERC20(usdc).balanceOf(address(alice)), 0);
        assertEq(IERC20(usdc).balanceOf(address(chamber)), requiredUsdcCollateral);

        // Every attempt to redeem should fail, because the mint was overcollaterized, so the redeemAmount is not enough to get even 1 wei of USDC out
        vm.prank(alice);
        vm.expectRevert(bytes("Redeem amount too low"));
        issuerWizard.redeem(IChamber(address(chamber)), quantityToRedeem);

        assertEq(chamber.totalSupply(), quantityToMint);
        assertGe(IERC20(usdc).balanceOf(address(chamber)), requiredUsdcCollateral);
        assertGe(IERC20(usdc).balanceOf(address(alice)), 0);
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should return the constituents to the msg.sender when the redeem() function
     * is executed under normal circumstances.
     */
    function testRedeemWithTwoConstituents(
        uint256 quantityToRedeem,
        uint256 token1Quantity,
        uint256 token2Quantity
    ) public {
        vm.assume(token1Quantity > 0);
        vm.assume(token1Quantity < 1 ether);
        vm.assume(token2Quantity > 0);
        vm.assume(token2Quantity < 1 ether);
        vm.assume(quantityToRedeem > 1 ether);
        vm.assume(quantityToRedeem < type(uint160).max);

        uint256[] memory testQuantities = new uint256[](2);
        testQuantities[0] = token1Quantity;
        testQuantities[1] = token2Quantity;
        uint256 requiredToken1Collateral = quantityToRedeem.preciseMulCeil(token1Quantity, 18);
        uint256 requiredToken2Collateral = quantityToRedeem.preciseMulCeil(token2Quantity, 18);
        deal(token1, alice, requiredToken1Collateral);
        deal(token2, alice, requiredToken2Collateral);
        assertEq(IERC20(token1).balanceOf(address(alice)), requiredToken1Collateral);
        assertEq(IERC20(token2).balanceOf(address(alice)), requiredToken2Collateral);

        Chamber chamber = Chamber(
            chamberGod.createChamber(
                "name", "symbol", globalConstituents, testQuantities, wizards, managers
            )
        );

        vm.prank(alice);
        ERC20(token1).approve(issuerAddress, requiredToken1Collateral);
        vm.prank(alice);
        ERC20(token2).approve(issuerAddress, requiredToken2Collateral);

        vm.prank(alice);
        issuerWizard.issue(IChamber(address(chamber)), quantityToRedeem);

        assertEq(chamber.totalSupply(), quantityToRedeem);
        assertEq(IERC20(token1).balanceOf(address(alice)), 0);
        assertEq(IERC20(token2).balanceOf(address(alice)), 0);
        assertEq(IERC20(token1).balanceOf(address(chamber)), requiredToken1Collateral);
        assertEq(IERC20(token2).balanceOf(address(chamber)), requiredToken2Collateral);
        vm.expectEmit(true, true, false, true, address(chamber));
        emit Transfer(alice, address(0x0), quantityToRedeem);
        vm.expectEmit(true, true, false, true, token1);
        emit Transfer(address(chamber), alice, quantityToRedeem.preciseMul(token1Quantity, 18));
        vm.expectEmit(true, true, false, true, token2);
        emit Transfer(address(chamber), alice, quantityToRedeem.preciseMul(token2Quantity, 18));
        vm.expectEmit(true, true, false, true, address(issuerWizard));
        emit ChamberTokenRedeemed(address(chamber), alice, quantityToRedeem);

        vm.prank(alice);
        issuerWizard.redeem(IChamber(address(chamber)), quantityToRedeem);

        assertEq(chamber.totalSupply(), 0);
        assertGe(
            IERC20(token1).balanceOf(address(chamber)),
            quantityToRedeem.preciseMulCeil(token1Quantity, 18)
                - quantityToRedeem.preciseMul(token1Quantity, 18)
        );
        assertGe(
            IERC20(token2).balanceOf(address(chamber)),
            quantityToRedeem.preciseMulCeil(token2Quantity, 18)
                - quantityToRedeem.preciseMul(token2Quantity, 18)
        );
        assertGe(
            IERC20(token1).balanceOf(address(alice)),
            quantityToRedeem.preciseMul(token1Quantity, 18)
        );
        assertGe(
            IERC20(token2).balanceOf(address(alice)),
            quantityToRedeem.preciseMul(token2Quantity, 18)
        );
    }

    /**
     * [SUCCESS] Should be able to redeem some USDC, because some part of the mint was not
     * overcollateralized, in other words, was legit collateralization, not a bonus.
     */
    function testRedeemUSDCWithGeneralMintUseCase(
        uint256 quantityToMint,
        uint256 quantityToRedeem,
        uint256 requiredUsdc
    ) public {
        vm.assume(requiredUsdc > 0);
        vm.assume(requiredUsdc < 1 ether);
        vm.assume(quantityToMint >= 1 ether);
        vm.assume(quantityToMint < type(uint128).max);
        vm.assume(quantityToRedeem > 1 ether / requiredUsdc); // Limit of legit collateral
        vm.assume(quantityToRedeem <= quantityToMint);

        address[] memory usdcAsConstituent = new address[](1);
        usdcAsConstituent[0] = usdc;
        uint256[] memory usdcQuantity = new uint256[](1);
        usdcQuantity[0] = requiredUsdc;
        uint256 requiredUsdcCollateral = quantityToMint.preciseMulCeil(requiredUsdc, 18);

        deal(usdc, alice, requiredUsdcCollateral);
        assertEq(IERC20(usdc).balanceOf(address(alice)), requiredUsdcCollateral);

        Chamber chamber = Chamber(
            chamberGod.createChamber(
                "name", "symbol", usdcAsConstituent, usdcQuantity, wizards, managers
            )
        );
        vm.prank(alice);
        ERC20(usdc).approve(issuerAddress, requiredUsdcCollateral);

        // This is not a forced mint, at least 1e18 chamber tokens will be collaterizaed in a legit manner, while the rest is a combination of
        // legit collateralization and overcollateralization
        vm.prank(alice);
        issuerWizard.issue(IChamber(address(chamber)), quantityToMint);
        assertEq(chamber.totalSupply(), quantityToMint);
        assertEq(IERC20(usdc).balanceOf(address(alice)), 0);
        assertEq(IERC20(usdc).balanceOf(address(chamber)), requiredUsdcCollateral);

        // Every redeem will pass, as the user will be able to get some USDC out
        vm.prank(alice);
        issuerWizard.redeem(IChamber(address(chamber)), quantityToRedeem);

        assertEq(chamber.totalSupply(), quantityToMint - quantityToRedeem);
        assertEq(
            IERC20(usdc).balanceOf(address(chamber)),
            requiredUsdcCollateral - quantityToRedeem.preciseMul(requiredUsdc, 18)
        );
        assertEq(
            IERC20(usdc).balanceOf(address(alice)), quantityToRedeem.preciseMul(requiredUsdc, 18)
        );
    }
}
