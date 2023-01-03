// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import "forge-std/Test.sol";
import {PreciseUnitMath} from "../../../src/lib/PreciseUnitMath.sol";

contract PreciseDivTest is Test {
    using PreciseUnitMath for uint256;

    /**
     * [REVERT] b = 0, then revert
     */
    function testPreciseDivBCannotBeZero(uint256 a, uint256 decimals) public {
        vm.assume(decimals > 0);
        vm.assume(decimals <= 18);
        vm.assume(a > 0);

        vm.expectRevert(bytes("Cannot divide by 0"));
        a.preciseDivCeil(0, decimals);
    }

    /**
     * [SUCESS] If a = 0, and b > 0, then:
     *
     * a.preciseDiv(b, decimals) == 0
     */
    function testPreciseDivShouldBeZeroIfAIsZero(uint256 b, uint256 decimals) public {
        vm.assume(decimals > 0);
        vm.assume(decimals <= 18);
        vm.assume(b > 0);
        vm.assume(b < type(uint256).max / (10 ** decimals));

        uint256 zero = 0;
        assertEq(zero.preciseDivCeil(b, decimals), 0);
    }

    /**
     * [SUCESS] If a = 1, b < 10ˆdecimals - 1, then:
     *
     * a.preciseDivCeil(b, decimals) == 1
     */
    function testPreciseDivCeilShouldBeOneWhenAIsOneAndBEqualsDecimalScale(
        uint256 b,
        uint256 decimals
    ) public {
        vm.assume(decimals > 0);
        vm.assume(decimals <= 18);
        vm.assume(b > 0);
        vm.assume(b < (10 ** decimals) - 1);

        uint256 a = 1;
        assertGe(a.preciseDivCeil(b, decimals), 2);
        assertLe(a.preciseDivCeil(b, decimals), 1 + (10 ** decimals) / b);
    }

    /**
     * [SUCESS] If a = 1, b = 10ˆdecimals - 1, then:
     *
     * a.preciseDivCeil(b, decimals) == 2
     */
    function testPreciseDivCeilShouldBeTwoWhenAIsOneAndBEqualsDecimalScaleMinusOne(uint256 decimals)
        public
    {
        vm.assume(decimals > 0);
        vm.assume(decimals <= 18);

        uint256 a = 1;
        uint256 b = (10 ** decimals) - 1;
        assertEq(a.preciseDivCeil(b, decimals), 2);
    }

    /**
     * [SUCESS] If a = 1, b = 10ˆdecimals, then:
     *
     * a.preciseDivCeil(b, decimals) == 1
     */
    function testPreciseDivCeilShouldBeOneWhenAIsOneAndBEqualsDecimalScale(uint256 decimals)
        public
    {
        vm.assume(decimals > 0);
        vm.assume(decimals <= 18);

        uint256 a = 1;
        uint256 b = 10 ** decimals;
        assertEq(a.preciseDivCeil(b, decimals), 1);
    }

    /**
     * [SUCESS] If a = 1, b > 10ˆdecimals, then:
     *
     * a.preciseDivCeil(b, decimals) == 1
     */
    function testPreciseDivCeilShouldBeOneWhenAIsOneAndBIsGreaterThanAScaled(
        uint256 b,
        uint256 decimals
    ) public {
        vm.assume(decimals > 0);
        vm.assume(decimals <= 18);
        vm.assume(b > 0);
        vm.assume(b > 10 ** decimals);

        uint256 a = 1;
        assertEq(a.preciseDivCeil(b, decimals), 1);
    }

    /**
     * [SUCESS] If a > 0, b > 0, and a * 10ˆdecimals < b, then:
     *
     * a.preciseDivCeil(b, decimals) == 1
     */
    function testPreciseDivWhenNumeratorIsLessThanDenominator(
        uint256 a,
        uint256 b,
        uint256 decimals
    ) public {
        vm.assume(decimals > 0);
        vm.assume(decimals <= 18);
        vm.assume(a > 0);
        vm.assume(a < type(uint256).max / (10 ** decimals));
        vm.assume(b > 0);
        vm.assume(b > a * (10 ** decimals));

        assertEq(a.preciseDivCeil(b, decimals), 1);
    }

    /**
     * [SUCESS] If a > 0, b < 10ˆdecimals, then:
     *
     * a.preciseDivCeil(b, decimals) <= 1 + (a * 10ˆdecimals) / b
     */
    function testPreciseDivAIsRandomValueBIsLessThanDecimals(uint256 a, uint256 b, uint256 decimals)
        public
    {
        vm.assume(a > 0);
        vm.assume(b > 0);
        vm.assume(decimals > 0);
        vm.assume(decimals <= 18);
        vm.assume(b <= 10 ** decimals);
        vm.assume(a < type(uint256).max / (10 ** decimals));

        assertGe(a.preciseDivCeil(b, decimals), ((a * (10 ** decimals) - 1) / b));
        assertLe(a.preciseDivCeil(b, decimals), 1 + ((a * (10 ** decimals)) / b));
    }

    /**
     * [SUCESS] If a > 0, b >= 10ˆdecimals, then:
     *
     * a.preciseDivCeil(b, decimals) == (a * 10ˆdecimals) / b
     */
    function testPreciseDivAIsRandomValueBIsGreaterEqualThanDecimals(
        uint256 a,
        uint256 b,
        uint256 decimals
    ) public {
        vm.assume(a > 0);
        vm.assume(b > 0);
        vm.assume(decimals > 0);
        vm.assume(decimals <= 18);
        vm.assume(b >= 10 ** decimals);
        vm.assume(a < type(uint256).max / (10 ** decimals));

        assertEq(a.preciseDivCeil(b, decimals), 1 + ((a * (10 ** decimals) - 1) / b));
    }
}
