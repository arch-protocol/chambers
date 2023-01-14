// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import {ChamberTestUtils} from "test/utils/ChamberTestUtils.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Chamber} from "src/Chamber.sol";
import {ChamberFactory} from "test/utils/factories.sol";
import {PreciseUnitMath} from "src/lib/PreciseUnitMath.sol";
import {ChamberGod} from "src/ChamberGod.sol";

contract ChamberIntegrationExecuteTradeTest is ChamberTestUtils {
    using SafeERC20 for IERC20;
    using PreciseUnitMath for uint256;

    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/

    Chamber public chamber;
    ChamberGod public god;
    ChamberFactory public chamberFactory;
    address public globalChamberAddress;
    address public owner;
    address public wizard;
    address public manager;
    address payable public zeroExProxy = payable(0xDef1C0ded9bec7F1a1670819833240f027b25EfF); //0x on ETH
    address public chamberGodAddress = vm.addr(0x791782394);
    address public token1 = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC on ETH
    address public token2 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH on ETH
    address public yvUSDC = 0xa354F35829Ae975e850e23e9615b11Da1B3dC4DE;
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
        manager = vm.addr(0x2);
        wizard = vm.addr(0x3);
        owner = vm.addr(0x1);
        address[] memory wizards = new address[](1);
        wizards[0] = wizard;
        address[] memory managers = new address[](1);
        managers[0] = manager;

        vm.prank(owner);
        god = new ChamberGod();

        vm.prank(address(god));
        chamber = new Chamber(
            owner,
            "Test Chamber",
            "TCH",
            globalConstituents,
            globalQuantities,
            wizards,
            managers
        );

        vm.startPrank(owner);
        god.addAllowedContract(zeroExProxy);
        god.addAllowedContract(yvUSDC);
        vm.stopPrank();

        vm.prank(manager);
        chamber.addAllowedContract(zeroExProxy);
        vm.prank(manager);
        chamber.addAllowedContract(yvUSDC);

        globalChamberAddress = address(chamber);
        vm.label(globalChamberAddress, "Chamber");
        vm.label(token1, "USDC");
        vm.label(token2, "WETH");
        vm.label(zeroExProxy, "ZeroEx");
    }

    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [REVERT] Should revert because because chamber has less balance than the
     * required by the quote. It's important no mention that zero sell amounts are not allowed
     * as it's required at the rebalancer wizard.
     */
    function testCannotExecuteWithLessBalanceThanRequiredByQuote(uint256 buyAmount) public {
        vm.assume(buyAmount > 1 ether);
        vm.assume(buyAmount < 1000 ether);

        deal(token1, globalChamberAddress, 0);

        (bytes memory quote,) = getQuoteDataForMint(buyAmount, token2, token1);

        vm.prank(wizard);
        vm.expectRevert();
        chamber.executeTrade(token1, 0, token2, 0, quote, zeroExProxy);

        assertEq(IERC20(token2).balanceOf(globalChamberAddress), 0);
    }

    /**
     * [REVERT] Should revert with bad quotes call data.
     */
    function testCannotSwapWithBadQuotesOnChamber() public {
        bytes memory quote = bytes("0x0123456");

        deal(token1, globalChamberAddress, 100 ether);

        vm.expectRevert();
        vm.prank(wizard);
        chamber.executeTrade(token1, 100 ether, token2, 0, quote, zeroExProxy);
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Should call with correct quotes and swap successfully with 1% slippage.
     */
    function testSuccessSwap(uint256 buyAmount) public {
        vm.assume(buyAmount > 1 ether);
        vm.assume(buyAmount < 1000 ether);

        (bytes memory quote, uint256 sellAmount) = getQuoteDataForMint(buyAmount, token2, token1);

        uint256 amountWithSlippage = (sellAmount * 101 / 100);
        deal(token1, globalChamberAddress, amountWithSlippage);

        vm.prank(wizard);
        chamber.executeTrade(token1, amountWithSlippage, token2, buyAmount, quote, zeroExProxy);

        uint256 inputTokenBalanceAfter = IERC20(token1).balanceOf(globalChamberAddress);

        assertGe(sellAmount * 1 / 100, inputTokenBalanceAfter);
        assertApproxEqAbs(
            buyAmount, IERC20(token2).balanceOf(globalChamberAddress), buyAmount * 5 / 1000
        );
    }

    /**
     * [SUCCESS] Should call with correct quotes and swap successfully with 1% slippage.
     */
    function testSuccessSwapTrade(uint256 buyAmount) public {
        vm.assume(buyAmount > 1 ether);
        vm.assume(buyAmount < 1000 ether);

        (bytes memory quote, uint256 sellAmount) = getQuoteDataForMint(buyAmount, token2, token1);

        uint256 amountWithSlippage = (sellAmount * 101 / 100);
        deal(token1, globalChamberAddress, amountWithSlippage);

        vm.prank(wizard);
        chamber.executeTrade(token1, amountWithSlippage, token2, buyAmount, quote, zeroExProxy);

        uint256 inputTokenBalanceAfter = IERC20(token1).balanceOf(globalChamberAddress);

        assertGe(sellAmount * 1 / 100, inputTokenBalanceAfter);
        assertApproxEqAbs(
            buyAmount, IERC20(token2).balanceOf(globalChamberAddress), buyAmount * 5 / 1000
        );
    }

    /**
     * [SUCCESS] Should make a success deposit in a usdc vault with 0.1% max slippage
     */
    function testSuccessDepositTrade(uint256 depositAmount) public {
        vm.assume(depositAmount > 1e6);
        vm.assume(depositAmount < 100000e6);
        bytes memory data = abi.encodeWithSignature("pricePerShare()");
        (bool success, bytes memory result) = yvUSDC.call(data);

        require(success, "Failed to get pricePerShare");

        deal(token1, globalChamberAddress, depositAmount);

        uint256 price = abi.decode(result, (uint256));
        uint256 yvUSDCQty = depositAmount.preciseDiv(price, 6);
        data = abi.encodeWithSignature("deposit(uint256)", depositAmount);

        vm.prank(wizard);
        chamber.executeTrade(
            token1, depositAmount, yvUSDC, yvUSDCQty * 995 / 1000, data, payable(yvUSDC)
        );
        uint256 currentYvUSDCQty = IERC20(yvUSDC).balanceOf(globalChamberAddress);
        assertApproxEqAbs(currentYvUSDCQty, yvUSDCQty, (yvUSDCQty) / 10000);
    }

    /**
     * [SUCCESS] Should make a success withdraw from a usdc vault with 0.1% max slippage
     */
    function testSuccessWithdrawTrade(uint256 sharesToSell) public {
        vm.assume(sharesToSell > 1e6);
        vm.assume(sharesToSell < 100000e6);
        bytes memory data = abi.encodeWithSignature("pricePerShare()");
        (bool success, bytes memory result) = yvUSDC.call(data);

        require(success, "Failed to get pricePerShare");

        deal(yvUSDC, globalChamberAddress, sharesToSell);

        uint256 price = abi.decode(result, (uint256));
        uint256 expectedUSDC = sharesToSell.preciseMul(price, 6);

        data = abi.encodeWithSignature("withdraw(uint256)", sharesToSell);

        vm.prank(wizard);
        chamber.executeTrade(yvUSDC, sharesToSell, token1, expectedUSDC, data, payable(yvUSDC));

        uint256 currentUSDCQty = IERC20(token1).balanceOf(globalChamberAddress);
        assertApproxEqAbs(currentUSDCQty, expectedUSDC, (expectedUSDC) / 10000);
    }
}
