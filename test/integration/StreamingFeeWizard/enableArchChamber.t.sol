// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import "forge-std/Test.sol";
import {IChamber} from "../../../src/interfaces/IChamber.sol";
import {IssuerWizard} from "../../../src/IssuerWizard.sol";
import {Chamber} from "../../../src/Chamber.sol";
import {ChamberFactory} from "../../utils/factories.sol";
import {StreamingFeeWizard} from "../../../src/StreamingFeeWizard.sol";

contract StreamingFeeWizardIntegrationEnableChamberTest is Test {
    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/

    IChamber public chamber;
    IssuerWizard public issuerWizard;
    StreamingFeeWizard public streamingFeeWizard;
    ChamberFactory public chamberFactory;
    Chamber public globalChamber;
    StreamingFeeWizard.FeeState public chamberFeeState;
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

        chamberFeeState = StreamingFeeWizard.FeeState(address(this), 100 ether, 80 ether, 0);
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
     * [REVERT] Only a Chamber's manager can add his chamber to this wizard
     */
    function testCannotEnableChamberIfMsgSenderIsNotAChamberManager(address caller) public {
        vm.assume(caller != address(this));

        Chamber someChamber =
            chamberFactory.getChamberWithCustomTokens(globalConstituents, globalQuantities);

        StreamingFeeWizard.FeeState memory customFeeState =
            StreamingFeeWizard.FeeState(address(this), 100 ether, 80 ether, 0);

        vm.expectRevert(bytes("msg.sender is not chamber's manager"));
        vm.prank(caller);
        streamingFeeWizard.enableChamber(IChamber(address(someChamber)), customFeeState);
    }

    /**
     * [REVERT] Should revert if the recipient specified in the FeeState is the null address
     */
    function testCannotEnableChamberIfRecipientIsNullWallet() public {
        Chamber someChamber =
            chamberFactory.getChamberWithCustomTokens(globalConstituents, globalQuantities);

        StreamingFeeWizard.FeeState memory customFeeState =
            StreamingFeeWizard.FeeState(address(0), 100 ether, 80 ether, 0);

        vm.expectRevert(bytes("Recipient cannot be null address"));
        streamingFeeWizard.enableChamber(IChamber(address(someChamber)), customFeeState);
    }

    /**
     * [REVERT] Should revert if the max. fee is above 100%
     */
    function testCannotEnableChamberIfMaxFeeIsAboveOneHundredPercent() public {
        Chamber someChamber =
            chamberFactory.getChamberWithCustomTokens(globalConstituents, globalQuantities);

        StreamingFeeWizard.FeeState memory customFeeState =
            StreamingFeeWizard.FeeState(address(this), 100 ether + 1, 80 ether, 0);

        vm.expectRevert(bytes("Max fee must be <= 100%"));
        streamingFeeWizard.enableChamber(IChamber(address(someChamber)), customFeeState);
    }

    /**
     * [REVERT] Should revert if the chamber streaming fee is above max specified in the same struct
     */
    function testCannotEnableChamberIfFeeIsAboveMaximum() public {
        Chamber someChamber =
            chamberFactory.getChamberWithCustomTokens(globalConstituents, globalQuantities);

        StreamingFeeWizard.FeeState memory customFeeState =
            StreamingFeeWizard.FeeState(address(this), 40 ether, 45 ether, 0);

        vm.expectRevert(bytes("Fee must be <= Max fee"));
        streamingFeeWizard.enableChamber(IChamber(address(someChamber)), customFeeState);
    }

    /**
     * [REVERT] Shoudl revert if trying to enable a Chamber that already exists
     */
    function testCannotEnableChamberIfItAlreadyExists() public {
        StreamingFeeWizard.FeeState memory customFeeState =
            StreamingFeeWizard.FeeState(address(this), 40 ether, 35 ether, 0);

        vm.expectRevert(bytes("Chamber already exists"));
        streamingFeeWizard.enableChamber(IChamber(chamberAddress), customFeeState);
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCESS] Should enable a chamber in the wizard if the struct provided is ok. Check
     * that the lastTimestamp is the current block.timestamp
     */
    function testEnableChamberShouldCreateAChamberInTheWizard() public {
        Chamber someChamber =
            chamberFactory.getChamberWithCustomTokens(globalConstituents, globalQuantities);
        StreamingFeeWizard.FeeState memory customFeeState =
            StreamingFeeWizard.FeeState(address(this), 30 ether, 8.1 ether, 0);

        streamingFeeWizard.enableChamber(IChamber(address(someChamber)), customFeeState);

        assertEq(
            streamingFeeWizard.getStreamingFeeRecipient(IChamber(address(someChamber))),
            address(this)
        );
        assertEq(
            streamingFeeWizard.getMaxStreamingFeePercentage(IChamber(address(someChamber))),
            30 ether
        );
        assertEq(
            streamingFeeWizard.getStreamingFeePercentage(IChamber(address(someChamber))), 8.1 ether
        );
        assertEq(
            streamingFeeWizard.getLastCollectTimestamp(IChamber(address(someChamber))),
            block.timestamp
        );
    }
}
