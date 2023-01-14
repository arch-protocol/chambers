// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import {ChamberTestUtils} from "test/utils/ChamberTestUtils.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Chamber} from "src/Chamber.sol";
import {ChamberFactory} from "test/utils/factories.sol";
import {PreciseUnitMath} from "src/lib/PreciseUnitMath.sol";

contract ChamberUnitExecuteTradeTest is ChamberTestUtils {
    using SafeERC20 for IERC20;
    using PreciseUnitMath for uint256;

    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/

    Chamber public chamber;
    ChamberFactory public chamberFactory;
    address public globalChamberAddress;
    address public owner;
    address public wizard;
    address public manager;
    address payable public dexAgg = payable(address(0x1));
    address public chamberGodAddress = vm.addr(0x2);
    address public token1 = vm.addr(0x3);
    address public token2 = vm.addr(0x4);
    address[] public globalConstituents = new address[](2);
    uint256[] public globalQuantities = new uint256[](2);

    /*//////////////////////////////////////////////////////////////
                              SET UP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        globalConstituents[0] = token1;
        globalConstituents[1] = token2;
        globalQuantities[0] = 6 ether;
        globalQuantities[1] = 2 ether;
        manager = vm.addr(0x5);
        wizard = vm.addr(0x6);
        address[] memory wizards = new address[](1);
        wizards[0] = wizard;
        address[] memory managers = new address[](1);
        managers[0] = manager;

        chamberFactory = new ChamberFactory(
          address(this),
          "name",
          "symbol",
          wizards,
          managers
        );

        chamber = chamberFactory.getChamberWithCustomTokens(globalConstituents, globalQuantities);

        vm.mockCall(
            address(chamberFactory),
            abi.encodeWithSignature("isAllowedContract(address)", dexAgg),
            abi.encode(true)
        );
        vm.prank(manager);
        chamber.addAllowedContract(dexAgg);
        vm.prank(manager);

        globalChamberAddress = address(chamber);
    }

    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [REVERT] Should revert if the caller is not a wizard.
     */
    function testCannotExecuteTradeIfNotWizard() public {
        vm.expectRevert("Must be a wizard");
        chamber.executeTrade(token1, 100 ether, token2, 0, bytes("0x1234"), dexAgg);
    }

    /**
     * [REVERT] Should call executeTrade() and revert because amount bought is less than buyAmount
     */
    function testCannotTradeWithInvalidBuyAmount() public {
        vm.mockCall(
            token2,
            abi.encodeWithSelector(IERC20(token2).balanceOf.selector, globalChamberAddress),
            abi.encode(10 ether)
        );

        vm.mockCall(
            token1,
            abi.encodeWithSelector(IERC20(token1).allowance.selector, globalChamberAddress),
            abi.encode(1000 ether)
        );

        vm.mockCall(dexAgg, bytes("0x1234"), abi.encode(bytes("0x1234")));

        vm.expectRevert("Underbought buy quantity");
        vm.prank(wizard);
        chamber.executeTrade(token1, 1 ether, token2, 1 ether, bytes("0x1234"), dexAgg);
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should call with correct amounts and with wizard
     */
    function testSuccessSwap() public {
        vm.mockCall(
            token1,
            abi.encodeWithSelector(IERC20(token1).balanceOf.selector, globalChamberAddress),
            abi.encode(10 ether)
        );

        vm.mockCall(
            token2,
            abi.encodeWithSelector(IERC20(token2).balanceOf.selector, globalChamberAddress),
            abi.encode(1 ether)
        );

        vm.mockCall(dexAgg, bytes("0x1234"), abi.encode(bytes("0x1234")));

        vm.mockCall(
            token1,
            abi.encodeWithSelector(IERC20(token1).allowance.selector, globalChamberAddress, dexAgg),
            abi.encode(type(uint256).max)
        );

        vm.expectCall(dexAgg, bytes("0x1234"));

        vm.prank(wizard);
        chamber.executeTrade(token1, 1 ether, token2, 0, bytes("0x1234"), dexAgg);
    }
}
