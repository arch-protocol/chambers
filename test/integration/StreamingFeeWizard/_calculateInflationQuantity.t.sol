// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import "forge-std/Test.sol";
import {ExposedStreamingFeeWizard} from "test/utils/exposedContracts/ExposedStreamingFeeWizard.sol";

contract StreamingFeeWizardIntegrationInternalCalculateInflationQuantityTest is Test {
    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/

    ExposedStreamingFeeWizard public streamingFeeWizard;
    address public feeWizardAddress;

    /*//////////////////////////////////////////////////////////////
                              SET UP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        streamingFeeWizard = new ExposedStreamingFeeWizard();
        feeWizardAddress = address(streamingFeeWizard);
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCESS] Should return 0 when lastCollectTimestamp is on the same block as the call
     */
    function testCalculateInflationQuantityShouldReturnZeroWhenCalledOnTheSameBlock(
        uint256 currentFee,
        uint256 currentSupply
    ) public {
        vm.assume(currentFee > 0);
        vm.assume(currentFee <= 100 ether);
        vm.assume(currentSupply > 0);
        vm.assume(currentSupply <= type(uint64).max);

        uint256 inflationQuantity = streamingFeeWizard.calculateInflationQuantity(
            currentSupply, block.timestamp, currentFee
        );

        assertEq(inflationQuantity, 0);
    }

    /**
     * [SUCESS] Should return 0 when supply is zero
     */
    function testCalculateInflationQuantityShouldReturnZeroWhenSupplyIsZero(
        uint256 currentFee,
        uint256 secondsElapsed
    ) public {
        vm.assume(currentFee > 0);
        vm.assume(currentFee <= 100 ether);
        vm.assume(secondsElapsed > 0);
        vm.assume(secondsElapsed < block.timestamp);

        uint256 inflationQuantity = streamingFeeWizard.calculateInflationQuantity(
            0, block.timestamp - secondsElapsed, currentFee
        );

        assertEq(inflationQuantity, 0);
    }

    /**
     * [SUCESS] Should return 0 when streaming fee percentage is zero
     */
    function testCalculateInflationQuantityShouldReturnZeroWhenStreamingFeeIsZero(
        uint256 currentSupply,
        uint256 secondsElapsed
    ) public {
        vm.assume(currentSupply > 0);
        vm.assume(currentSupply <= type(uint64).max);
        vm.assume(secondsElapsed > 0);
        vm.assume(secondsElapsed < block.timestamp);

        uint256 inflationQuantity = streamingFeeWizard.calculateInflationQuantity(
            currentSupply, block.timestamp - secondsElapsed, 0
        );

        assertEq(inflationQuantity, 0);
    }

    /**
     * [SUCESS] Should return 'years' times the fees for years passed
     */
    function testCalculateInflationQuantityShouldReturnCorrectValueAfterYears(
        uint256 currentFee,
        uint256 currentSupply,
        uint256 _years
    ) public {
        vm.assume(currentFee > 0);
        vm.assume(currentFee <= 100 ether);
        vm.assume(currentSupply > 0);
        vm.assume(currentSupply <= type(uint64).max);
        vm.assume(_years > 0);
        vm.assume(_years < block.timestamp / 365.25 days);

        uint256 inflationQuantity = streamingFeeWizard.calculateInflationQuantity(
            currentSupply, block.timestamp - (_years * 365.25 days), currentFee
        );

        assertEq(inflationQuantity, (_years * currentFee * currentSupply) / (100 ether));
    }

    /**
     * [SUCESS] Should return the correct value for a 1 day window time
     */
    function testCalculateInflationQuantityShouldReturnCorrectValueForOneDayWIndowTime(
        uint256 currentFee,
        uint256 currentSupply,
        uint256 _days
    ) public {
        vm.assume(currentFee > 0);
        vm.assume(currentFee <= 100 ether);
        vm.assume(currentSupply > 0);
        vm.assume(currentSupply <= type(uint64).max);
        vm.assume(_days > 0);
        vm.assume(_days < block.timestamp / 1 days);

        uint256 inflationQuantity = streamingFeeWizard.calculateInflationQuantity(
            currentSupply, block.timestamp - (_days * 1 days), currentFee
        );

        assertEq(
            inflationQuantity,
            (_days * 1 days * currentFee * currentSupply) / (365.25 days * 100 ether)
        );
    }
}
