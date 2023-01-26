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
 * Fake chamber that was not created by ChamberGod contract.
 * It will be used to perform a phishing attack attempt.
 */
contract FakeChamber {
    function mint(address, uint256) external {
        return;
    }

    function decimals() external view returns (uint8) {
        return 18;
    }

    function getConstituentsAddresses() external view returns (address[] memory) {
        address[] memory constituents = new address[](1);

        // USDC
        constituents[0] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

        return constituents;
    }

    function getConstituentQuantity(address) external view returns (uint256) {
        return 1e18;
    }
}

contract ChambersTest is Test {
    ERC20 public constant USDC = ERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    ChamberGod public god;
    IssuerWizard public issuer;
    RebalanceWizard public rebalancer;
    StreamingFeeWizard public fees;
    Chamber public chamber;

    address public owner;
    address public manager;
    address public bob;
    address public alice;

    function setUp() public {
        owner = makeAddr("OWNER");
        manager = makeAddr("MANAGER");
        bob = makeAddr("BOB");
        alice = makeAddr("ALICE");

        vm.startPrank(owner);

        //[ARCH] Moved god a few lines above because address is needed at IssuerWizard constructor
        god = new ChamberGod();
        issuer = new IssuerWizard(address(god));
        rebalancer = new RebalanceWizard();
        fees = new StreamingFeeWizard();

        god.addWizard(address(issuer));
        god.addWizard(address(rebalancer));
        god.addWizard(address(fees));

        address[] memory constituents = new address[](1);
        constituents[0] = address(USDC);

        uint256[] memory quantities = new uint256[](1);
        quantities[0] = 1000e6;

        address[] memory wizards = new address[](3);
        wizards[0] = address(issuer);
        wizards[1] = address(rebalancer);
        wizards[2] = address(fees);

        address[] memory managers = new address[](1);
        managers[0] = manager;

        chamber = Chamber(
            god.createChamber("Nomoi USDC", "nUSDC", constituents, quantities, wizards, managers)
        );

        vm.stopPrank();

        vm.startPrank(manager);
        IStreamingFeeWizard.FeeState memory feeState =
            IStreamingFeeWizard.FeeState(owner, 1e18, 1e18, block.timestamp);

        fees.enableChamber(chamber, feeState);
        vm.stopPrank();

        deal(address(USDC), bob, 1000000e6);
        deal(address(USDC), alice, 1000000e6);
    }

    /*//////////////////////////////////////////////////////////////
                              REVERT
    //////////////////////////////////////////////////////////////*/

    /**
     * [REVERT] Cannot issue a Chamber token that has not been created by the ChamberGod
     */
    function testCannotIssueFakeChamber() public {
        FakeChamber fakeChamber = new FakeChamber();

        //[ARCH] save Bob's USDC balance to check after the phishing attempt.
        uint256 bobBalanceBeforePhishingAttempt = USDC.balanceOf(address(bob));

        vm.startPrank(bob);

        // Bob approves the issuer to use all USDC tokens
        USDC.approve(address(issuer), type(uint256).max);
        // Bob deposits into a legit chamber
        issuer.issue(chamber, 1e6);
        // Bob is the target of a phishing attack that makes him interact with a fake malicious
        // chamber

        //[ARCH] Should revert now because fakeChamber was not created by ChamberGod
        vm.expectRevert("Chamber invalid");
        issuer.issue(Chamber(address(fakeChamber)), 1e6);

        vm.stopPrank();

        // The fake chamber stole Bob's tokens
        // Depending on the implementation of `FakeChamber.getConstituentQuantity`, all USDC could
        // be stolen from Bob

        //[ARCH] Check that Assets were not stolen
        assertEq(USDC.balanceOf(address(fakeChamber)), 0);

        console.log("Bob USDC balance", USDC.balanceOf(address(bob)));
        console.log("Issuer", USDC.balanceOf(address(fakeChamber)));
        console.log("Fake chamber USDC balance", USDC.balanceOf(address(issuer)));
    }
}
