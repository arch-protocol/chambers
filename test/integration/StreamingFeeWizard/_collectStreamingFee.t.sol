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
import {StreamingFeeWizard} from "../../../src/StreamingFeeWizard.sol";
import {ExposedStreamingFeeWizard} from "../../utils/exposedContracts/ExposedStreamingFeeWizard.sol";
import {PreciseUnitMath} from "../../../src/lib/PreciseUnitMath.sol";
import {IStreamingFeeWizard} from "src/interfaces/IStreamingFeeWizard.sol";

contract StreamingFeeWizardIntegrationInternalCollectStreamingFeeTest is Test {
    using PreciseUnitMath for uint256;

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 value);

    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/

    IChamber public chamber;
    IssuerWizard public issuerWizard;
    ChamberFactory public chamberFactory;
    Chamber public globalChamber;
    ExposedStreamingFeeWizard public streamingFeeWizard;
    StreamingFeeWizard.FeeState public chamberFeeState;
    address public aliceTheSorcerer = vm.addr(0xe87809df12a1);
    address public issuerAddress;
    address public feeWizardAddress;
    address public chamberAddress;
    address public chamberGodAddress = vm.addr(0x791782394);
    address public token1 = 0x2b591e99afE9f32eAA6214f7B7629768c40Eeb39; // HEX on ETH
    address public token2 = 0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e; // YFI on ETH
    address[] public globalConstituents = new address[](2);
    uint256[] public globalQuantities = new uint256[](2);

    /*//////////////////////////////////////////////////////////////
                              SET UP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        globalConstituents[0] = token1;
        globalConstituents[1] = token2;
        globalQuantities[0] = 54;
        globalQuantities[1] = 77;

        issuerWizard = new IssuerWizard();
        issuerAddress = address(issuerWizard);

        streamingFeeWizard = new ExposedStreamingFeeWizard();
        feeWizardAddress = address(streamingFeeWizard);

        address[] memory wizards = new address[](3);
        wizards[0] = issuerAddress;
        wizards[1] = feeWizardAddress;
        wizards[2] = aliceTheSorcerer;
        address[] memory managers = new address[](1);
        managers[0] = address(this);

        chamberFactory = new ChamberFactory(
          address(this),
          "name",
          "symbol",
          wizards,
          managers
        );

        globalChamber =
            chamberFactory.getChamberWithCustomTokens(globalConstituents, globalQuantities);

        chamberAddress = address(globalChamber);

        chamberFeeState = IStreamingFeeWizard.FeeState(address(this), 100 ether, 80 ether, 0);
        streamingFeeWizard.enableChamber(IChamber(chamberAddress), chamberFeeState);

        vm.label(chamberGodAddress, "ChamberGod");
        vm.label(issuerAddress, "IssuerWizard");
        vm.label(feeWizardAddress, "FeeWizard");
        vm.label(chamberAddress, "Chamber");
        vm.label(address(chamberFactory), "ChamberFactory");
        vm.label(aliceTheSorcerer, "Alice");
        vm.label(token1, "HEX");
        vm.label(token2, "YFI");
    }

    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [REVERT] Should revert if addressChamber provided is not a chamber
     */
    function testCannotCollectStreamingFeeIfAddressIsNotAChamber() public {
        address randomAddress = vm.addr(0x87394);

        vm.expectRevert(); // Cannot define the exact message
        streamingFeeWizard.exposedCollectStreamingFee(
            IChamber(randomAddress), block.timestamp - 10, 1
        );
    }

    /**
     * [REVERT] Should revert if streaming fee wizard is not in the Chamber's wizard list
     */
    function testCannotCollectStreamingFeeIfStreamingFeeWizardIsNotInChamberWizards() public {
        address[] memory wizards = new address[](2);
        wizards[0] = issuerAddress;
        wizards[1] = aliceTheSorcerer;
        // Missing FeeWizard [here]
        address[] memory managers = new address[](1);
        managers[0] = address(this);

        chamberFactory = new ChamberFactory(
          address(this),
          "name",
          "symbol",
          wizards,
          managers
        );

        Chamber someChamber =
            chamberFactory.getChamberWithCustomTokens(globalConstituents, globalQuantities);

        streamingFeeWizard.enableChamber(IChamber(address(someChamber)), chamberFeeState);

        // Add some supply
        uint256 initialSupply = 30 ether;

        deal(token1, aliceTheSorcerer, initialSupply.preciseMulCeil(globalQuantities[0], 18));
        deal(token2, aliceTheSorcerer, initialSupply.preciseMulCeil(globalQuantities[1], 18));
        vm.prank(aliceTheSorcerer);
        IERC20(token1).approve(issuerAddress, initialSupply.preciseMulCeil(globalQuantities[0], 18));
        vm.prank(aliceTheSorcerer);
        IERC20(token2).approve(issuerAddress, initialSupply.preciseMulCeil(globalQuantities[1], 18));

        vm.prank(aliceTheSorcerer);
        issuerWizard.issue(IChamber(address(someChamber)), initialSupply);

        // Let time pass to accumulate fees
        uint256 lastTimestamp = block.timestamp;
        vm.warp(block.timestamp + 300000);

        // Try to collect fees and mint new supply
        vm.expectRevert(bytes("Must be a wizard"));
        streamingFeeWizard.exposedCollectStreamingFee(
            IChamber(address(someChamber)), lastTimestamp, 80 ether
        );
    }

    /**
     * [REVERT] Should revert when collecting fees with zero supply, but not zero fees
     */
    function testCollectStreamingFeeShouldNotChangeChamberIfSupplyIsZero(uint256 blocksAhead)
        public
    {
        vm.assume(blocksAhead > 0);
        vm.assume(blocksAhead < 365.25 days);

        // Time passes
        vm.warp(block.timestamp + blocksAhead);

        // Calculate claimable fee
        uint256 currentFee = streamingFeeWizard.getStreamingFeePercentage(IChamber(chamberAddress));
        uint256 currentTimestamp =
            streamingFeeWizard.getLastCollectTimestamp(IChamber(chamberAddress));
        address currentRecipient =
            streamingFeeWizard.getStreamingFeeRecipient(IChamber(chamberAddress));
        uint256 currentSupply = IERC20(chamberAddress).totalSupply();
        uint256 currentQuantityToken1 = IChamber(chamberAddress).getConstituentQuantity(token1);
        uint256 currentQuantityToken2 = IChamber(chamberAddress).getConstituentQuantity(token2);
        uint256 inflationQuantity = streamingFeeWizard.calculateInflationQuantity(
            currentSupply, currentTimestamp, currentFee
        );
        assertEq(inflationQuantity, 0);
        uint256 currentFeeRecipientBalance = IERC20(chamberAddress).balanceOf(currentRecipient);

        vm.expectCall(chamberAddress, abi.encodeCall(IERC20(chamberAddress).totalSupply, ()));
        vm.expectCall(
            chamberAddress,
            abi.encodeCall(IChamber(chamberAddress).mint, (currentRecipient, inflationQuantity))
        );
        vm.expectCall(chamberAddress, abi.encodeCall(IChamber(chamberAddress).updateQuantities, ()));
        vm.expectEmit(true, true, true, true, chamberAddress);
        emit Transfer(address(0), address(this), inflationQuantity);

        // Call
        vm.expectRevert(); // bytes("Division or modulo by 0")
        streamingFeeWizard.exposedCollectStreamingFee(
            IChamber(chamberAddress), currentTimestamp, currentFee
        );

        // Check conditions
        assertEq(IERC20(chamberAddress).totalSupply(), currentSupply + inflationQuantity);
        assertEq(IChamber(chamberAddress).getConstituentQuantity(token1), currentQuantityToken1);
        assertEq(IChamber(chamberAddress).getConstituentQuantity(token2), currentQuantityToken2);
        assertEq(
            IERC20(chamberAddress).balanceOf(currentRecipient),
            currentFeeRecipientBalance + inflationQuantity
        );
        assertEq(streamingFeeWizard.getStreamingFeePercentage(IChamber(chamberAddress)), currentFee);
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCESS] Should not change any state in the chamber if streaming fee is zero
     */
    function testCollectStreamingFeeShouldNotChangeChamberIfFeeIsZero(uint256 blocksAhead) public {
        vm.assume(blocksAhead > 0);
        vm.assume(blocksAhead < 365.25 days);

        // Add some supply
        uint256 initialSupply = 30 ether;

        deal(token1, aliceTheSorcerer, initialSupply.preciseMulCeil(globalQuantities[0], 18));
        deal(token2, aliceTheSorcerer, initialSupply.preciseMulCeil(globalQuantities[1], 18));
        vm.prank(aliceTheSorcerer);
        IERC20(token1).approve(issuerAddress, initialSupply.preciseMulCeil(globalQuantities[0], 18));
        vm.prank(aliceTheSorcerer);
        IERC20(token2).approve(issuerAddress, initialSupply.preciseMulCeil(globalQuantities[1], 18));

        vm.prank(aliceTheSorcerer);
        issuerWizard.issue(IChamber(chamberAddress), initialSupply);

        // Time passes
        vm.warp(block.timestamp + 1);

        // Set fee to zero
        streamingFeeWizard.updateStreamingFee(IChamber(chamberAddress), 0);

        // Time passes
        vm.warp(block.timestamp + 2);

        // Calculate claimable fee
        uint256 currentFee = streamingFeeWizard.getStreamingFeePercentage(IChamber(chamberAddress));
        uint256 currentTimestamp =
            streamingFeeWizard.getLastCollectTimestamp(IChamber(chamberAddress));
        address currentRecipient =
            streamingFeeWizard.getStreamingFeeRecipient(IChamber(chamberAddress));
        uint256 currentSupply = IERC20(chamberAddress).totalSupply();
        uint256 currentQuantityToken1 = IChamber(chamberAddress).getConstituentQuantity(token1);
        uint256 currentQuantityToken2 = IChamber(chamberAddress).getConstituentQuantity(token2);
        uint256 inflationQuantity = streamingFeeWizard.calculateInflationQuantity(
            currentSupply, currentTimestamp, currentFee
        );
        assertEq(inflationQuantity, 0);
        uint256 currentFeeRecipientBalance = IERC20(chamberAddress).balanceOf(currentRecipient);

        // Call
        streamingFeeWizard.exposedCollectStreamingFee(
            IChamber(chamberAddress), currentTimestamp, currentFee
        );

        // Check conditions
        assertEq(IERC20(chamberAddress).totalSupply(), currentSupply);
        assertEq(IERC20(chamberAddress).balanceOf(currentRecipient), currentFeeRecipientBalance);
        assertEq(streamingFeeWizard.getStreamingFeePercentage(IChamber(chamberAddress)), currentFee);

        // Collecting fees again in the future still does not mint anything
        vm.warp(block.timestamp + 3 * blocksAhead);
        streamingFeeWizard.exposedCollectStreamingFee(
            IChamber(chamberAddress), currentTimestamp, currentFee
        );
        vm.warp(block.timestamp + 4 * blocksAhead);
        streamingFeeWizard.exposedCollectStreamingFee(
            IChamber(chamberAddress), currentTimestamp, currentFee
        );

        // Check conditions
        assertEq(IERC20(chamberAddress).totalSupply(), currentSupply + inflationQuantity);
        assertEq(IChamber(chamberAddress).getConstituentQuantity(token1), currentQuantityToken1);
        assertEq(IChamber(chamberAddress).getConstituentQuantity(token2), currentQuantityToken2);
        assertEq(
            IERC20(chamberAddress).balanceOf(currentRecipient),
            currentFeeRecipientBalance + inflationQuantity
        );
        assertEq(streamingFeeWizard.getStreamingFeePercentage(IChamber(chamberAddress)), currentFee);
    }

    /**
     * [SUCESS] Should execute the function correctly, check states and emitted events
     */
    function testCollectStreamingFee(uint256 blocksAhead) public {
        vm.assume(blocksAhead > 0);
        vm.assume(blocksAhead < 365.25 days);

        // Add some supply
        uint256 initialSupply = 30 ether;

        deal(token1, aliceTheSorcerer, initialSupply.preciseMulCeil(globalQuantities[0], 18));
        deal(token2, aliceTheSorcerer, initialSupply.preciseMulCeil(globalQuantities[1], 18));
        vm.prank(aliceTheSorcerer);
        IERC20(token1).approve(issuerAddress, initialSupply.preciseMulCeil(globalQuantities[0], 18));
        vm.prank(aliceTheSorcerer);
        IERC20(token2).approve(issuerAddress, initialSupply.preciseMulCeil(globalQuantities[1], 18));

        vm.prank(aliceTheSorcerer);
        issuerWizard.issue(IChamber(chamberAddress), initialSupply);

        // Time passes
        vm.warp(block.timestamp + blocksAhead);

        // Calculate claimable fee
        uint256 currentFee = streamingFeeWizard.getStreamingFeePercentage(IChamber(chamberAddress));
        uint256 currentTimestamp =
            streamingFeeWizard.getLastCollectTimestamp(IChamber(chamberAddress));
        address currentRecipient =
            streamingFeeWizard.getStreamingFeeRecipient(IChamber(chamberAddress));
        uint256 currentSupply = IERC20(chamberAddress).totalSupply();
        uint256 currentQuantityToken1 = IChamber(chamberAddress).getConstituentQuantity(token1);
        uint256 currentQuantityToken2 = IChamber(chamberAddress).getConstituentQuantity(token2);
        uint256 inflationQuantity = streamingFeeWizard.calculateInflationQuantity(
            currentSupply, currentTimestamp, currentFee
        );
        uint256 currentFeeRecipientBalance = IERC20(chamberAddress).balanceOf(currentRecipient);

        vm.expectCall(chamberAddress, abi.encodeCall(IERC20(chamberAddress).totalSupply, ()));
        vm.expectCall(
            chamberAddress,
            abi.encodeCall(IChamber(chamberAddress).mint, (currentRecipient, inflationQuantity))
        );
        vm.expectCall(chamberAddress, abi.encodeCall(IChamber(chamberAddress).updateQuantities, ()));
        vm.expectEmit(true, true, true, true, chamberAddress);
        emit Transfer(address(0), address(this), inflationQuantity);

        // Call
        streamingFeeWizard.exposedCollectStreamingFee(
            IChamber(chamberAddress), currentTimestamp, currentFee
        );

        // Check conditions
        assertEq(IERC20(chamberAddress).totalSupply(), currentSupply + inflationQuantity);
        assertLe(IChamber(chamberAddress).getConstituentQuantity(token1), currentQuantityToken1);
        assertLe(IChamber(chamberAddress).getConstituentQuantity(token2), currentQuantityToken2);
        assertEq(
            IERC20(chamberAddress).balanceOf(currentRecipient),
            currentFeeRecipientBalance + inflationQuantity
        );
        assertEq(streamingFeeWizard.getStreamingFeePercentage(IChamber(chamberAddress)), currentFee);
    }
}
