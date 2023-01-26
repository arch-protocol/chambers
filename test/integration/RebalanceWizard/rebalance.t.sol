// Copyright 2022 Smash Works Inc.
// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.17.0;

import {Chamber} from "src/Chamber.sol";
import {ArrayUtils} from "src/lib/ArrayUtils.sol";
import {IssuerWizard} from "src/IssuerWizard.sol";
import {RebalanceWizard} from "src/RebalanceWizard.sol";
import {IRebalanceWizard} from "src/interfaces/IRebalanceWizard.sol";
import {IChamber} from "src/interfaces/IChamber.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ChamberTestUtils} from "test/utils/ChamberTestUtils.sol";
import {PreciseUnitMath} from "src/lib/PreciseUnitMath.sol";
import {ChamberGod} from "src/ChamberGod.sol";

contract RebalanceWizardIntegrationRebalanceTest is ChamberTestUtils {
    /*//////////////////////////////////////////////////////////////
                              LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using ArrayUtils for address[];
    using PreciseUnitMath for uint256;

    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/

    IChamber private chamber;
    IssuerWizard private issuer;
    RebalanceWizard private rebalancer;
    ChamberGod private god;
    address private owner;
    address private manager;
    address private usdt = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address private yvUSDT = 0x3B27F92C0e212C671EA351827EDF93DB27cc0c65;
    address private yvUSDC = 0xa354F35829Ae975e850e23e9615b11Da1B3dC4DE;
    address private usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address[] private constituents;
    uint256[] private quantities;
    address[] private wizards;
    address[] private managers;

    /*//////////////////////////////////////////////////////////////
                              SET UP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        constituents = new address[](1);
        quantities = new uint256[](1);
        wizards = new address[](2);
        managers = new address[](1);
        owner = vm.addr(0x2);
        vm.startPrank(owner);
        god = new ChamberGod();
        issuer = new IssuerWizard(address(god));
        rebalancer = new RebalanceWizard();
        vm.label(address(issuer), "Issuer");
        vm.label(address(rebalancer), "Rebalancer");
        god.addWizard(address(issuer));
        god.addWizard(address(rebalancer));
        wizards[0] = address(issuer);
        wizards[1] = address(rebalancer);
        managers[0] = vm.addr(0x3);
        constituents[0] = yvUSDC;
        quantities[0] = 1000e6;
        chamber = IChamber(
            god.createChamber("USD High Yield", "USHY", constituents, quantities, wizards, managers)
        );
        god.addAllowedContract(yvUSDC);
        god.addAllowedContract(yvUSDT);
        chamber.addManager(owner);
        chamber.addAllowedContract(yvUSDC);
        chamber.addAllowedContract(yvUSDT);
        vm.stopPrank();
        vm.prank(0x36822d0b11F4594380181cE6e76bd4986d46c389);
        deal(yvUSDC, owner, 1000e6);
        vm.startPrank(owner);
        IERC20(yvUSDC).approve(address(issuer), 1000e6);
        issuer.issue(chamber, 1e18);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/

    // TODO: Add revert test cases

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * Should successfully call rebalance() and perform the following trades:
     *  - Withdraw USDC from yvUSDC vault in yearn
     *  - Perform a swap in 0x Dex Aggregator from USDC to USDT
     *  - Deposit USDT into yvUSDT vault in yearn
     */
    function testRebalanceWithdrawTradeDeposit() public {
        IRebalanceWizard.RebalanceParams[] memory trades = new IRebalanceWizard.RebalanceParams[](3);
        // Data for the first trade (withdraw USDC from yvUSDC)
        uint256 sharesToSell = 100e6;
        bytes memory data = abi.encodeWithSignature("pricePerShare()");
        (bool success, bytes memory result) = yvUSDC.call(data);

        require(success, "Failed to get pricePerShare");

        uint256 price = abi.decode(result, (uint256));
        uint256 expectedUSDC = sharesToSell.preciseMul(price, 6);

        data = abi.encodeWithSignature("withdraw(uint256)", sharesToSell);
        IRebalanceWizard.RebalanceParams memory withdrawParams = IRebalanceWizard.RebalanceParams(
            chamber, yvUSDC, sharesToSell, usdc, expectedUSDC, yvUSDC, payable(yvUSDC), data
        );
        trades[0] = withdrawParams;

        // Data for the second trade (Swap in 0x USDC for USDT)
        CompleteQuoteResponse memory response =
            getCompleteQuoteData(CompleteQuoteParams(usdc, expectedUSDC, usdt));

        IRebalanceWizard.RebalanceParams memory swapParams = IRebalanceWizard.RebalanceParams(
            chamber,
            usdc,
            expectedUSDC,
            usdt,
            response._buyAmount,
            response._allowanceTarget,
            payable(response._target),
            response._quotes
        );
        trades[1] = swapParams;

        // Data for the third trade (Deposit USDT into Beefy)
        data = abi.encodeWithSignature("pricePerShare()");
        (success, result) = yvUSDT.call(data);

        require(success, "Failed to get pricePerShare");

        price = abi.decode(result, (uint256));
        uint256 expectedShares = response._buyAmount.preciseDiv(price, 6);
        expectedShares = expectedShares * 995 / 1000;

        data = abi.encodeWithSignature("deposit(uint256)", response._buyAmount);
        IRebalanceWizard.RebalanceParams memory depositParams = IRebalanceWizard.RebalanceParams(
            chamber,
            usdt,
            response._buyAmount,
            yvUSDT,
            expectedShares,
            yvUSDT,
            payable(yvUSDT),
            data
        );
        trades[2] = depositParams;

        vm.startPrank(owner);
        god.addAllowedContract(response._target);
        chamber.addAllowedContract(response._target);
        rebalancer.rebalance(trades);
        vm.stopPrank();
    }
}
