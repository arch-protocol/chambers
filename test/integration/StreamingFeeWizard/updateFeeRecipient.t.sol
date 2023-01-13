// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import "forge-std/Test.sol";
import {IChamber} from "../../../src/interfaces/IChamber.sol";
import {IssuerWizard} from "../../../src/IssuerWizard.sol";
import {Chamber} from "../../../src/Chamber.sol";
import {ChamberFactory} from "../../utils/factories.sol";
import {StreamingFeeWizard} from "../../../src/StreamingFeeWizard.sol";
import {IStreamingFeeWizard} from "src/interfaces/IStreamingFeeWizard.sol";

contract StreamingFeeWizardIntegrationUpdateFeeRecipientTest is Test {
    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event FeeRecipientUpdated(address indexed _chamber, address _newFeeRecipient);

    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/

    IChamber public chamber;
    IssuerWizard public issuerWizard;
    StreamingFeeWizard public streamingFeeWizard;
    ChamberFactory public chamberFactory;
    Chamber public globalChamber;
    IStreamingFeeWizard.FeeState public chamberFeeState;
    address public alice = vm.addr(0xe87809df12a1);
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

        streamingFeeWizard = new StreamingFeeWizard();
        feeWizardAddress = address(streamingFeeWizard);

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

        globalChamber =
            chamberFactory.getChamberWithCustomTokens(globalConstituents, globalQuantities);

        chamberAddress = address(globalChamber);

        chamberFeeState = IStreamingFeeWizard.FeeState(address(this), 100 ether, 2 ether, 0);
        streamingFeeWizard.enableChamber(IChamber(chamberAddress), chamberFeeState);

        vm.label(chamberGodAddress, "ChamberGod");
        vm.label(issuerAddress, "IssuerWizard");
        vm.label(feeWizardAddress, "FeeWizard");
        vm.label(chamberAddress, "Chamber");
        vm.label(address(chamberFactory), "ChamberFactory");
        vm.label(alice, "Alice");
        vm.label(token1, "HEX");
        vm.label(token2, "YFI");
    }

    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [REVERT] Chamber must exist in the Wizard beforehand
     */
    function testCannotUpdateFeeRecipientOfNonExistantChamber(address caller, address someChamber)
        public
    {
        vm.assume(someChamber != chamberAddress);
        vm.assume(caller != someChamber);
        vm.expectRevert(bytes("Chamber does not exist"));

        vm.prank(caller);
        streamingFeeWizard.updateFeeRecipient(IChamber(someChamber), caller);
    }

    /**
     * [REVERT] Only a Chamber's manager can update fee recipient
     */
    function testCannotUpdateFeeRecipientIfMsgSenderIsNotChamberManager(address caller) public {
        vm.assume(caller != address(this));
        vm.expectRevert(bytes("msg.sender is not chamber's manager"));

        vm.prank(caller);
        streamingFeeWizard.updateFeeRecipient(IChamber(chamberAddress), caller);
    }

    /**
     * [REVERT] Cannot set null wallet as recipient
     */
    function testCannotUpdateFeeRecipientWithNullAddress() public {
        vm.expectRevert(bytes("Recipient cannot be null address"));
        streamingFeeWizard.updateFeeRecipient(IChamber(chamberAddress), address(0));
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Anyone can add a Chamber to its FeeWizard contract and update recipient as they please.
     * As this method don't interact with the Chamber's internal state.
     */
    function testUpdateFeeRecipientIsPermissionlessToTheChamberManagerEvenIfWizardIsNotAllowedInChamber(
    ) public {
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
        streamingFeeWizard.updateFeeRecipient(IChamber(address(someChamber)), vm.addr(0x70123));
    }

    /**
     * [SUCCESS] Should execute updateFeeRecipient() with a correct wallet, and
     * check that the new state is set, and the event emitted.
     */
    function testUpdateFeeRecipient() public {
        address newRecipient = vm.addr(0x70123);
        vm.expectEmit(true, false, false, true, address(streamingFeeWizard));
        emit FeeRecipientUpdated(chamberAddress, newRecipient);
        streamingFeeWizard.updateFeeRecipient(IChamber(chamberAddress), newRecipient);

        address currentRecipient =
            streamingFeeWizard.getStreamingFeeRecipient(IChamber(chamberAddress));
        assertEq(currentRecipient, newRecipient);
    }
}
