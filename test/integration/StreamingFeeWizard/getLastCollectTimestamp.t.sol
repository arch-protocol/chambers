// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import "forge-std/Test.sol";
import {IChamber} from "src/interfaces/IChamber.sol";
import {IssuerWizard} from "src/IssuerWizard.sol";
import {Chamber} from "src/Chamber.sol";
import {ChamberFactory} from "test/utils/factories.sol";
import {StreamingFeeWizard} from "src/StreamingFeeWizard.sol";
import {IStreamingFeeWizard} from "src/interfaces/IStreamingFeeWizard.sol";

contract StreamingFeeWizardIntegrationGetLastCollectTimestampTest is Test {
    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/

    IChamber public chamber;
    IssuerWizard public issuerWizard;
    StreamingFeeWizard public streamingFeeWizard;
    ChamberFactory public chamberFactory;
    Chamber public globalChamber;
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
     * [REVERT] Should revert if asking for a chamber that does not exist
     */
    function testCannotLastCollectTimestampIfChamberDoesNotExist(
        address caller,
        address someChamber
    ) public {
        vm.assume(someChamber != chamberAddress);
        vm.assume(caller != someChamber);
        vm.expectRevert(bytes("Chamber does not exist"));

        vm.prank(caller);
        streamingFeeWizard.getLastCollectTimestamp(IChamber(someChamber));
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCESS] Should return the last collect timestamp if the chamber exists
     */
    function testLastCollectTimestamp(uint256 maxFeePercentage, uint256 feePercetange) public {
        vm.assume(maxFeePercentage < 100 ether);
        vm.assume(feePercetange <= maxFeePercentage);

        uint256 currentBlock = block.timestamp;
        IStreamingFeeWizard.FeeState memory chamberFeeState =
            IStreamingFeeWizard.FeeState(address(this), maxFeePercentage, feePercetange, 0);
        streamingFeeWizard.enableChamber(IChamber(chamberAddress), chamberFeeState);

        uint256 lastCollectTimestamp =
            streamingFeeWizard.getLastCollectTimestamp(IChamber(chamberAddress));

        assertEq(lastCollectTimestamp, currentBlock);
    }
}
