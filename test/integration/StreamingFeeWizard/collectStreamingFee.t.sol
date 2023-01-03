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

contract StreamingFeeWizardIntegrationCollectStreamingFeeTest is Test {
    using PreciseUnitMath for uint256;

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 value);
    event FeeCollected(
        address indexed _chamber, uint256 _streamingFeePercentage, uint256 inflationQuantity
    );

    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/

    IChamber public chamber;
    IssuerWizard public issuerWizard;
    ExposedStreamingFeeWizard public streamingFeeWizard;
    ChamberFactory public chamberFactory;
    Chamber public globalChamber;
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

        chamberFeeState = StreamingFeeWizard.FeeState(address(this), 100 ether, 80 ether, 0);
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
     * [REVERT] Should revert when trying to collect fees from a Chamber that does not exists
     */
    function testCannotCollectFeesOfNonExistantChamber(address caller, address someChamber)
        public
    {
        vm.assume(someChamber != chamberAddress);
        vm.assume(caller != someChamber);
        vm.expectRevert(bytes("Chamber does not exist"));

        vm.prank(caller);
        streamingFeeWizard.collectStreamingFee(IChamber(someChamber));
    }

    /**
     * [REVERT] Any manager from a Chamber can add it to the FeeWizard contract and perform any writing function
     * as they please. But they cannot call collectFees(), only chamber's allowed wizards.
     *
     * For instance, if you want to use a another FeeWizard contract for your chamber, you could track fees
     * beforehand, and then allow the Wizard in the chamber, and collect fees. BUT, this is improbable as the
     * addWizard() method can only add allowed wizards by the chamberGod, and when supply is zero. Any other wizard
     * wont be able to join the chamber current list, so this scenario is impossible.
     */
    function testCannotCollectOrUpdateFeesWhenFeeWizardIsNotAllowedInChamber() public {
        address[] memory wizards = new address[](1);
        wizards[0] = issuerAddress;
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
        vm.warp(block.timestamp + 100000);
        streamingFeeWizard.updateFeeRecipient(IChamber(address(someChamber)), vm.addr(0x70123));
        vm.warp(block.timestamp + 200000);
        streamingFeeWizard.updateMaxStreamingFee(IChamber(address(someChamber)), 99 ether);

        vm.warp(block.timestamp + 300000); // Let time pass to accumulate fees

        vm.expectRevert(bytes("Must be a wizard"));
        streamingFeeWizard.collectStreamingFee(IChamber(address(someChamber)));

        vm.warp(block.timestamp + 400000);
        vm.expectRevert(bytes("Must be a wizard")); // updateStreamingFee also collect fees
        streamingFeeWizard.updateStreamingFee(IChamber(address(someChamber)), 99 ether);

        // Add stremingFeeWizard to wizards in chamber
        vm.expectRevert(); // TODO: Make msg.sender a Chamber God to use bytes("Wizard not validated in ChamberGod")
        someChamber.addWizard(feeWizardAddress);
    }

    /**
     * [REVERT] Should revert trying to collect fees twice in the same block
     */
    function testCannotCollectStreamingFeeIfNoBlocksHavePassed() public {
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
        vm.warp(block.timestamp + 1000000);

        uint256 currentFee = streamingFeeWizard.getStreamingFeePercentage(IChamber(chamberAddress));

        // Call succesful
        streamingFeeWizard.collectStreamingFee(IChamber(chamberAddress));

        // Get updated params
        address currentRecipient =
            streamingFeeWizard.getStreamingFeeRecipient(IChamber(chamberAddress));
        uint256 currentSupply = IERC20(chamberAddress).totalSupply();
        uint256 currentQuantityToken1 = IChamber(chamberAddress).getConstituentQuantity(token1);
        uint256 currentQuantityToken2 = IChamber(chamberAddress).getConstituentQuantity(token2);
        uint256 currentFeeRecipientBalance = IERC20(chamberAddress).balanceOf(currentRecipient);

        // Cannot collect again
        vm.expectRevert(bytes("Cannot collect twice"));
        streamingFeeWizard.collectStreamingFee(IChamber(chamberAddress));
        vm.expectRevert(bytes("Cannot collect twice"));
        streamingFeeWizard.collectStreamingFee(IChamber(chamberAddress));

        // Check conditions
        assertEq(IERC20(chamberAddress).totalSupply(), currentSupply);
        assertEq(IChamber(chamberAddress).getConstituentQuantity(token1), currentQuantityToken1);
        assertEq(IChamber(chamberAddress).getConstituentQuantity(token2), currentQuantityToken2);
        assertEq(IERC20(chamberAddress).balanceOf(currentRecipient), currentFeeRecipientBalance);
        assertEq(streamingFeeWizard.getStreamingFeePercentage(IChamber(chamberAddress)), currentFee);
    }

    /**
     * [REVERT] Should NOT collect fees when the fee is zero. Supply nor constituents quantities should change
     * in the chamber.
     */
    function testCollectZeroFees() public {
        // Create chamber with 0% fees
        address[] memory wizards = new address[](2);
        wizards[0] = issuerAddress;
        wizards[1] = feeWizardAddress;
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

        StreamingFeeWizard.FeeState memory feeState =
            StreamingFeeWizard.FeeState(address(this), 100 ether, 0 ether, 0); // 0% fee

        streamingFeeWizard.enableChamber(IChamber(address(someChamber)), feeState);

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

        // Time passes
        vm.warp(block.timestamp + 1000323);

        // Calculate claimable fee
        uint256 currentFee =
            streamingFeeWizard.getStreamingFeePercentage(IChamber(address(someChamber)));
        uint256 currentTimestamp =
            streamingFeeWizard.getLastCollectTimestamp(IChamber(address(someChamber)));
        address currentRecipient =
            streamingFeeWizard.getStreamingFeeRecipient(IChamber(address(someChamber)));
        uint256 currentSupply = IERC20(address(someChamber)).totalSupply();
        uint256 currentQuantityToken1 =
            IChamber(address(someChamber)).getConstituentQuantity(token1);
        uint256 currentQuantityToken2 =
            IChamber(address(someChamber)).getConstituentQuantity(token2);
        uint256 inflationQuantity = streamingFeeWizard.calculateInflationQuantity(
            currentSupply, currentTimestamp, currentFee
        );
        assertEq(inflationQuantity, 0);
        uint256 currentFeeRecipientBalance =
            IERC20(address(someChamber)).balanceOf(currentRecipient);

        // Call
        vm.expectRevert(bytes("Chamber fee is zero"));
        vm.prank(vm.addr(0x9283423b3));
        streamingFeeWizard.collectStreamingFee(IChamber(address(someChamber)));

        // Check conditions
        assertEq(IERC20(address(someChamber)).totalSupply(), currentSupply);
        assertEq(
            IChamber(address(someChamber)).getConstituentQuantity(token1), currentQuantityToken1
        );
        assertEq(
            IChamber(address(someChamber)).getConstituentQuantity(token2), currentQuantityToken2
        );
        assertEq(
            IERC20(address(someChamber)).balanceOf(currentRecipient), currentFeeRecipientBalance
        );
        assertEq(
            streamingFeeWizard.getStreamingFeePercentage(IChamber(address(someChamber))), currentFee
        );

        // Call multiple times, by other people, and supply and quantities should maintain
        vm.warp(block.timestamp + 89239748723);
        vm.expectRevert(bytes("Chamber fee is zero"));
        vm.prank(vm.addr(0x71253));
        streamingFeeWizard.collectStreamingFee(IChamber(address(someChamber)));
        vm.warp(block.timestamp + 9827983774233);
        vm.expectRevert(bytes("Chamber fee is zero"));
        vm.prank(vm.addr(0x8b3));
        streamingFeeWizard.collectStreamingFee(IChamber(address(someChamber)));

        // Add some supply in between
        uint256 additionalSupply = 33 ether;

        deal(token1, aliceTheSorcerer, additionalSupply * globalQuantities[0]);
        deal(token2, aliceTheSorcerer, additionalSupply * globalQuantities[1]);
        vm.prank(aliceTheSorcerer);
        IERC20(token1).approve(issuerAddress, additionalSupply * globalQuantities[0]);
        vm.prank(aliceTheSorcerer);
        IERC20(token2).approve(issuerAddress, additionalSupply * globalQuantities[1]);

        vm.prank(aliceTheSorcerer);
        issuerWizard.issue(IChamber(address(someChamber)), additionalSupply);

        // Collect a final time
        vm.warp(block.timestamp + 98289347598347534);
        vm.expectRevert(bytes("Chamber fee is zero"));
        vm.prank(vm.addr(0x88d8fb3));
        streamingFeeWizard.collectStreamingFee(IChamber(address(someChamber)));

        // Check conditions
        assertEq(IERC20(address(someChamber)).totalSupply(), currentSupply + additionalSupply);
        assertEq(
            IChamber(address(someChamber)).getConstituentQuantity(token1), currentQuantityToken1
        );
        assertEq(
            IChamber(address(someChamber)).getConstituentQuantity(token2), currentQuantityToken2
        );
        assertEq(
            IERC20(address(someChamber)).balanceOf(currentRecipient), currentFeeRecipientBalance
        );
        assertEq(
            streamingFeeWizard.getStreamingFeePercentage(IChamber(address(someChamber))), currentFee
        );
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Any wallet should be able to collect fees from any chamber. The fee Collection should be
     * correct, and the FeeCollected event should emit. Calling it again in the same blocks makes no effect.
     */
    function testCollectFeesByAnyWallet(address caller, uint256 blocksAhead) public {
        vm.assume(caller != chamberAddress);
        vm.assume(caller != address(0));
        vm.assume(blocksAhead > 0);
        vm.assume(blocksAhead < 365.25 days / 12);

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
        uint256 inflationQuantity = streamingFeeWizard.calculateInflationQuantity(
            currentSupply, currentTimestamp, currentFee
        );
        uint256 currentFeeRecipientBalance = IERC20(chamberAddress).balanceOf(currentRecipient);

        vm.expectCall(chamberAddress, abi.encodeCall(IERC20(chamberAddress).totalSupply, ()));
        vm.expectCall(
            chamberAddress,
            abi.encodeCall(IChamber(chamberAddress).mint, (address(this), inflationQuantity))
        );
        vm.expectCall(chamberAddress, abi.encodeCall(IChamber(chamberAddress).updateQuantities, ()));
        vm.expectEmit(true, true, true, true, chamberAddress);
        emit Transfer(address(0), address(this), inflationQuantity);
        vm.expectEmit(true, false, false, true, address(streamingFeeWizard));
        emit FeeCollected(chamberAddress, currentFee, inflationQuantity);

        // Call
        vm.prank(caller);
        streamingFeeWizard.collectStreamingFee(IChamber(chamberAddress));

        // Check conditions
        assertEq(IERC20(chamberAddress).totalSupply(), currentSupply + inflationQuantity);
        assertEq(
            IERC20(chamberAddress).balanceOf(currentRecipient),
            currentFeeRecipientBalance + inflationQuantity
        );
        assertEq(streamingFeeWizard.getStreamingFeePercentage(IChamber(chamberAddress)), currentFee);

        // Cannot collect fees again in the same block
        vm.expectRevert(bytes("Cannot collect twice"));
        vm.prank(vm.addr(0x089172be3));
        streamingFeeWizard.collectStreamingFee(IChamber(chamberAddress));
        vm.expectRevert(bytes("Cannot collect twice"));
        vm.prank(vm.addr(0x086672be1));
        streamingFeeWizard.collectStreamingFee(IChamber(chamberAddress));

        // Check conditions
        assertEq(IERC20(chamberAddress).totalSupply(), currentSupply + inflationQuantity);
        assertEq(
            IERC20(chamberAddress).balanceOf(currentRecipient),
            currentFeeRecipientBalance + inflationQuantity
        );
        assertEq(streamingFeeWizard.getStreamingFeePercentage(IChamber(chamberAddress)), currentFee);
    }

    /**
     * [SUCCESS] Should collect fees when the fee is 100%. Supply should duplicate, and constituent quantities
     * should cut by half. This scenario is absurd but allowed. To avoid failure the min. quantity of a constituent
     * is set to 2 wei.
     */
    function testCollectAHundreadPercentFeesInAYear() public {
        // Create chamber with 100% fees
        address[] memory wizards = new address[](2);
        wizards[0] = issuerAddress;
        wizards[1] = feeWizardAddress;
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

        StreamingFeeWizard.FeeState memory feeState =
            StreamingFeeWizard.FeeState(address(this), 100 ether, 100 ether, 0); // 100% fee

        streamingFeeWizard.enableChamber(IChamber(address(someChamber)), feeState);

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

        // Time passes
        vm.warp(block.timestamp + (365.25 days)); // One year exactly

        // Calculate claimable fee
        uint256 currentFee =
            streamingFeeWizard.getStreamingFeePercentage(IChamber(address(someChamber)));
        uint256 currentTimestamp =
            streamingFeeWizard.getLastCollectTimestamp(IChamber(address(someChamber)));
        address currentRecipient =
            streamingFeeWizard.getStreamingFeeRecipient(IChamber(address(someChamber)));
        uint256 currentSupply = IERC20(address(someChamber)).totalSupply();
        uint256 currentQuantityToken1 =
            IChamber(address(someChamber)).getConstituentQuantity(token1);
        uint256 currentQuantityToken2 =
            IChamber(address(someChamber)).getConstituentQuantity(token2);
        uint256 inflationQuantity = streamingFeeWizard.calculateInflationQuantity(
            currentSupply, currentTimestamp, currentFee
        );
        uint256 currentFeeRecipientBalance =
            IERC20(address(someChamber)).balanceOf(currentRecipient);

        vm.expectEmit(true, false, false, true, address(streamingFeeWizard));
        emit FeeCollected(address(someChamber), currentFee, inflationQuantity);

        // Call
        vm.prank(vm.addr(0x779434283423b3));
        streamingFeeWizard.collectStreamingFee(IChamber(address(someChamber)));

        // Check conditions
        assertEq(IERC20(address(someChamber)).totalSupply(), currentSupply + inflationQuantity);
        assertGe(IERC20(address(someChamber)).totalSupply(), 2 * currentSupply);
        assertLe(
            IChamber(address(someChamber)).getConstituentQuantity(token1), currentQuantityToken1 / 2
        );
        assertLe(
            IChamber(address(someChamber)).getConstituentQuantity(token2), currentQuantityToken2 / 2
        );
        assertEq(
            IERC20(address(someChamber)).balanceOf(currentRecipient),
            currentFeeRecipientBalance + inflationQuantity
        );
        assertEq(
            streamingFeeWizard.getStreamingFeePercentage(IChamber(address(someChamber))), currentFee
        );
    }
}
