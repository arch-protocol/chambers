// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IChamber} from "src/interfaces/IChamber.sol";
import {Chamber} from "src/Chamber.sol";
import {IssuerWizard} from "src/IssuerWizard.sol";
import {ChamberFactory} from "test/utils/factories.sol";
import {PreciseUnitMath} from "src/lib/PreciseUnitMath.sol";

contract EvilSaruman {
    function attack(address _chamberToAttack) external {
        IChamber(_chamberToAttack).mint(address(this), 1);
        IChamber(_chamberToAttack).updateQuantities();
        IChamber(_chamberToAttack).mint(address(this), 1);
        IChamber(_chamberToAttack).updateQuantities();
    }
}

contract ChamberIntegrationUpdateQuantitiesTest is Test {
    using PreciseUnitMath for uint256;

    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/

    EvilSaruman public evilSaruman; // Evil Wizard
    IssuerWizard public issuerWizard;
    ChamberFactory public chamberFactory;
    Chamber public globalChamber;
    address public aliceTheSorcerer = vm.addr(0xe87809df12a1);
    address public issuerAddress;
    address public maliciousWizard;
    address public globalChamberAddress;
    address public chamberGodAddress = vm.addr(0x791782394);
    address public token1 = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC on ETH
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
        globalQuantities[0] = 6 ether;
        globalQuantities[1] = 2 ether;

        issuerWizard = new IssuerWizard(chamberGodAddress);
        issuerAddress = address(issuerWizard);

        evilSaruman = new EvilSaruman();
        maliciousWizard = address(evilSaruman);

        address[] memory wizards = new address[](3);
        wizards[0] = aliceTheSorcerer;
        wizards[1] = issuerAddress;
        wizards[2] = maliciousWizard;
        address[] memory managers = new address[](1);
        managers[0] = aliceTheSorcerer;

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
        globalChamberAddress = address(globalChamber);

        vm.label(chamberGodAddress, "ChamberGod");
        vm.label(issuerAddress, "IssuerWizard");
        vm.label(globalChamberAddress, "Chamber");
        vm.label(address(chamberFactory), "ChamberFactory");
        vm.label(aliceTheSorcerer, "Alice");
        vm.label(token1, "USDC");
        vm.label(token2, "YFI");
    }

    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [REVERT] Should revert when the caller is not a wizard
     */
    function testCannotUpdateQuantitiesWhenCallerIsNotAWizard(address randomAddress) public {
        vm.assume(randomAddress != aliceTheSorcerer);
        uint256 previousChamberSupply = IERC20(globalChamberAddress).totalSupply();
        uint256[] memory previousQuantities = globalChamber.getQuantities();
        assertEq(previousChamberSupply, 0);

        vm.expectRevert(bytes("Must be a wizard"));

        vm.prank(randomAddress);
        globalChamber.updateQuantities();

        uint256 newChamberSupply = IERC20(globalChamberAddress).totalSupply();
        uint256[] memory newQuantities = globalChamber.getQuantities();
        assertEq(newChamberSupply, previousChamberSupply);
        assertEq(newQuantities, previousQuantities);
    }

    /**
     * [REVERT] Should revert when the total supply is zero.
     */
    function testCannotUpdateQuantitiesWhenTotalSupplyIsZero() public {
        uint256 previousChamberSupply = IERC20(globalChamberAddress).totalSupply();
        uint256[] memory previousQuantities = globalChamber.getQuantities();
        assertEq(previousChamberSupply, 0);

        vm.expectRevert();

        vm.prank(aliceTheSorcerer);
        globalChamber.updateQuantities();

        uint256 newChamberSupply = IERC20(address(globalChamber)).totalSupply();
        assertEq(newChamberSupply, previousChamberSupply);
        uint256[] memory newQuantities = globalChamber.getQuantities();
        assertEq(newChamberSupply, previousChamberSupply);
        assertEq(newQuantities, previousQuantities);
    }

    /**
     * [REVERT] Should revert if the total quantity collateral of one token in the Chamber,
     * is less than the total supply of chamber tokens. i.e. The division collateral * 10edecimals / supply
     * is less than zero. This happens when Total suuply is greater than the total units of a token:
     *
     * Supply > Collateral, or
     *
     * uncollateraized_supply + collaterized_supply > token_i_quantity * collaterized_supply / 10edecimals
     *
     * For Any token_i
     *
     * When this scenario happens, the function reverts. So any bad call from the StreamingFeeWizard
     * or the RebalanceWizard will revert.
     */
    function testCannotUpdateQuantitiesWhenOneConstituentCollateralIsNotEnoughForTotalSupply(
        uint256 initialSupply,
        uint256 token1Quantity,
        uint256 token2Quantity
    ) public {
        vm.assume(initialSupply > 1 ether);
        vm.assume(initialSupply < type(uint160).max);
        vm.assume(token1Quantity > 0);
        vm.assume(token1Quantity < type(uint64).max);
        vm.assume(token2Quantity > 0);
        vm.assume(token2Quantity < type(uint64).max);

        // Collateralized mint
        uint256[] memory testQuantities = new uint256[](2);
        testQuantities[0] = token1Quantity;
        testQuantities[1] = token2Quantity;

        Chamber chamber =
            chamberFactory.getChamberWithCustomTokens(globalConstituents, testQuantities);

        uint256 requiredToken1Collateral = initialSupply.preciseMulCeil(token1Quantity, 18);
        uint256 requiredToken2Collateral = initialSupply.preciseMulCeil(token2Quantity, 18);
        deal(token1, aliceTheSorcerer, requiredToken1Collateral);
        deal(token2, aliceTheSorcerer, requiredToken2Collateral);
        vm.prank(aliceTheSorcerer);
        IERC20(token1).approve(issuerAddress, requiredToken1Collateral);
        vm.prank(aliceTheSorcerer);
        IERC20(token2).approve(issuerAddress, requiredToken2Collateral);

        vm.expectEmit(true, true, true, true, issuerAddress);
        emit ChamberTokenIssued(address(chamber), aliceTheSorcerer, initialSupply);

        vm.prank(aliceTheSorcerer);
        issuerWizard.issue(IChamber(address(chamber)), initialSupply);

        // Uncollateralized mint
        uint256 supplyForExactCrashToken2 = (requiredToken2Collateral * 1 ether) + 1; // Break update quantities
        vm.prank(aliceTheSorcerer);
        chamber.mint(aliceTheSorcerer, supplyForExactCrashToken2);

        // UpdateQuantities()
        uint256 currentChamberSupply = IERC20(address(chamber)).totalSupply();
        uint256[] memory currentQuantities = chamber.getQuantities();
        uint256 currentToken1Balance = IERC20(token1).balanceOf(address(chamber));
        uint256 currentToken2Balance = IERC20(token2).balanceOf(address(chamber));
        uint256 currentAliceBalance = IERC20(address(chamber)).balanceOf(aliceTheSorcerer);

        vm.expectRevert(bytes("Zero quantity not allowed"));
        vm.prank(aliceTheSorcerer);
        chamber.updateQuantities();

        uint256 newChamberSupply = IERC20(address(chamber)).totalSupply();
        uint256[] memory newQuantities = chamber.getQuantities();
        uint256 newToken1Balance = IERC20(token1).balanceOf(address(chamber));
        uint256 newToken2Balance = IERC20(token2).balanceOf(address(chamber));
        uint256 newAliceBalance = IERC20(address(chamber)).balanceOf(aliceTheSorcerer);

        assertEq(currentToken1Balance, newToken1Balance);
        assertEq(currentToken2Balance, newToken2Balance);
        assertEq(currentChamberSupply, newChamberSupply);
        assertEq(currentQuantities, newQuantities);
        assertEq(currentAliceBalance, newAliceBalance);
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should change the quantities as expected, if there is at least one unit of
     * every token, for each token in the chamber. i.e. The following is always satisfied:
     *
     * (token_i.balanceOf(chamber) > chamber.totalSupply)  for every token_i in constituents
     */
    function testUpdateQuantities(uint256 token1Quantity, uint256 token2Quantity) public {
        uint256 uncollaterizedMintSupplyPercentage = 76;
        uint256 initialSupply = 1 ether;
        vm.assume(token1Quantity > 6);
        vm.assume(token2Quantity > 6);
        vm.assume(token1Quantity < type(uint64).max);
        vm.assume(token2Quantity < type(uint64).max);

        // Create some supply
        uint256[] memory testQuantities = new uint256[](2);
        testQuantities[0] = token1Quantity;
        testQuantities[1] = token2Quantity;

        Chamber chamber =
            chamberFactory.getChamberWithCustomTokens(globalConstituents, testQuantities);

        uint256 requiredToken1Collateral = initialSupply.preciseMulCeil(token1Quantity, 18);
        uint256 requiredToken2Collateral = initialSupply.preciseMulCeil(token2Quantity, 18);
        deal(token1, aliceTheSorcerer, requiredToken1Collateral);
        deal(token2, aliceTheSorcerer, requiredToken2Collateral);
        vm.prank(aliceTheSorcerer);
        IERC20(token1).approve(issuerAddress, requiredToken1Collateral);
        vm.prank(aliceTheSorcerer);
        IERC20(token2).approve(issuerAddress, requiredToken2Collateral);

        vm.expectEmit(true, true, true, true, issuerAddress);
        emit ChamberTokenIssued(address(chamber), aliceTheSorcerer, initialSupply);

        vm.prank(aliceTheSorcerer);
        issuerWizard.issue(IChamber(address(chamber)), initialSupply);

        uint256 previousChamberSupply = IERC20(address(chamber)).totalSupply();

        // Uncollaterized mint
        uint256 uncollaterizedMintAmount =
            (uncollaterizedMintSupplyPercentage * previousChamberSupply) / 100;
        vm.prank(aliceTheSorcerer);
        chamber.mint(address(this), uncollaterizedMintAmount); // Mint X% supply to this

        uint256 currentChamberSupply = IERC20(address(chamber)).totalSupply();
        uint256 currentAliceBalance = IERC20(address(chamber)).balanceOf(aliceTheSorcerer);

        assertEq(currentChamberSupply, previousChamberSupply + uncollaterizedMintAmount);
        assertEq(currentAliceBalance, initialSupply); // Alice has the same tokens

        uint256 token1Balance = IERC20(token1).balanceOf(address(chamber));
        uint256 token2Balance = IERC20(token2).balanceOf(address(chamber));

        // Update quantities
        vm.prank(aliceTheSorcerer);
        chamber.updateQuantities();

        uint256 newChamberSupply = IERC20(address(chamber)).totalSupply();
        uint256 newAliceBalance = IERC20(address(chamber)).balanceOf(aliceTheSorcerer);

        assertEq(currentChamberSupply, newChamberSupply);
        assertEq(currentAliceBalance, newAliceBalance); // Alice has the same tokens

        uint256 newQuantityToken1 = chamber.getConstituentQuantity(token1);
        uint256 newQuantityToken2 = chamber.getConstituentQuantity(token2);

        uint256 expectedQuantityToken1 = token1Balance.preciseDiv(currentChamberSupply, 18);
        uint256 expectedQuantityToken2 = token2Balance.preciseDiv(currentChamberSupply, 18);

        assertEq(expectedQuantityToken1, newQuantityToken1);
        assertEq(expectedQuantityToken2, newQuantityToken2);
    }

    /**
     * [SUCCESS] Should not change the quantities, if there isn't an uncollaterized mint.
     * i.e. all minted tokens are fully collaterized. i.e. calling the function randomly.
     */
    function testUpdateQuantitiesShouldNotChangeAnythingIfUncollaterizedMintIsZero(
        uint256 initialSupply,
        uint256 token1Quantity,
        uint256 token2Quantity
    ) public {
        vm.assume(initialSupply > 1 ether);
        vm.assume(initialSupply < type(uint160).max);
        vm.assume(token1Quantity > 2);
        vm.assume(token1Quantity < type(uint64).max);
        vm.assume(token2Quantity > 2);
        vm.assume(token2Quantity < type(uint64).max);

        // Create some supply
        uint256[] memory testQuantities = new uint256[](2);
        testQuantities[0] = token1Quantity;
        testQuantities[1] = token2Quantity;

        Chamber chamber =
            chamberFactory.getChamberWithCustomTokens(globalConstituents, testQuantities);

        uint256 requiredToken1Collateral = initialSupply.preciseMulCeil(token1Quantity, 18);
        uint256 requiredToken2Collateral = initialSupply.preciseMulCeil(token2Quantity, 18);
        deal(token1, aliceTheSorcerer, requiredToken1Collateral);
        deal(token2, aliceTheSorcerer, requiredToken2Collateral);
        vm.prank(aliceTheSorcerer);
        IERC20(token1).approve(issuerAddress, requiredToken1Collateral);
        vm.prank(aliceTheSorcerer);
        IERC20(token2).approve(issuerAddress, requiredToken2Collateral);

        vm.expectEmit(true, true, true, true, issuerAddress);
        emit ChamberTokenIssued(address(chamber), aliceTheSorcerer, initialSupply);

        vm.prank(aliceTheSorcerer);
        issuerWizard.issue(IChamber(address(chamber)), initialSupply);

        uint256 currentChamberSupply = IERC20(address(chamber)).totalSupply();
        uint256[] memory currentQuantities = chamber.getQuantities();
        uint256 currentToken1Balance = IERC20(token1).balanceOf(address(chamber));
        uint256 currentToken2Balance = IERC20(token2).balanceOf(address(chamber));
        uint256 currentAliceBalance = IERC20(address(chamber)).balanceOf(aliceTheSorcerer);

        // Zero mint
        vm.prank(aliceTheSorcerer);
        chamber.mint(aliceTheSorcerer, 0);

        // Update quantities
        vm.prank(aliceTheSorcerer);
        chamber.updateQuantities();

        uint256 newChamberSupply = IERC20(address(chamber)).totalSupply();
        uint256[] memory newQuantities = chamber.getQuantities();
        uint256 newToken1Balance = IERC20(token1).balanceOf(address(chamber));
        uint256 newToken2Balance = IERC20(token2).balanceOf(address(chamber));
        uint256 newAliceBalance = IERC20(address(chamber)).balanceOf(aliceTheSorcerer);

        assertEq(currentToken1Balance, newToken1Balance);
        assertEq(currentToken2Balance, newToken2Balance);
        assertEq(currentChamberSupply, newChamberSupply);
        assertEq(currentQuantities, newQuantities);
        assertEq(currentAliceBalance, newAliceBalance);
    }

    /**
     * [SUCCESS] Should NOT revert if a malicious Wizard tries to call mint + updateQuantities twice
     * in another contract. Any malicious wizard can break a chamber where it has been allowlisted.
     * This test reflects the importance of the onlyWizard modifier.
     */
    function testUpdateQuantitiesTwiceInAMaliciousWizard(
        uint256 initialSupply,
        uint256 token1Quantity,
        uint256 token2Quantity
    ) public {
        vm.assume(initialSupply > 1000);
        vm.assume(initialSupply < type(uint160).max);
        vm.assume(token1Quantity > 6);
        vm.assume(token1Quantity < type(uint64).max);
        vm.assume(token2Quantity > 6);
        vm.assume(token2Quantity < type(uint64).max);

        // Collateralized mint
        uint256[] memory testQuantities = new uint256[](2);
        testQuantities[0] = token1Quantity;
        testQuantities[1] = token2Quantity;

        Chamber chamber =
            chamberFactory.getChamberWithCustomTokens(globalConstituents, testQuantities);

        uint256 requiredToken1Collateral = initialSupply.preciseMulCeil(token1Quantity, 18);
        uint256 requiredToken2Collateral = initialSupply.preciseMulCeil(token2Quantity, 18);
        deal(token1, aliceTheSorcerer, requiredToken1Collateral);
        deal(token2, aliceTheSorcerer, requiredToken2Collateral);
        vm.prank(aliceTheSorcerer);
        IERC20(token1).approve(issuerAddress, requiredToken1Collateral);
        vm.prank(aliceTheSorcerer);
        IERC20(token2).approve(issuerAddress, requiredToken2Collateral);

        vm.expectEmit(true, true, true, true, issuerAddress);
        emit ChamberTokenIssued(address(chamber), aliceTheSorcerer, initialSupply);

        vm.prank(aliceTheSorcerer);
        issuerWizard.issue(IChamber(address(chamber)), initialSupply);

        // Uncollateralized mint
        uint256 uncollaterizedMintAmount = 2 * initialSupply / 100; // Mint 2% supply uncollaterized
        vm.prank(aliceTheSorcerer);
        chamber.mint(aliceTheSorcerer, uncollaterizedMintAmount);

        // Attack chamber
        evilSaruman.attack(address(chamber));
    }
}
