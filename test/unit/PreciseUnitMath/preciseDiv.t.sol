// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import "forge-std/Test.sol";
import {PreciseUnitMath} from "../../../src/lib/PreciseUnitMath.sol";

contract PreciseUnitMathUnitPreciseDivTest is Test {
    using PreciseUnitMath for uint256;

    /**
     * [REVERT] b = 0, then revert
     */
    function testPreciseDivBCannotBeZero(uint256 a, uint256 decimals) public {
        vm.assume(decimals > 0);
        vm.assume(decimals <= 18);
        vm.assume(a > 0);

        vm.expectRevert(bytes("Cannot divide by 0"));
        a.preciseDiv(0, decimals);
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
        assertEq(zero.preciseDiv(b, decimals), 0);
    }

    /**
     * [SUCESS] If a = 1, b > a * 10ˆdecimals, then:
     *
     * a.preciseDiv(b, decimals) == 0
     */
    function testPreciseDivShouldBeZeroWhenAIsOneAndBIsGreaterThanAScaled(
        uint256 b,
        uint256 decimals
    ) public {
        vm.assume(decimals > 0);
        vm.assume(decimals <= 18);
        vm.assume(b > 0);
        vm.assume(b > 10 ** decimals);

        uint256 a = 1;
        assertEq(a.preciseDiv(b, decimals), 0);
    }

    /**
     * [SUCESS] If a > 0, b > 0, and a * 10ˆdecimals < b, then:
     *
     * a.preciseDiv(b, decimals) == 0
     *
     * We restrict b to avoid arithmetic overflow.
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

        assertEq(a.preciseDiv(b, decimals), 0);
    }

    /**
     * [SUCESS] If a > 0, b < 10ˆdecimals, then:
     *
     * a.preciseDiv(b, decimals) == (a * 10ˆdecimals) / b
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

        assertEq(a.preciseDiv(b, decimals), ((a * (10 ** decimals)) / b));
    }

    /**
     * [SUCESS] If a > 0, b >= 10ˆdecimals, then:
     *
     * a.preciseDiv(b, decimals) == (a * 10ˆdecimals) / b
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

        assertEq(a.preciseDiv(b, decimals), ((a * (10 ** decimals)) / b));
    }
}
