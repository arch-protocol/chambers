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
import {ChamberFactory} from "test/utils/factories.sol";
import {PreciseUnitMath} from "src/lib/PreciseUnitMath.sol";
import {ChamberGod} from "src/ChamberGod.sol";
import {ExposedRebalanceWizard} from "test/utils/exposedContracts/ExposedRebalanceWizard.sol";

contract RebalanceWizardIntegrationTradeTest is ChamberTestUtils {
    /*//////////////////////////////////////////////////////////////
                              LIBRARIES
    //////////////////////////////////////////////////////////////*/

    using ArrayUtils for address[];
    using PreciseUnitMath for uint256;

    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/

    IChamber private chamberWithNoVault;
    IChamber private chamberWithVault;
    IssuerWizard private issuer;
    ExposedRebalanceWizard private rebalancer;
    ChamberFactory private factory;
    IRebalanceWizard.RebalanceParams private params;
    ChamberGod private god;
    address payable private dexAggregator = payable(0xDef1C0ded9bec7F1a1670819833240f027b25EfF);
    address private owner;
    address private manager;
    string private symbol = "USHY";
    string private name = "USD High Yield";
    address private dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
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
        rebalancer = new ExposedRebalanceWizard();
        vm.label(address(issuer), "Issuer");
        vm.label(address(rebalancer), "Rebalancer");
        god.addWizard(address(issuer));
        god.addWizard(address(rebalancer));
        wizards[0] = address(issuer);
        wizards[1] = address(rebalancer);
        managers[0] = vm.addr(0x3);
        constituents[0] = usdc;
        quantities[0] = 100000e6;
        chamberWithNoVault = IChamber(
            god.createChamber("NoVaultChamber", "NVCH", constituents, quantities, wizards, managers)
        );
        constituents[0] = yvUSDC;
        quantities[0] = 100000e6;
        chamberWithVault = IChamber(
            god.createChamber("VaultChamber", "VCH", constituents, quantities, wizards, managers)
        );
        vm.stopPrank();
        vm.prank(0x0A59649758aa4d66E25f08Dd01271e891fe52199);
        deal(usdc, owner, 100000e6);
        vm.prank(0x36822d0b11F4594380181cE6e76bd4986d46c389);
        deal(yvUSDC, owner, 100000e6);
        vm.startPrank(owner);
        chamberWithNoVault.addManager(owner);
        chamberWithVault.addManager(owner);
        IERC20(usdc).approve(address(issuer), 100000e6);
        IERC20(yvUSDC).approve(address(issuer), 100000e6);
        issuer.issue(chamberWithNoVault, 1e18);
        issuer.issue(chamberWithVault, 1e18);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * Should call trade() and revert because quote is invalid
     */
    function testCannotTradeWithWrongQuote() public {
        uint256 sellAmount = 50e6;
        uint256 buyAmount = 1e6;
        bytes memory quotes = bytes(abi.encode(buyAmount));
        address target = vm.addr(0x123123);
        vm.startPrank(owner);
        god.addAllowedContract(target);
        chamberWithNoVault.addAllowedContract(target);
        params = IRebalanceWizard.RebalanceParams(
            chamberWithNoVault, usdc, sellAmount, dai, buyAmount, payable(target), quotes
        );
        vm.expectRevert();
        rebalancer.trade(params);
        vm.stopPrank();
    }

    /**
     * Should call trade() and revert because Chamber has no balance of sellToken
     */
    function testCannotTradeWithNoBalance() public {
        uint256 sellAmount = 50e6;
        uint256 buyAmount = 1e6;
        bytes memory quotes = bytes(abi.encode(buyAmount));
        address target = vm.addr(0x123123);
        vm.startPrank(address(rebalancer));
        chamberWithNoVault.withdrawTo(
            usdc, owner, IERC20(usdc).balanceOf(address(chamberWithNoVault))
        );
        vm.stopPrank();
        vm.startPrank(owner);
        god.addAllowedContract(target);
        chamberWithNoVault.addAllowedContract(target);
        params = IRebalanceWizard.RebalanceParams(
            chamberWithNoVault, usdc, sellAmount, dai, buyAmount, payable(target), quotes
        );
        vm.expectRevert("Sell quantity >= chamber balance");
        rebalancer.trade(params);
        vm.stopPrank();
    }

    /**
     * Should call trade() and revert because target is not allowed in Chamber
     */
    function testCannotTradeWithUnallowedTarget() public {
        uint256 sellAmount = 50e6;
        uint256 buyAmount = 1e6;
        bytes memory quotes = bytes(abi.encode(buyAmount));
        address target = vm.addr(0x123123);
        vm.startPrank(owner);
        params = IRebalanceWizard.RebalanceParams(
            chamberWithNoVault, usdc, sellAmount, dai, buyAmount, payable(target), quotes
        );
        vm.expectRevert("Target not allowed");
        rebalancer.trade(params);
        vm.stopPrank();
    }

    /**
     * Should call trade() and revert because target is Chamber
     */
    function testCannotTradeWithChamberAsTarget() public {
        uint256 sellAmount = 50e6;
        uint256 buyAmount = 1e6;
        bytes memory quotes = bytes(abi.encode(buyAmount));
        address target = address(chamberWithNoVault);
        vm.startPrank(owner);
        god.addAllowedContract(target);
        chamberWithNoVault.addAllowedContract(target);
        params = IRebalanceWizard.RebalanceParams(
            chamberWithNoVault, usdc, sellAmount, dai, buyAmount, payable(target), quotes
        );
        vm.expectRevert("Cannot invoke the Chamber");
        rebalancer.trade(params);
        vm.stopPrank();
    }

    /**
     * [REVERT] Should revert if less balance than sell amount
     */
    function testCannotTradeWithLessBalanceThanSellAmount() public {
        uint256 sellAmount = 100000e18;
        uint256 buyAmount = 1e6;
        bytes memory quotes = bytes(abi.encode(buyAmount));
        address target = vm.addr(0x123123);
        vm.startPrank(owner);
        god.addAllowedContract(target);
        chamberWithNoVault.addAllowedContract(target);
        params = IRebalanceWizard.RebalanceParams(
            chamberWithNoVault, usdc, sellAmount, dai, buyAmount, payable(target), quotes
        );
        vm.expectRevert("Sell quantity >= chamber balance");
        rebalancer.trade(params);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * Should successfully call trade() and receive the correct amount of buyToken
     * using 0x's dexAggregator and quotes
     */
    function testTradeUsing0xAggregator(uint256 sellAmount) public {
        vm.assume(sellAmount > 1e6);
        vm.assume(sellAmount < 100000e6);
        (bytes memory quotes, uint256 buyAmount, address target) =
            getCompleteQuoteData(usdc, sellAmount, dai);
        vm.startPrank(owner);
        god.addAllowedContract(target);
        chamberWithNoVault.addAllowedContract(target);
        params = IRebalanceWizard.RebalanceParams(
            chamberWithNoVault, usdc, sellAmount, dai, buyAmount, payable(target), quotes
        );
        rebalancer.trade(params);
        uint256 daiQty = chamberWithNoVault.getConstituentQuantity(dai);
        vm.stopPrank();
        assertGe(daiQty, IERC20(dai).balanceOf(address(chamberWithNoVault)));
    }

    /**
     * Should successfully call trade() and receive the correct amount of yvUSDC
     * after making a deposit to the yearn vault
     */
    function testTradeDepositUSDCToVault(uint256 depositAmount) public {
        vm.assume(depositAmount > 1e6);
        vm.assume(depositAmount < 100000e6);
        bytes memory data = abi.encodeWithSignature("pricePerShare()");
        (bool success, bytes memory result) = yvUSDC.call(data);

        require(success, "Failed to get pricePerShare");
        vm.startPrank(owner);
        god.addAllowedContract(yvUSDC);
        chamberWithNoVault.addAllowedContract(yvUSDC);

        uint256 price = abi.decode(result, (uint256));
        uint256 yvUSDCQty = depositAmount.preciseDiv(price, 6);
        data = abi.encodeWithSignature("deposit(uint256)", depositAmount);
        params = IRebalanceWizard.RebalanceParams(
            chamberWithNoVault,
            usdc,
            depositAmount,
            yvUSDC,
            yvUSDCQty * 995 / 1000,
            payable(yvUSDC),
            data
        );
        rebalancer.trade(params);
        uint256 currentyvQty = chamberWithNoVault.getConstituentQuantity(yvUSDC);
        assertGe(currentyvQty, IERC20(yvUSDC).balanceOf(address(chamberWithNoVault)));
        vm.stopPrank();
    }

    /**
     * Should successfully call trade() and receive the correct amount of USDC
     * after making a withdrawal from the yearn vault
     */
    function testTradeWithdrawUSDCFromVault(uint256 sharesToSell) public {
        vm.assume(sharesToSell > 1e6);
        vm.assume(sharesToSell < 100000e6);
        bytes memory data = abi.encodeWithSignature("pricePerShare()");
        (bool success, bytes memory result) = yvUSDC.call(data);

        require(success, "Failed to get pricePerShare");
        vm.startPrank(owner);
        god.addAllowedContract(yvUSDC);
        chamberWithVault.addAllowedContract(yvUSDC);

        uint256 price = abi.decode(result, (uint256));
        uint256 expectedUSDC = sharesToSell.preciseMul(price, 6);

        data = abi.encodeWithSignature("withdraw(uint256)", sharesToSell);
        params = IRebalanceWizard.RebalanceParams(
            chamberWithVault, yvUSDC, sharesToSell, usdc, expectedUSDC, payable(yvUSDC), data
        );

        rebalancer.trade(params);
        uint256 currentUSDCQty = chamberWithVault.getConstituentQuantity(usdc);
        assertGe(currentUSDCQty, IERC20(usdc).balanceOf(address(chamberWithVault)));
        vm.stopPrank();
    }
}
