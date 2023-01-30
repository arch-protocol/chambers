// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17.0;

import {Test} from "forge-std/Test.sol";
import {ChamberGod} from "src/ChamberGod.sol";
import {Chamber} from "src/Chamber.sol";
import {IssuerWizard} from "src/IssuerWizard.sol";
import {RebalanceWizard, IRebalanceWizard} from "src/RebalanceWizard.sol";
import {StreamingFeeWizard, IStreamingFeeWizard} from "src/StreamingFeeWizard.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {console} from "forge-std/console.sol";

/**
 * ERC20 with _afterTokenTransfer hook implemented. It makes a callback function after every transfer.
 */
contract ERC20WithCallback is ERC20("", "") {
    address public callback;

    constructor(address _callback) {
        callback = _callback;
    }

    function _afterTokenTransfer(address, address, uint256) internal virtual override {
        (bool success,) = callback.call("");
        success;
    }
}
/**
 * Malicious contract that tries to call collectStreamingFees function at fallback.
 * This contract is called by the ERC20WithCallback contract and will try to perform an attack.
 */

contract MaliciousContract {
    StreamingFeeWizard feeWiz;
    Chamber chamber;

    constructor(StreamingFeeWizard _feeWiz) {
        feeWiz = _feeWiz;
    }

    function setChamber(Chamber _chamber) public {
        chamber = _chamber;
    }

    fallback() external {
        if (address(chamber) == address(0)) {
            return;
        }

        // This will trigger updateQuantities()
        feeWiz.collectStreamingFee(chamber);
    }
}

