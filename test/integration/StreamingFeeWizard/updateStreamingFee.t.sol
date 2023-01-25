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
import {StreamingFeeWizard} from "src/StreamingFeeWizard.sol";
import {ExposedStreamingFeeWizard} from "test/utils/exposedContracts/ExposedStreamingFeeWizard.sol";
import {PreciseUnitMath} from "src/lib/PreciseUnitMath.sol";
import {IStreamingFeeWizard} from "src/interfaces/IStreamingFeeWizard.sol";

contract StreamingFeeWizardIntegrationUpdateStreamingFeeTest is Test {
    using PreciseUnitMath for uint256;

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 value);
    event FeeCollected(
        address indexed _chamber, uint256 _streamingFeePercentage, uint256 inflationQuantity
    );
    event StreamingFeeUpdated(address indexed _chamber, uint256 _newStreamingFee);

    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/

    IChamber public chamber;
    IssuerWizard public issuerWizard;
    ExposedStreamingFeeWizard public streamingFeeWizard;
    ChamberFactory public chamberFactory;
    Chamber public globalChamber;
    IStreamingFeeWizard.FeeState public chamberFeeState;
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

        issuerWizard = new IssuerWizard(chamberGodAddress);
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
     * [REVERT] Chamber must exist in the Wizard beforehand
     */
    function testCannotUpdateStreamingFeeOfNonExistantChamber(address caller, address someChamber)
        public
    {
        vm.assume(someChamber != chamberAddress);
        vm.assume(caller != someChamber);
        vm.expectRevert(bytes("Chamber does not exist"));

        vm.prank(caller);
        streamingFeeWizard.updateStreamingFee(IChamber(someChamber), 1 ether);
    }

    /**
     * [REVERT] Only a Chamber's manager can update the streaming fee
     */
    function testCannotUpdateStreamingFeeIfMsgSenderIsNotChamberManager(address caller) public {
        vm.assume(caller != address(this));

        // Time passes
        vm.warp(block.timestamp + 10);

        vm.expectRevert(bytes("msg.sender is not chamber's manager"));
        vm.prank(caller);
        streamingFeeWizard.updateStreamingFee(IChamber(chamberAddress), 1 ether);
    }

    /**
     * [REVERT] Cannot set a fee above maximum
     */
    function testCannotUpdateStreamingFeeAboveMaximum(uint256 newFee) public {
        uint256 currentMaximum =
            streamingFeeWizard.getMaxStreamingFeePercentage(IChamber(chamberAddress));
        vm.assume(newFee > currentMaximum);

        // Time passes
        vm.warp(block.timestamp + 10);

        vm.expectRevert(bytes("New fee is above maximum"));
        streamingFeeWizard.updateStreamingFee(IChamber(chamberAddress), newFee);
    }

    /**
     * [REVERT] Cannot update fee in the same block that enables the chamber
     */
    function testCannotUpdateFeeInTheSameBlockAsEnablingChamber(uint256 newFee) public {
        vm.expectRevert(bytes("Cannot update fee after collecting"));
        streamingFeeWizard.updateStreamingFee(IChamber(chamberAddress), newFee);
    }

    /**
     * [REVERT] Cannot update fee in the same block that collects fees
     */
    function testCannotUpdateFeeInTheSameBlockAsCollectingFee(uint256 newFee) public {
        // Add initial suuply
        uint256 initialSupply = 30 ether;

        deal(token1, aliceTheSorcerer, initialSupply.preciseMulCeil(globalQuantities[0], 18));
        deal(token2, aliceTheSorcerer, initialSupply.preciseMulCeil(globalQuantities[1], 18));
        vm.prank(aliceTheSorcerer);
        IERC20(token1).approve(issuerAddress, initialSupply.preciseMulCeil(globalQuantities[0], 18));
        vm.prank(aliceTheSorcerer);
        IERC20(token2).approve(issuerAddress, initialSupply.preciseMulCeil(globalQuantities[1], 18));

        vm.prank(aliceTheSorcerer);
        issuerWizard.issue(IChamber(address(chamberAddress)), initialSupply);

        // Time passes
        vm.warp(block.timestamp + 100000);

        uint256 currentFee = streamingFeeWizard.getStreamingFeePercentage(IChamber(chamberAddress));

        // Collect fee
        streamingFeeWizard.collectStreamingFee(IChamber(chamberAddress));

        // Cannot update fee in the same block
        vm.expectRevert(bytes("Cannot update fee after collecting"));
        streamingFeeWizard.updateStreamingFee(IChamber(chamberAddress), newFee);

        uint256 lastFee = streamingFeeWizard.getStreamingFeePercentage(IChamber(chamberAddress));
        assertEq(lastFee, currentFee);
    }

    /**
     * [REVERT] Anyone can add a Chamber to its FeeWizard contract, BUT if chamber supply and fee is greater than zero, NONE should be
     * able to update the streaming fee as they please, because the update calls collectFees() that access the mint() function
     * in the chamber restricted to onlyWizards() that are previously allowed in the chamber. Collecting fees won't work as long
     * as the Chamber don't have the wizard added to their wizard's whitelist.
     */
    function testCannotUpdateStreamingFeeWhenFeeAndSupplyIsGreaterThanZeroAndManagerCallsButFailsWhenMint(
    ) public {
        address[] memory wizards = new address[](2); // ExposedStreamingFeeWizard is not allowed to call onlyWizard methods in chamber
        wizards[0] = issuerAddress;
        wizards[1] = aliceTheSorcerer;
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

        // Time passes
        vm.warp(block.timestamp + 100000);

        // Change fee percentage
        uint256 newFee = 81 ether;
        uint256 currentMaximum =
            streamingFeeWizard.getMaxStreamingFeePercentage(IChamber(address(someChamber)));
        vm.assume(newFee <= currentMaximum);

        uint256 currentFee =
            streamingFeeWizard.getStreamingFeePercentage(IChamber(address(someChamber)));
        uint256 currentTimestamp =
            streamingFeeWizard.getLastCollectTimestamp(IChamber(address(someChamber)));
        address currentRecipient =
            streamingFeeWizard.getStreamingFeeRecipient(IChamber(address(someChamber)));
        uint256 currentSupply = IERC20(address(someChamber)).totalSupply();
        uint256 inflationQuantity = streamingFeeWizard.calculateInflationQuantity(
            currentSupply, currentTimestamp, currentFee
        );
        uint256 currentFeeRecipientBalance =
            IERC20(address(someChamber)).balanceOf(currentRecipient);

        vm.expectCall(
            address(someChamber),
            abi.encodeCall(IChamber(address(someChamber)).isManager, (address(this)))
        );
        vm.expectCall(
            address(someChamber), abi.encodeCall(IERC20(address(someChamber)).totalSupply, ())
        );
        vm.expectCall(
            address(someChamber),
            abi.encodeCall(IChamber(address(someChamber)).mint, (address(this), inflationQuantity))
        );

        // Call
        vm.expectRevert(bytes("Must be a wizard"));
        streamingFeeWizard.updateStreamingFee(IChamber(address(someChamber)), newFee);

        // Assertions
        uint256 newSupply = IERC20(address(someChamber)).totalSupply();
        uint256 newFeeRecipientBalance = IERC20(address(someChamber)).balanceOf(currentRecipient);
        uint256 newFeeUpdated =
            streamingFeeWizard.getStreamingFeePercentage(IChamber(address(someChamber)));
        assertEq(newSupply, currentSupply);
        assertEq(newFeeRecipientBalance, currentFeeRecipientBalance);
        assertEq(newFeeUpdated, currentFee);
    }

    /**
     * [REVERT] Anyone can add a Chamber to its FeeWizard contract, BUT if chamber supply is zero AND fee is greater than zero,
     * NONE should be able to update the streaming fee as they please, because the update calls collectFees() that access the mint()
     * function, with 0 as input, in the chamber, that is restricted to onlyWizards() that are previously allowed in the chamber.
     * Collecting fees won't work as long as the Chamber don't have the wizard added to their wizard's whitelist. Even if the amount is zero.
     */
    function testCannotUpdateStreamingFeeWhenFeeOnlyIsGreaterThanZeroAndManagerCallsButFailsWhenMint(
    ) public {
        address[] memory wizards = new address[](0); // ExposedStreamingFeeWizard is not allowed to call onlyWizard methods in chamber
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

        // Time passes, no supply
        vm.warp(block.timestamp + 100000);

        vm.expectRevert(bytes("Must be a wizard"));
        streamingFeeWizard.updateStreamingFee(IChamber(address(someChamber)), 81 ether);
    }

    /**
     * [REVERT] Anyone can add a Chamber to its FeeWizard contract, BUT if chamber supply is greater than zero AND initial fee is zero,
     * The manager should be able to update the streaming fee ONCE, because the update SKIPS the call to mint() in the chamber, as
     * the previous fee was zero. If the next fee if zero again, it will skip the call to mint(), and the manager can call this method
     * AS MANY TIMES as pleased.
     */
    function testCannotUpdateStreamingFeeWhenFeesZeroAndSupplyIsGreaterThanZeroAndManagerCallsButFailsWhenMint(
    ) public {
        address[] memory wizards = new address[](2); // ExposedStreamingFeeWizard is not allowed to call onlyWizard methods in chamber
        wizards[0] = issuerAddress;
        wizards[1] = aliceTheSorcerer;
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

        IStreamingFeeWizard.FeeState memory feeState =
            IStreamingFeeWizard.FeeState(address(this), 100 ether, 0 ether, 0);
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

        // Change fee percentage to zero again
        uint256 zeroFee = 0 ether;
        address currentRecipient =
            streamingFeeWizard.getStreamingFeeRecipient(IChamber(address(someChamber)));
        uint256 currentSupply = IERC20(address(someChamber)).totalSupply();
        uint256 currentFeeRecipientBalance =
            IERC20(address(someChamber)).balanceOf(currentRecipient);

        // Time passes + call with zero again and again
        vm.warp(block.timestamp + 100000);
        streamingFeeWizard.updateStreamingFee(IChamber(address(someChamber)), zeroFee);
        vm.warp(block.timestamp + 100001);
        streamingFeeWizard.updateStreamingFee(IChamber(address(someChamber)), zeroFee);
        vm.warp(block.timestamp + 100002);
        streamingFeeWizard.updateStreamingFee(IChamber(address(someChamber)), zeroFee);

        // Call + change ONCE above zero
        vm.warp(block.timestamp + 100003);
        uint256 validFeeOnce = 81 ether;
        streamingFeeWizard.updateStreamingFee(IChamber(address(someChamber)), validFeeOnce);

        // Call should fail as the function calls mint() in the chamber
        vm.warp(block.timestamp + 100004);
        vm.expectRevert(bytes("Must be a wizard"));
        streamingFeeWizard.updateStreamingFee(IChamber(address(someChamber)), 82 ether);

        // Assertions that nothing changed in the chamber state since the beginning
        uint256 newSupply = IERC20(address(someChamber)).totalSupply();
        uint256 newFeeRecipientBalance = IERC20(address(someChamber)).balanceOf(currentRecipient);
        uint256 newFeeUpdated =
            streamingFeeWizard.getStreamingFeePercentage(IChamber(address(someChamber)));
        assertEq(newSupply, currentSupply);
        assertEq(newFeeRecipientBalance, currentFeeRecipientBalance);
        assertEq(newFeeUpdated, validFeeOnce);
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Anyone can add a Chamber to its FeeWizard contract and update streaming fee as they please, but
     * ONLY once in a block.
     */
    function testUpdateStreamingFeeIsPermissionLessToTheManagerAndIsAbleToCallItWhenSupplyAndFeeAreZeroOnce(
    ) public {
        address[] memory wizards = new address[](0); // ExposedStreamingFeeWizard is not allowed to call onlyWizard methods in chamber
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

        IStreamingFeeWizard.FeeState memory feeState =
            IStreamingFeeWizard.FeeState(address(this), 100 ether, 0 ether, 0);

        streamingFeeWizard.enableChamber(IChamber(address(someChamber)), feeState);

        // Time passes
        vm.warp(block.timestamp + 1);

        streamingFeeWizard.updateStreamingFee(IChamber(address(someChamber)), 81 ether);
        vm.expectRevert(bytes("Cannot update fee after collecting"));
        streamingFeeWizard.updateStreamingFee(IChamber(address(someChamber)), 80 ether);
        vm.expectRevert(bytes("Cannot update fee after collecting"));
        streamingFeeWizard.updateStreamingFee(IChamber(address(someChamber)), 79 ether);
    }

    /**
     * [SUCCESS] Should execute updateStreamingFee() with correct params and check
     * that fees are collected, the new state is set, and events are emitted.
     */
    function testUpdateStreamingFee(uint256 newFee) public {
        // Add initial suuply
        uint256 initialSupply = 30 ether;

        deal(token1, aliceTheSorcerer, initialSupply.preciseMulCeil(globalQuantities[0], 18));
        deal(token2, aliceTheSorcerer, initialSupply.preciseMulCeil(globalQuantities[1], 18));
        vm.prank(aliceTheSorcerer);
        IERC20(token1).approve(issuerAddress, initialSupply.preciseMulCeil(globalQuantities[0], 18));
        vm.prank(aliceTheSorcerer);
        IERC20(token2).approve(issuerAddress, initialSupply.preciseMulCeil(globalQuantities[1], 18));

        vm.prank(aliceTheSorcerer);
        issuerWizard.issue(IChamber(address(chamberAddress)), initialSupply);

        // Time passes
        vm.warp(block.timestamp + 100000);

        // Change fee percentage
        uint256 currentMaximum =
            streamingFeeWizard.getMaxStreamingFeePercentage(IChamber(chamberAddress));
        vm.assume(newFee <= currentMaximum);

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

        vm.expectCall(
            chamberAddress, abi.encodeCall(IChamber(chamberAddress).isManager, (address(this)))
        );
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
        vm.expectEmit(true, false, false, true, address(streamingFeeWizard));
        emit StreamingFeeUpdated(chamberAddress, newFee);

        streamingFeeWizard.updateStreamingFee(IChamber(chamberAddress), newFee);

        uint256 newSupply = IERC20(chamberAddress).totalSupply();
        uint256 newFeeRecipientBalance = IERC20(chamberAddress).balanceOf(currentRecipient);
        uint256 newFeeUpdated =
            streamingFeeWizard.getStreamingFeePercentage(IChamber(chamberAddress));
        assertEq(newSupply, currentSupply + inflationQuantity);
        assertEq(newFeeRecipientBalance, currentFeeRecipientBalance + inflationQuantity);
        assertEq(newFeeUpdated, newFee);
    }
}
