// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import {ArrayUtils} from "src/lib/ArrayUtils.sol";
import {RebalanceWizard} from "src/RebalanceWizard.sol";
import {ExposedRebalanceWizard} from "test/utils/exposedContracts/ExposedRebalanceWizard.sol";
import {IChamber} from "src/interfaces/IChamber.sol";
import {ChamberTestUtils} from "test/utils/ChamberTestUtils.sol";
import {PreciseUnitMath} from "src/lib/PreciseUnitMath.sol";

contract RebalanceWizardUnitTradeTest is ChamberTestUtils {
    /*//////////////////////////////////////////////////////////////
                              LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using ArrayUtils for address[];
    using PreciseUnitMath for uint256;

    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/

    ExposedRebalanceWizard private rebalancer;
    RebalanceWizard.RebalanceParams private params;
    address payable private dexAggregator = payable(0xDef1C0ded9bec7F1a1670819833240f027b25EfF);
    address private owner;
    IChamber private chamber;
    address private chamberAddress;
    address private dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address private yvUSDC = 0xa354F35829Ae975e850e23e9615b11Da1B3dC4DE;
    address private usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    /*//////////////////////////////////////////////////////////////
                              SET UP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        rebalancer = new ExposedRebalanceWizard();
        vm.label(address(rebalancer), "Rebalancer");
        owner = vm.addr(0x2);
        vm.label(owner, "Owner");
        chamberAddress = vm.addr(0x4);
        chamber = IChamber(chamberAddress);
        vm.label(chamberAddress, "Chamber");
        vm.mockCall(
            chamberAddress, abi.encodeWithSignature("isManager(address)", owner), abi.encode(true)
        );
    }

    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * Should call trade() and revert because caller is not a Manager
     */
    function testCannotTradeWithoutManager() public {
        uint256 sellAmount = 50e6;
        uint256 buyAmount = 1e6;
        bytes memory quotes = bytes(abi.encode(buyAmount));
        address target = vm.addr(0x123123);
        params = RebalanceWizard.RebalanceParams(
            chamber, usdc, sellAmount, dai, buyAmount, payable(target), quotes
        );
        vm.mockCall(
            chamberAddress,
            abi.encodeWithSignature("isManager(address)", address(this)),
            abi.encode(false)
        );
        vm.expectRevert("Only managers can trade");
        rebalancer.trade(params);
    }

    /**
     * Should call trade() and revert because sell quantity is 0
     */
    function testCannotTradeWithZeroSellQuantity() public {
        uint256 sellAmount = 0;
        uint256 buyAmount = 1e6;
        bytes memory quotes = bytes(abi.encode(buyAmount));
        address target = vm.addr(0x123123);
        params = RebalanceWizard.RebalanceParams(
            chamber, usdc, sellAmount, dai, buyAmount, payable(target), quotes
        );
        vm.expectRevert("Sell quantity must be > 0");
        vm.prank(owner);
        rebalancer.trade(params);
    }

    /**
     * [REVERT] Should revert if less balance than sell amount
     */
    function testCannotTradeWithInsufficientBalance() public {
        uint256 sellAmount = 50e6;
        uint256 buyAmount = 1e6;
        bytes memory quotes = bytes(abi.encode(buyAmount));
        address target = vm.addr(0x123123);
        params = RebalanceWizard.RebalanceParams(
            chamber, usdc, sellAmount, dai, buyAmount, payable(target), quotes
        );
        vm.mockCall(
            chamberAddress,
            abi.encodeWithSignature("isConstituent(address)", usdc),
            abi.encode(true)
        );
        vm.mockCall(
            usdc, abi.encodeWithSignature("balanceOf(address)", address(chamber)), abi.encode(0)
        );
        vm.expectRevert("Sell quantity >= chamber balance");
        vm.prank(owner);
        rebalancer.trade(params);
    }

    /**
     * Should call trade() and revert because buy quantity is 0
     */

    function testCannotTradeWithZeroBuyQuantity() public {
        uint256 sellAmount = 50e6;
        uint256 buyAmount = 0;
        bytes memory quotes = bytes(abi.encode(buyAmount));
        address target = vm.addr(0x123123);
        params = RebalanceWizard.RebalanceParams(
            chamber, usdc, sellAmount, dai, buyAmount, payable(target), quotes
        );
        vm.expectRevert("Min. buy quantity must be > 0");
        vm.prank(owner);
        rebalancer.trade(params);
    }

    /**
     * Should call trade() and revert because sellToken and buyToken are the same token
     */
    function testCannotTradeWithSellAndBuyTokensSame() public {
        uint256 sellAmount = 50e6;
        uint256 buyAmount = 1e6;
        bytes memory quotes = bytes(abi.encode(buyAmount));
        address target = vm.addr(0x123123);
        params = RebalanceWizard.RebalanceParams(
            chamber, usdc, sellAmount, usdc, buyAmount, payable(target), quotes
        );
        vm.expectRevert("Traded tokens must be different");
        vm.prank(owner);
        rebalancer.trade(params);
    }

    /**
     * Should call trade() and revert because sellToken is not a constituent
     */
    function testCannotTradeWithSellTokenNotAConstituent() public {
        uint256 sellAmount = 50e6;
        uint256 buyAmount = 1e6;
        bytes memory quotes = bytes(abi.encode(buyAmount));
        address target = vm.addr(0x123123);
        params = RebalanceWizard.RebalanceParams(
            chamber, yvUSDC, sellAmount, dai, buyAmount, payable(target), quotes
        );
        vm.mockCall(
            chamberAddress,
            abi.encodeWithSignature("isConstituent(address)", yvUSDC),
            abi.encode(false)
        );
        vm.expectRevert("Sell token must be a constituent");
        vm.prank(owner);
        rebalancer.trade(params);
    }
}
