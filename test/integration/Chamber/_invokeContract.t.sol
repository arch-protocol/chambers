// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import {ChamberTestUtils} from "test/utils/ChamberTestUtils.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ExposedChamber} from "test/utils/exposedContracts/ExposedChamber.sol";

contract ChamberIntegrationInternalInvokeContractTest is ChamberTestUtils {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/

    ExposedChamber public chamber;
    address payable public zeroExProxy = payable(0xDef1C0ded9bec7F1a1670819833240f027b25EfF); //0x on ETH
    address public globalChamberAddress;
    address public chamberGodAddress = vm.addr(0x791782394);
    address public token1 = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC on ETH
    address public token2 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH on ETH
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
        address[] memory wizards = new address[](0);
        address[] memory managers = new address[](0);

        chamber = new ExposedChamber(
            address(this),
            "USD Yield Index",
            "USHY",
            globalConstituents,
            globalQuantities,
            wizards,
            managers
        );
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
     * [REVERT] Should revert because tradeIssuer has balance but no approve has been granted on
     * the input token.
     */
    function testCannotSwapWithoutInputTokenApproveOnChamber(uint256 buyAmount) public {
        vm.assume(buyAmount > 1 ether);
        vm.assume(buyAmount < 1000 ether);

        (bytes memory quote, uint256 sellAmount) = getQuoteDataForMint(buyAmount, token2, token1);
        uint256 amountWithSlippage = (sellAmount * 101 / 100);

        deal(token1, globalChamberAddress, amountWithSlippage);
        // Approve expected [here]

        vm.expectRevert();
        chamber.invokeContract(quote, zeroExProxy);

        assertEq(IERC20(token1).balanceOf(globalChamberAddress), amountWithSlippage);
    }

    /**
     * [REVERT] Should revert because tradeIssuer has no balance.
     */
    function testCannotSwapWithoutInputTokenBalanceOnChamber(uint256 buyAmount) public {
        vm.assume(buyAmount > 1 ether);
        vm.assume(buyAmount < 1000 ether);

        (bytes memory quote,) = getQuoteDataForMint(buyAmount, token2, token1);

        vm.prank(globalChamberAddress);
        IERC20(token1).approve(zeroExProxy, type(uint256).max);

        vm.expectRevert();
        chamber.invokeContract(quote, zeroExProxy);

        assertEq(IERC20(token1).balanceOf(globalChamberAddress), 0);
    }

    /**
     * [REVERT] Should revert with bad quotes call data.
     */
    function testCannotSwapWithBadQuotesOnChamber() public {
        bytes memory quote = bytes("0x0123456");

        vm.expectRevert();
        chamber.invokeContract(quote, zeroExProxy);
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

        vm.prank(globalChamberAddress);
        IERC20(token1).approve(zeroExProxy, type(uint256).max);

        bytes memory responseCall = chamber.invokeContract(quote, zeroExProxy);

        uint256 amountBought = abi.decode(responseCall, (uint256));
        uint256 inputTokenBalanceAfter = IERC20(token1).balanceOf(globalChamberAddress);

        assertGe(sellAmount * 1 / 100, inputTokenBalanceAfter);
        assertApproxEqAbs(
            buyAmount, IERC20(token2).balanceOf(globalChamberAddress), buyAmount * 5 / 1000
        );
        assertEq(IERC20(token2).balanceOf(globalChamberAddress), amountBought);
    }
}
