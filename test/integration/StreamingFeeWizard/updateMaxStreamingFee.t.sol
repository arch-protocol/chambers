// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import "forge-std/Test.sol";
import {IChamber} from "../../../src/interfaces/IChamber.sol";
import {Chamber} from "../../../src/Chamber.sol";
import {ChamberFactory} from "../../utils/factories.sol";
import {StreamingFeeWizard} from "../../../src/StreamingFeeWizard.sol";
import {IStreamingFeeWizard} from "src/interfaces/IStreamingFeeWizard.sol";

contract StreamingFeeWizardIntegrationUpdateMaxStreamingFeeTest is Test {
    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event MaxStreamingFeeUpdated(address indexed _chamber, uint256 _newMaxStreamingFee);

    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/

    IChamber public chamber;
    StreamingFeeWizard public streamingFeeWizard;
    ChamberFactory public chamberFactory;
    Chamber public globalChamber;
    IStreamingFeeWizard.FeeState public chamberFeeState;
    address public feeWizardAddress;
    address public chamberAddress;
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

        streamingFeeWizard = new StreamingFeeWizard();
        feeWizardAddress = address(streamingFeeWizard);

        address[] memory wizards = new address[](1);
        wizards[0] = feeWizardAddress;
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

        vm.label(feeWizardAddress, "FeeWizard");
        vm.label(chamberAddress, "Chamber");
        vm.label(address(chamberFactory), "ChamberFactory");
        vm.label(token1, "HEX");
        vm.label(token2, "YFI");
    }

    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [REVERT] Chamber must exist in the Wizard beforehand
     */
    function testCannotUpdateMaxStreamingFeeOfNonExistantChamber(
        address caller,
        address someChamber
    ) public {
        vm.assume(someChamber != chamberAddress);
        vm.assume(caller != someChamber);
        vm.expectRevert(bytes("Chamber does not exist"));

        vm.prank(caller);
        streamingFeeWizard.updateMaxStreamingFee(IChamber(someChamber), 1 ether);
    }

    /**
     * [REVERT] Only a Chamber's manager can update the max streaming fee
     */
    function testCannotUpdateMaxStreamingFeeIfMsgSenderIsNotChamberManager(address caller) public {
        vm.assume(caller != address(this));
        vm.expectRevert(bytes("msg.sender is not chamber's manager"));

        vm.prank(caller);
        streamingFeeWizard.updateMaxStreamingFee(IChamber(chamberAddress), 1 ether);
    }

    /**
     * [REVERT] Cannot set a max. fee above current maximum
     */
    function testCannotUpdateMaxStreamingFeeAboveCurrentMaximum(uint256 newMax) public {
        uint256 currentMaximum =
            streamingFeeWizard.getMaxStreamingFeePercentage(IChamber(chamberAddress));
        vm.assume(newMax > currentMaximum);

        vm.expectRevert(bytes("New max fee is above maximum"));
        streamingFeeWizard.updateMaxStreamingFee(IChamber(chamberAddress), newMax);
    }

    /**
     * [REVERT] Cannot set a max. fee below current fee
     */
    function testCannotUpdateMaxStreamingFeeBelowCurrentFee(uint256 newMax) public {
        uint256 currentFee = streamingFeeWizard.getStreamingFeePercentage(IChamber(chamberAddress));
        vm.assume(newMax <= currentFee);

        vm.expectRevert(bytes("New max fee is below current fee"));
        streamingFeeWizard.updateMaxStreamingFee(IChamber(chamberAddress), newMax);
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Anyone can add a Chamber to its FeeWizard contract and update max. streaming fee as they please.
     * As this method don't interact with the Chamber's internal state.
     */
    function testUpdateMaxStreamingFeeIsPermissionLessToTheManagerButCollectFeesDoesNot() public {
        address[] memory wizards = new address[](0); // StreamingFeeWizard is not allowed to call onlyWizard methods in chamber
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
        streamingFeeWizard.updateMaxStreamingFee(IChamber(address(someChamber)), 81 ether);
    }

    /**
     * [SUCCESS] Should execute updateMaxStreamingFee() with correct params and check
     * that the new state is set, and the event emitted.
     */
    function testUpdateMaxStreamingFee(uint256 newMaxFee) public {
        uint256 currentFee = streamingFeeWizard.getStreamingFeePercentage(IChamber(chamberAddress));
        uint256 currentMaxFee =
            streamingFeeWizard.getMaxStreamingFeePercentage(IChamber(chamberAddress));
        vm.assume(newMaxFee >= currentFee);
        vm.assume(newMaxFee <= currentMaxFee);

        vm.expectEmit(true, false, false, true, address(streamingFeeWizard));
        emit MaxStreamingFeeUpdated(chamberAddress, newMaxFee);
        streamingFeeWizard.updateMaxStreamingFee(IChamber(chamberAddress), newMaxFee);

        uint256 updatedMaxFee =
            streamingFeeWizard.getMaxStreamingFeePercentage(IChamber(chamberAddress));
        assertEq(updatedMaxFee, newMaxFee);
    }

    /**
     * [SUCCESS] Should update the max. fee to the current streaming fee
     */
    function testUpdateMaxStreamingFeeToCurrentStreamingFee() public {
        uint256 currentFee = streamingFeeWizard.getStreamingFeePercentage(IChamber(chamberAddress));
        vm.expectEmit(true, false, false, true, address(streamingFeeWizard));
        emit MaxStreamingFeeUpdated(chamberAddress, currentFee);
        streamingFeeWizard.updateMaxStreamingFee(IChamber(chamberAddress), currentFee);

        uint256 updatedMaxFee =
            streamingFeeWizard.getMaxStreamingFeePercentage(IChamber(chamberAddress));
        assertEq(updatedMaxFee, currentFee);
    }
}
