// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import "forge-std/Test.sol";
import {PreciseUnitMath} from "src/lib/PreciseUnitMath.sol";

contract PreciseUnitMathUnitPreciseMulCeilTest is Test {
    using PreciseUnitMath for uint256;

    /**
     * Square root function used to restict some values in the tests
     */
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    /**
     * [SUCESS] If a = 0, and b > 0, then:
     *
     * a.mulCeil(b, decimals) = 0
     */
    function testPreciseMulCeilShouldBeZeroIfAOIsZero(uint256 b, uint256 decimals) public {
        vm.assume(b > 0);
        vm.assume(decimals > 0);
        vm.assume(decimals <= 18);

        uint256 a = 0;
        assertEq(a.preciseMulCeil(b, decimals), 0);
    }

    /**
     * [SUCESS] If b = 0, and a > 0, then:
     *
     * a.mulCeil(b, decimals) = 0
     */
    function testPreciseMulCeilShouldBeZeroIfBOIsZero(uint256 a, uint256 decimals) public {
        vm.assume(a > 0);
        vm.assume(decimals > 0);
        vm.assume(decimals <= 18);

        uint256 b = 0;
        assertEq(a.preciseMulCeil(b, decimals), 0);
    }

    /**
     * [SUCESS] If a = 1, b > 2, b <= 10ˆdecimals then:
     *
     * a.mulCeil(b, decimals) == 1
     */
    function testPreciseMulCeilShouldBeOneIfAIsOneAndBIsLessOrEqualThanScale(
        uint256 b,
        uint256 decimals
    ) public {
        vm.assume(decimals > 0);
        vm.assume(decimals <= 18);
        vm.assume(b > 2);
        vm.assume(b <= 10 ** decimals);

        uint256 a = 1;
        assertEq(a.preciseMulCeil(b, decimals), 1);
    }

    /**
     * [SUCESS] If b = 1, a > 2, a <= 10ˆdecimals then:
     *
     * a.mulCeil(b, decimals) == 1
     */
    function testPreciseMulCeilShouldBeOneIfBIsOneAndAIsLessOrEqualThanScale(
        uint256 a,
        uint256 decimals
    ) public {
        vm.assume(decimals > 0);
        vm.assume(decimals <= 18);
        vm.assume(a > 2);
        vm.assume(a <= 10 ** decimals);

        uint256 b = 1;
        assertEq(a.preciseMulCeil(b, decimals), 1);
    }

    /**
     * [SUCESS] If a = 1, b > 0, then:
     *
     * a.mulCeil(b, decimals) >= b / 10ˆdecimals
     * a.mulCeil(b, decimals) <= b / 10ˆdecimals + 1
     */
    function testPreciseMulCeilShouldRoundUpWhenAIsOne(uint256 b, uint256 decimals) public {
        vm.assume(b > 0);
        vm.assume(decimals > 0);
        vm.assume(decimals <= 18);

        uint256 a = 1;
        assertGe(a.preciseMulCeil(b, decimals), (b / (10 ** decimals)));
        assertLe(a.preciseMulCeil(b, decimals), (b / (10 ** decimals)) + 1);
    }

    /**
     * [SUCESS] If b = 1, a > 0, then:
     *
     * a.mulCeil(b, decimals) >= a / 10ˆdecimals
     * a.mulCeil(b, decimals) <= a / 10ˆdecimals + 1
     */
    function testPreciseMulCeilShouldRoundUpWhenBIsOne(uint256 a, uint256 decimals) public {
        vm.assume(a > 0);
        vm.assume(decimals > 0);
        vm.assume(decimals <= 18);

        uint256 b = 1;
        assertGe(a.preciseMulCeil(b, decimals), (a / (10 ** decimals)));
        assertLe(a.preciseMulCeil(b, decimals), (a / (10 ** decimals)) + 1);
    }

    /**
     * [SUCESS] If a > 0, b > 0, and b < sqrt(uint256.max), and a <= b, then:
     *
     * a.mulCeil(b, decimals) >= (a * b) / 10ˆdecimals
     * a.mulCeil(b, decimals) <= (a * b) / 10ˆdecimals + 1
     *
     * We restrict b to avoid arithmetic overflow.
     */
    function testPreciseMulCeilShouldRoundUpWhenAIsLessOrEqualB(
        uint256 a,
        uint256 b,
        uint256 decimals
    ) public {
        vm.assume(a > 0);
        vm.assume(b > 0);
        vm.assume(decimals > 0);
        vm.assume(decimals <= 18);
        vm.assume(b < sqrt(type(uint256).max));
        vm.assume(a <= b);

        uint256 result = (a * b) / (10 ** decimals);
        assertGe(a.preciseMulCeil(b, decimals), result);
        assertLe(a.preciseMulCeil(b, decimals), result + 1);
    }

    /**
     * [SUCESS] If b > 0, a > 0, and a < sqrt(uint256.max), and b <= a, then:
     *
     * a.mulCeil(b, decimals) >= (a * b) / 10ˆdecimals
     * a.mulCeil(b, decimals) <= (a * b) / 10ˆdecimals + 1
     *
     * We restrict a to avoid arithmetic overflow.
     */
    function testPreciseMulCeilShouldRoundUpWhenBIsLessOrEqualA(
        uint256 a,
        uint256 b,
        uint256 decimals
    ) public {
        vm.assume(b > 0);
        vm.assume(a > 0);
        vm.assume(decimals > 0);
        vm.assume(decimals <= 18);
        vm.assume(a < sqrt(type(uint256).max));
        vm.assume(b <= a);

        uint256 result = (a * b) / (10 ** decimals);
        assertGe(a.preciseMulCeil(b, decimals), result);
        assertLe(a.preciseMulCeil(b, decimals), result + 1);
    }

    /**
     * [SUCESS] If a > 0, b < 10ˆdecimals, then:
     *
     * a.mulCeil(b, decimals) >= (a * b) / 10ˆdecimals
     * a.mulCeil(b, decimals) <= (a * b) / 10ˆdecimals + 1
     */
    function testPreciseMulCeilAIsRandomValueBIsLessThanDecimals(
        uint256 a,
        uint256 b,
        uint256 decimals
    ) public {
        vm.assume(a > 0);
        vm.assume(b > 0);
        vm.assume(decimals > 0);
        vm.assume(decimals <= 18);
        vm.assume(b <= 10 ** decimals);
        vm.assume(a < sqrt(type(uint256).max));

        uint256 result = ((a * b) / (10 ** decimals));
        assertGe(a.preciseMulCeil(b, decimals), result);
        assertLe(a.preciseMulCeil(b, decimals), result + 1);
    }

    /**
     * [SUCESS] If b > 0, a < 10ˆdecimals, then:
     *
     * a.mulCeil(b, decimals) >= (a * b) / 10ˆdecimals
     * a.mulCeil(b, decimals) <= (a * b) / 10ˆdecimals + 1
     */
    function testPreciseMulCeilBIsRandomValueAIsLessThanDecimals(
        uint256 a,
        uint256 b,
        uint256 decimals
    ) public {
        vm.assume(a > 0);
        vm.assume(b > 0);
        vm.assume(decimals > 0);
        vm.assume(decimals <= 18);
        vm.assume(a <= 10 ** decimals);
        vm.assume(b < sqrt(type(uint256).max));

        uint256 result = ((a * b) / (10 ** decimals));
        assertGe(a.preciseMulCeil(b, decimals), result);
        assertLe(a.preciseMulCeil(b, decimals), result + 1);
    }

    /**
     * [SUCESS] If a = 1, b <= 10ˆdecimals, then:
     *
     * a.mulCeil(b, decimals) = 1
     */
    function testPreciseMulWhenAIsOneAndBIsLessOrEqualThanMaxDecimals(uint256 b, uint256 decimals)
        public
    {
        vm.assume(decimals > 0);
        vm.assume(decimals <= 18);
        vm.assume(b > 0);
        vm.assume(b <= 10 ** decimals);

        uint256 a = 1;
        assertEq(a.preciseMulCeil(b, decimals), 1);
    }

    /**
     * [SUCESS] If b = 1, a <= 10ˆdecimals, then:
     *
     * a.mulCeil(b, decimals) = 1
     */
    function testPreciseMulWhenBIsOneAndAIsLessOrEqualThanMaxDecimals(uint256 a, uint256 decimals)
        public
    {
        vm.assume(decimals > 0);
        vm.assume(decimals <= 18);
        vm.assume(a > 0);
        vm.assume(a <= 10 ** decimals);

        uint256 b = 1;
        assertEq(a.preciseMulCeil(b, decimals), 1);
    }

    /**
     * [SUCESS] If a = 1, b > 10ˆdecimals, then:
     *
     * a.mulCeil(b, decimals) >= b / 10ˆdecimals
     * a.mulCeil(b, decimals) <= b / 10ˆdecimals + 1
     */
    function testPreciseMulWhenBIsOneAndAIsGreaterThanMaxDecimals(uint256 b, uint256 decimals)
        public
    {
        vm.assume(decimals > 0);
        vm.assume(decimals <= 18);
        vm.assume(b > 10 ** decimals);

        uint256 a = 1;
        assertGe(a.preciseMulCeil(b, decimals), (b / (10 ** decimals)));
        assertLe(a.preciseMulCeil(b, decimals), (b / (10 ** decimals)) + 1);
    }

    /**
     * [SUCESS] If b = 1, a > 10ˆdecimals, then:
     *
     * a.mulCeil(b, decimals) >= a / 10ˆdecimals
     * a.mulCeil(b, decimals) <= a / 10ˆdecimals + 1
     */
    function testPreciseMulWhenAIsOneAndBIsGreaterThanMaxDecimals(uint256 a, uint256 decimals)
        public
    {
        vm.assume(decimals > 0);
        vm.assume(decimals <= 18);
        vm.assume(a > 10 ** decimals);

        uint256 b = 1;
        assertGe(a.preciseMulCeil(b, decimals), (a / (10 ** decimals)));
        assertLe(a.preciseMulCeil(b, decimals), (a / (10 ** decimals)) + 1);
    }

    /**
     * [SUCESS] If a > 0, b = 10^decimals, then:
     *
     * a.mulCeil(b, decimals) = a
     */
    function testPreciseMulCeilShouldEqualAIfBEqualsScale(uint256 a, uint256 decimals) public {
        vm.assume(a > 0);
        vm.assume(a < sqrt(type(uint256).max));
        vm.assume(decimals > 0);
        vm.assume(decimals <= 18);

        uint256 b = 10 ** decimals;
        uint256 result = a;
        assertEq(a.preciseMulCeil(b, decimals), result);
    }
}
