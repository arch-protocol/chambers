// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import "forge-std/Test.sol";
import {PreciseUnitMath} from "../../../src/lib/PreciseUnitMath.sol";

contract PreciseMulTest is Test {
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
     * a.preciseMul(b, decimals) = 0
     */
    function testPreciseMulShouldBeZeroIfAIsZero(uint256 b, uint256 decimals) public {
        vm.assume(b > 0);
        vm.assume(decimals > 0);
        vm.assume(decimals <= 18);

        uint256 a = 0;
        assertEq(a.preciseMul(b, decimals), 0);
    }

    /**
     * [SUCESS] If b = 0, and a > 0, then:
     *
     * a.preciseMul(b, decimals) = 0
     */
    function testPreciseMulShouldBeZeroIfBIsZero(uint256 a, uint256 decimals) public {
        vm.assume(a > 0);
        vm.assume(decimals > 0);
        vm.assume(decimals <= 18);

        uint256 b = 0;
        assertEq(a.preciseMul(b, decimals), 0);
    }

    /**
     * [SUCESS] If a = 1, b > 0, then:
     *
     * a.preciseMul(b, decimals) == b / 10ˆdecimals
     */
    function testPreciseMulShouldRoundUpWhenAIsOne(uint256 b, uint256 decimals) public {
        vm.assume(b > 0);
        vm.assume(decimals > 0);
        vm.assume(decimals <= 18);

        uint256 a = 1;
        assertEq(a.preciseMul(b, decimals), (b / (10 ** decimals)));
        assertEq(b.preciseMul(a, decimals), (b / (10 ** decimals)));
    }

    /**
     * [SUCESS] If b = 1, a > 0, then:
     *
     * a.preciseMul(b, decimals) == a / 10ˆdecimals
     */
    function testPreciseMulShouldRoundUpWhenBIsOne(uint256 a, uint256 decimals) public {
        vm.assume(a > 0);
        vm.assume(decimals > 0);
        vm.assume(decimals <= 18);

        uint256 b = 1;
        assertEq(a.preciseMul(b, decimals), (a / (10 ** decimals)));
    }

    /**
     * [SUCESS] If a > 0, b > 0, and b < sqrt(uint256.max), and a <= b, then:
     *
     * a.preciseMul(b, decimals) >= (a * b) / 10ˆdecimals
     *
     * We restrict b to avoid arithmetic overflow.
     */
    function testPreciseMulShouldRoundUpWhenAIsLessOrEqualB(uint256 a, uint256 b, uint256 decimals)
        public
    {
        vm.assume(a > 0);
        vm.assume(b > 0);
        vm.assume(decimals > 0);
        vm.assume(decimals <= 18);
        vm.assume(b < sqrt(type(uint256).max));
        vm.assume(a <= b);

        assertEq(a.preciseMul(b, decimals), ((a * b) / (10 ** decimals)));
    }

    /**
     * [SUCESS] If b > 0, a > 0, and a < sqrt(uint256.max), and b <= a, then:
     *
     * a.preciseMul(b, decimals) >= (a * b) / 10ˆdecimals
     *
     * We restrict a to avoid arithmetic overflow.
     */
    function testPreciseMulShouldRoundUpWhenBIsLessOrEqualA(uint256 a, uint256 b, uint256 decimals)
        public
    {
        vm.assume(a > 0);
        vm.assume(b > 0);
        vm.assume(decimals > 0);
        vm.assume(decimals <= 18);
        vm.assume(a < sqrt(type(uint256).max));
        vm.assume(b <= a);

        assertEq(a.preciseMul(b, decimals), ((a * b) / (10 ** decimals)));
    }

    /**
     * [SUCESS] If a > 0, b < 10ˆdecimals, then:
     *
     * a.preciseMul(b, decimals) == (a * b) / 10ˆdecimals
     */
    function testPreciseMulAIsRandomValueBIsLessThanDecimals(uint256 a, uint256 b, uint256 decimals)
        public
    {
        vm.assume(a > 0);
        vm.assume(b > 0);
        vm.assume(decimals > 0);
        vm.assume(decimals <= 18);
        vm.assume(b <= 10 ** decimals);
        vm.assume(a < sqrt(type(uint256).max));

        assertEq(a.preciseMul(b, decimals), ((a * b) / (10 ** decimals)));
        assertEq(b.preciseMul(a, decimals), ((a * b) / (10 ** decimals)));
    }

    /**
     * [SUCESS] If b > 0, a < 10ˆdecimals, then:
     *
     * a.preciseMul(b, decimals) == (a * b) / 10ˆdecimals
     */
    function testPreciseMulBIsRandomValueAIsLessThanDecimals(uint256 a, uint256 b, uint256 decimals)
        public
    {
        vm.assume(a > 0);
        vm.assume(b > 0);
        vm.assume(decimals > 0);
        vm.assume(decimals <= 18);
        vm.assume(a <= 10 ** decimals);
        vm.assume(b < sqrt(type(uint256).max));

        assertEq(a.preciseMul(b, decimals), ((a * b) / (10 ** decimals)));
    }

    /**
     * [SUCESS] If a = 1, b < 10ˆdecimals, then:
     *
     * a.preciseMul(b, decimals) = 0
     */
    function testPreciseMulWhenAIsOneAndBIsLessOrEqualThanMaxDecimals(uint256 b, uint256 decimals)
        public
    {
        vm.assume(decimals > 0);
        vm.assume(decimals <= 18);
        vm.assume(b > decimals);
        vm.assume(b < 10 ** decimals);

        uint256 a = 1;
        assertEq(a.preciseMul(b, decimals), 0);
    }

    /**
     * [SUCESS] If b = 1, a < 10ˆdecimals, then:
     *
     * a.preciseMul(b, decimals) = 0
     */
    function testPreciseMulWhenBIsOneAndAIsLessOrEqualThanMaxDecimals(uint256 a, uint256 decimals)
        public
    {
        vm.assume(decimals > 0);
        vm.assume(decimals <= 18);
        vm.assume(a > decimals);
        vm.assume(a < 10 ** decimals);

        uint256 b = 1;
        assertEq(a.preciseMul(b, decimals), 0);
    }

    /**
     * [SUCESS] If a = 1, b > 10ˆdecimals, then:
     *
     * a.preciseMul(b, decimals) == b / 10ˆdecimals
     */
    function testPreciseMulWhenAIsOneAndBIsGreaterThanMaxDecimals(uint256 b, uint256 decimals)
        public
    {
        vm.assume(decimals > 0);
        vm.assume(decimals <= 18);
        vm.assume(b > 10 ** decimals);

        uint256 a = 1;
        assertEq(a.preciseMul(b, decimals), (b / (10 ** decimals)));
    }

    /**
     * [SUCESS] If b = 1, a > 10ˆdecimals, then:
     *
     * a.preciseMul(b, decimals) == a / 10ˆdecimals
     */
    function testPreciseMulWhenBIsOneAndAIsGreaterThanMaxDecimals(uint256 a, uint256 decimals)
        public
    {
        vm.assume(decimals > 0);
        vm.assume(decimals <= 18);
        vm.assume(a > 10 ** decimals);

        uint256 b = 1;
        assertEq(a.preciseMul(b, decimals), (a / (10 ** decimals)));
    }
}