contract Reentrancy is Test {
    ERC20 constant WETH = ERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    ChamberGod god;
    IssuerWizard issuer;
    RebalanceWizard rebalancer;
    StreamingFeeWizard streamingFee;

    address owner;
    address manager;
    address alice;
    address bob;

    function setUp() public {
        owner = makeAddr("OWNER");
        manager = makeAddr("MANAGER");
        alice = makeAddr("ALICE");
        bob = makeAddr("BOB");

        vm.startPrank(owner);

        //[ARCH] moved god creation here because of IssuerWizard implementations to prevent phishing.
        god = new ChamberGod();
        issuer = new IssuerWizard(address(god));
        rebalancer = new RebalanceWizard();
        streamingFee = new StreamingFeeWizard();

        god.addWizard(address(issuer));
        god.addWizard(address(rebalancer));
        god.addWizard(address(streamingFee));

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                              SUCCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * [SUCCESS] Will try to perform a call to collectStreamingFees and update the constituents
     * quantities at the Chamber. This will not result in a revert but the call to streaming fees
     * will have no effect on the constituentsQuantities array since updateQuantities will be locked
     * while issuing new tokens at the issuerWizard.
     */
    function testIssueReentrancy() public {
        MaliciousContract callback = new MaliciousContract(streamingFee);
        ERC20WithCallback callbackToken = new ERC20WithCallback(address(callback));

        address[] memory constituents = new address[](1);
        constituents[0] = address(callbackToken);

        uint256[] memory quantities = new uint256[](1);
        quantities[0] = 1e18;

        address[] memory wizards = new address[](3);
        wizards[0] = address(issuer);
        wizards[1] = address(rebalancer);
        wizards[2] = address(streamingFee);

        address[] memory managers = new address[](1);
        managers[0] = manager;

        vm.prank(owner);
        Chamber chamber = Chamber(
            god.createChamber("Reentrancy", "r", constituents, quantities, wizards, managers)
        );

        deal(address(callbackToken), alice, 1e18);
        deal(address(callbackToken), bob, 1e18);

        // Enable fees just to avoid reverts, we don't really care about amounts
        vm.prank(manager);
        streamingFee.enableChamber(chamber, IStreamingFeeWizard.FeeState(address(1), 1, 1, 0));

        // ALICE (represents normal users depositing)

        // Mint some chamber tokens
        vm.startPrank(alice);
        callbackToken.approve(address(issuer), 1e18);
        issuer.issue(chamber, 1e18);
        vm.stopPrank();

        vm.warp(block.timestamp + 1);

        // BOB / Attack
        //[ARCH] save balances to check that they remain unchanged after attack attempt
        uint256 bobWethBalanceBefore = callbackToken.balanceOf(bob);
        uint256 bobChamberBalanceBefore = chamber.balanceOf(bob);
        uint256 constituentQuantityBefore = chamber.getConstituentQuantity(address(WETH));
        uint256 chamberWethBalanceBefore = callbackToken.balanceOf(address(chamber));

        console.log("Bob's token balance    ", callbackToken.balanceOf(bob));
        console.log("Bob's chamber balance  ", chamber.balanceOf(bob));
        console.log(
            "Constituent quantity   ", chamber.getConstituentQuantity(address(callbackToken))
        );
        console.log("Chamber's token balance", callbackToken.balanceOf(address(chamber)));

        // Enable the callback
        callback.setChamber(chamber);
        vm.startPrank(bob);

        console.log("\nISSUING...\n");
        callbackToken.approve(address(issuer), 1e18);
        issuer.issue(chamber, 1e18);

        vm.warp(block.timestamp + 1);

        console.log("Bob's token balance    ", callbackToken.balanceOf(bob));
        console.log("Bob's chamber balance  ", chamber.balanceOf(bob));
        console.log(
            "Constituent quantity   ", chamber.getConstituentQuantity(address(callbackToken))
        );
        console.log("Chamber's token balance", callbackToken.balanceOf(address(chamber)));

        // This will now use the inflated constituent quantity
        console.log("\nREDEEMING...\n");
        issuer.redeem(chamber, 1e18);

        console.log("Bob's token balance    ", callbackToken.balanceOf(bob));
        console.log("Bob's chamber balance  ", chamber.balanceOf(bob));
        console.log(
            "Constituent quantity   ", chamber.getConstituentQuantity(address(callbackToken))
        );
        console.log("Chamber's token balance", callbackToken.balanceOf(address(chamber)));

        assertEq(bobWethBalanceBefore, callbackToken.balanceOf(bob));
        assertEq(bobChamberBalanceBefore, chamber.balanceOf(bob));
        assertEq(constituentQuantityBefore, chamber.getConstituentQuantity(address(WETH)));
        assertEq(chamberWethBalanceBefore, callbackToken.balanceOf(address(chamber)));

        vm.stopPrank();
    }

    /**
     * [SUCCESS] Will try to perform a call to collectStreamingFees and update the constituents
     * quantities at the Chamber. This will not result in a revert but the call to streaming fees
     * will have no effect on the constituentsQuantities array since updateQuantities and minting
     * will be locked while redeeming tokens at the issuerWizard.
     */
    function testRedeemReentrancy() public {
        MaliciousContract callback = new MaliciousContract(streamingFee);
        ERC20WithCallback callbackToken = new ERC20WithCallback(address(callback));

        address[] memory constituents = new address[](2);
        constituents[0] = address(callbackToken);
        constituents[1] = address(WETH);

        uint256[] memory quantities = new uint256[](2);
        quantities[0] = 1e18;
        quantities[1] = 1e18;

        address[] memory wizards = new address[](3);
        wizards[0] = address(issuer);
        wizards[1] = address(rebalancer);
        wizards[2] = address(streamingFee);

        address[] memory managers = new address[](1);
        managers[0] = manager;

        vm.prank(owner);
        Chamber chamber = Chamber(
            god.createChamber("Reentrancy", "r", constituents, quantities, wizards, managers)
        );

        deal(address(WETH), alice, 1e18);
        deal(address(callbackToken), alice, 1e18);
        deal(address(WETH), bob, 3e18);
        deal(address(callbackToken), bob, 3e18);

        // Enable fees just to avoid reverts, we don't really care about amounts
        vm.prank(manager);
        streamingFee.enableChamber(chamber, IStreamingFeeWizard.FeeState(address(1), 1, 1, 0));

        // ALICE (represents normal users depositing)

        // Mint some chamber tokens
        vm.startPrank(alice);
        callbackToken.approve(address(issuer), 1e18);
        WETH.approve(address(issuer), 1e18);
        issuer.issue(chamber, 1e18);
        vm.stopPrank();

        vm.warp(block.timestamp + 1);

        // BOB / Attack
        //[ARCH] save balances to check that they remain unchanged after attack attempt
        uint256 bobWethBalanceBefore = WETH.balanceOf(bob);
        uint256 bobChamberBalanceBefore = chamber.balanceOf(bob);
        uint256 constituentQuantityBefore = chamber.getConstituentQuantity(address(WETH));
        uint256 chamberWethBalanceBefore = WETH.balanceOf(address(chamber));

        console.log("Bob's WETH balance     ", WETH.balanceOf(bob));
        console.log("Bob's chamber balance  ", chamber.balanceOf(bob));
        console.log("Constituent quantity   ", chamber.getConstituentQuantity(address(WETH)));
        console.log("Chamber's WETH balance ", WETH.balanceOf(address(chamber)));

        vm.startPrank(bob);

        console.log("\nISSUING...\n");
        callbackToken.approve(address(issuer), 3e18);
        WETH.approve(address(issuer), 3e18);
        issuer.issue(chamber, 3e18);

        console.log("Bob's WETH balance     ", WETH.balanceOf(bob));
        console.log("Bob's chamber balance  ", chamber.balanceOf(bob));
        console.log("Constituent quantity   ", chamber.getConstituentQuantity(address(WETH)));
        console.log("Chamber's WETH balance ", WETH.balanceOf(address(chamber)));

        // Enable the callback
        callback.setChamber(chamber);
        // This will trigger the callback
        console.log("\nREDEEMING... (with callback)\n");
        issuer.redeem(chamber, 2e18);

        console.log("Bob's WETH balance     ", WETH.balanceOf(bob));
        console.log("Bob's chamber balance  ", chamber.balanceOf(bob));
        console.log("Constituent quantity   ", chamber.getConstituentQuantity(address(WETH)));
        console.log("Chamber's WETH balance ", WETH.balanceOf(address(chamber)));

        // Disable the callback
        callback.setChamber(Chamber(address(0)));
        // This will not trigger the callback, but will use inflated quantities
        console.log("\nREDEEMING...\n");
        issuer.redeem(chamber, 1e18);

        console.log("Bob's WETH balance     ", WETH.balanceOf(bob));
        console.log("Bob's chamber balance  ", chamber.balanceOf(bob));
        console.log("Constituent quantity   ", chamber.getConstituentQuantity(address(WETH)));
        console.log("Chamber's WETH balance ", WETH.balanceOf(address(chamber)));

        assertEq(bobWethBalanceBefore, WETH.balanceOf(bob));
        assertEq(bobChamberBalanceBefore, chamber.balanceOf(bob));
        assertEq(constituentQuantityBefore, chamber.getConstituentQuantity(address(WETH)));
        assertEq(chamberWethBalanceBefore, WETH.balanceOf(address(chamber)));

        vm.stopPrank();
    }
}
