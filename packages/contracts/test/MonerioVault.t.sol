// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test, console } from "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { MonerioVault } from "../src/MonerioVault.sol";
import { MockERC20 } from "../src/mocks/MockERC20.sol";

contract MonerioVaultTest is Test {
    MonerioVault public vault;
    MonerioVault public vaultImpl;
    MockERC20 public token;

    address public owner = address(this);
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");

    uint256 public constant INITIAL_BALANCE = 10_000e6; // 10,000 JPYC (6 decimals)
    uint256 public constant WEEKLY_LIMIT = 1_000e6; // 1,000 JPYC per week

    function setUp() public {
        // Deploy mock token (JPYC-like, 6 decimals)
        token = new MockERC20("JPY Coin", "JPYC", 6);

        // Deploy implementation
        vaultImpl = new MonerioVault();

        // Deploy proxy and initialize
        bytes memory initData = abi.encodeWithSelector(MonerioVault.initialize.selector, address(token));
        ERC1967Proxy proxy = new ERC1967Proxy(address(vaultImpl), initData);
        vault = MonerioVault(address(proxy));

        // Mint tokens to users
        token.mint(user1, INITIAL_BALANCE);
        token.mint(user2, INITIAL_BALANCE);
    }

    // ============ Initialization Tests ============

    function test_initialize() public view {
        assertEq(address(vault.token()), address(token));
        assertEq(vault.owner(), owner);
    }

    function test_initialize_revertsWithZeroAddress() public {
        MonerioVault newImpl = new MonerioVault();
        bytes memory initData = abi.encodeWithSelector(MonerioVault.initialize.selector, address(0));

        vm.expectRevert(MonerioVault.ZeroAddress.selector);
        new ERC1967Proxy(address(newImpl), initData);
    }

    // ============ Deposit Tests ============

    function test_deposit() public {
        uint256 depositAmount = 1_000e6;

        vm.startPrank(user1);
        token.approve(address(vault), depositAmount);
        vault.deposit(depositAmount);
        vm.stopPrank();

        assertEq(vault.balances(user1), depositAmount);
        assertEq(token.balanceOf(address(vault)), depositAmount);
        assertEq(token.balanceOf(user1), INITIAL_BALANCE - depositAmount);
    }

    function test_deposit_revertsWithZeroAmount() public {
        vm.startPrank(user1);
        token.approve(address(vault), 1000e6);

        vm.expectRevert(MonerioVault.ZeroAmount.selector);
        vault.deposit(0);
        vm.stopPrank();
    }

    function test_deposit_multipleDeposits() public {
        uint256 amount1 = 500e6;
        uint256 amount2 = 300e6;

        vm.startPrank(user1);
        token.approve(address(vault), amount1 + amount2);
        vault.deposit(amount1);
        vault.deposit(amount2);
        vm.stopPrank();

        assertEq(vault.balances(user1), amount1 + amount2);
    }

    // ============ SetDailyLimit Tests ============

    function test_setDailyLimit() public {
        vm.prank(user1);
        vault.setDailyLimit(WEEKLY_LIMIT);

        assertEq(vault.dailyLimit(user1), WEEKLY_LIMIT);
    }

    function test_setDailyLimit_canUpdateLimit() public {
        vm.startPrank(user1);
        vault.setDailyLimit(WEEKLY_LIMIT);
        vault.setDailyLimit(WEEKLY_LIMIT * 2);
        vm.stopPrank();

        assertEq(vault.dailyLimit(user1), WEEKLY_LIMIT * 2);
    }

    // ============ Payout Tests ============

    function test_payout() public {
        // Setup: deposit and set limit
        vm.startPrank(user1);
        token.approve(address(vault), INITIAL_BALANCE);
        vault.deposit(INITIAL_BALANCE);
        vault.setDailyLimit(WEEKLY_LIMIT);
        vm.stopPrank();

        // Advance time by 1 week
        vm.warp(block.timestamp + 7 days);

        // Execute payout
        vault.payout(user1);

        assertEq(vault.balances(user1), INITIAL_BALANCE - WEEKLY_LIMIT);
        assertEq(token.balanceOf(user1), WEEKLY_LIMIT);
        assertEq(vault.lastPayout(user1), block.timestamp);
    }

    function test_payout_revertsWithZeroAddress() public {
        vm.expectRevert(MonerioVault.ZeroAddress.selector);
        vault.payout(address(0));
    }

    function test_payout_revertsWithZeroLimit() public {
        vm.startPrank(user1);
        token.approve(address(vault), INITIAL_BALANCE);
        vault.deposit(INITIAL_BALANCE);
        // No daily limit set
        vm.stopPrank();

        vm.warp(block.timestamp + 7 days);

        vm.expectRevert(MonerioVault.ZeroAmount.selector);
        vault.payout(user1);
    }

    function test_payout_revertsWhenTooEarly() public {
        // Setup
        vm.startPrank(user1);
        token.approve(address(vault), INITIAL_BALANCE);
        vault.deposit(INITIAL_BALANCE);
        vault.setDailyLimit(WEEKLY_LIMIT);
        vm.stopPrank();

        // First payout after 1 week
        vm.warp(block.timestamp + 7 days);
        vault.payout(user1);

        // Try second payout before 1 week
        vm.warp(block.timestamp + 6 days);

        vm.expectRevert(MonerioVault.PayoutTooEarly.selector);
        vault.payout(user1);
    }

    function test_payout_revertsWithInsufficientBalance() public {
        // Setup with small deposit
        vm.startPrank(user1);
        token.approve(address(vault), 100e6);
        vault.deposit(100e6);
        vault.setDailyLimit(WEEKLY_LIMIT); // Limit > balance
        vm.stopPrank();

        vm.warp(block.timestamp + 7 days);

        vm.expectRevert(MonerioVault.InsufficientBalance.selector);
        vault.payout(user1);
    }

    function test_payout_multipleWeeks() public {
        // Setup
        vm.startPrank(user1);
        token.approve(address(vault), INITIAL_BALANCE);
        vault.deposit(INITIAL_BALANCE);
        vault.setDailyLimit(WEEKLY_LIMIT);
        vm.stopPrank();

        // Week 1
        vm.warp(block.timestamp + 7 days);
        vault.payout(user1);
        assertEq(vault.balances(user1), INITIAL_BALANCE - WEEKLY_LIMIT);

        // Week 2
        vm.warp(block.timestamp + 7 days);
        vault.payout(user1);
        assertEq(vault.balances(user1), INITIAL_BALANCE - (WEEKLY_LIMIT * 2));

        // Week 3
        vm.warp(block.timestamp + 7 days);
        vault.payout(user1);
        assertEq(vault.balances(user1), INITIAL_BALANCE - (WEEKLY_LIMIT * 3));
    }

    // ============ EmergencyWithdraw Tests ============

    function test_emergencyWithdraw() public {
        // Setup: user deposits
        vm.startPrank(user1);
        token.approve(address(vault), INITIAL_BALANCE);
        vault.deposit(INITIAL_BALANCE);
        vm.stopPrank();

        // Owner emergency withdraws
        address recipient = makeAddr("recipient");
        vault.emergencyWithdraw(recipient);

        assertEq(token.balanceOf(recipient), INITIAL_BALANCE);
        assertEq(token.balanceOf(address(vault)), 0);
    }

    function test_emergencyWithdraw_revertsForNonOwner() public {
        vm.startPrank(user1);
        token.approve(address(vault), INITIAL_BALANCE);
        vault.deposit(INITIAL_BALANCE);

        vm.expectRevert(MonerioVault.OnlyOwner.selector);
        vault.emergencyWithdraw(user1);
        vm.stopPrank();
    }

    function test_emergencyWithdraw_revertsWithZeroAddress() public {
        vm.startPrank(user1);
        token.approve(address(vault), INITIAL_BALANCE);
        vault.deposit(INITIAL_BALANCE);
        vm.stopPrank();

        vm.expectRevert(MonerioVault.ZeroAddress.selector);
        vault.emergencyWithdraw(address(0));
    }

    function test_emergencyWithdraw_revertsWithZeroBalance() public {
        vm.expectRevert(MonerioVault.ZeroAmount.selector);
        vault.emergencyWithdraw(owner);
    }

    // ============ Ownership Tests ============

    function test_transferOwnership() public {
        address newOwner = makeAddr("newOwner");
        vault.transferOwnership(newOwner);

        assertEq(vault.owner(), newOwner);
    }

    function test_transferOwnership_revertsForNonOwner() public {
        vm.prank(user1);
        vm.expectRevert(MonerioVault.OnlyOwner.selector);
        vault.transferOwnership(user1);
    }

    function test_transferOwnership_revertsWithZeroAddress() public {
        vm.expectRevert(MonerioVault.ZeroAddress.selector);
        vault.transferOwnership(address(0));
    }

    // ============ View Function Tests ============

    function test_canPayout_returnsTrue() public {
        vm.startPrank(user1);
        token.approve(address(vault), INITIAL_BALANCE);
        vault.deposit(INITIAL_BALANCE);
        vault.setDailyLimit(WEEKLY_LIMIT);
        vm.stopPrank();

        vm.warp(block.timestamp + 7 days);

        (bool eligible, string memory reason) = vault.canPayout(user1);
        assertTrue(eligible);
        assertEq(reason, "");
    }

    function test_canPayout_noLimitSet() public view {
        (bool eligible, string memory reason) = vault.canPayout(user1);
        assertFalse(eligible);
        assertEq(reason, "No daily limit set");
    }

    function test_canPayout_intervalNotReached() public {
        vm.startPrank(user1);
        token.approve(address(vault), INITIAL_BALANCE);
        vault.deposit(INITIAL_BALANCE);
        vault.setDailyLimit(WEEKLY_LIMIT);
        vm.stopPrank();

        // First payout
        vm.warp(block.timestamp + 7 days);
        vault.payout(user1);

        // Check before interval
        vm.warp(block.timestamp + 1 days);

        (bool eligible, string memory reason) = vault.canPayout(user1);
        assertFalse(eligible);
        assertEq(reason, "Payout interval not reached");
    }

    function test_canPayout_insufficientBalance() public {
        vm.startPrank(user1);
        token.approve(address(vault), 100e6);
        vault.deposit(100e6);
        vault.setDailyLimit(WEEKLY_LIMIT);
        vm.stopPrank();

        vm.warp(block.timestamp + 7 days);

        (bool eligible, string memory reason) = vault.canPayout(user1);
        assertFalse(eligible);
        assertEq(reason, "Insufficient balance");
    }

    function test_nextPayoutTime() public {
        vm.startPrank(user1);
        token.approve(address(vault), INITIAL_BALANCE);
        vault.deposit(INITIAL_BALANCE);
        vault.setDailyLimit(WEEKLY_LIMIT);
        vm.stopPrank();

        // Before any payout
        assertEq(vault.nextPayoutTime(user1), 7 days);

        // After first payout
        vm.warp(block.timestamp + 7 days);
        vault.payout(user1);

        assertEq(vault.nextPayoutTime(user1), block.timestamp + 7 days);
    }

    // ============ Upgrade Tests ============

    function test_upgrade() public {
        // Deploy new implementation
        VestraVault newImpl = new VestraVault();

        // Upgrade
        vault.upgradeToAndCall(address(newImpl), "");

        // Verify state is preserved
        assertEq(address(vault.token()), address(token));
        assertEq(vault.owner(), owner);
    }

    function test_upgrade_revertsForNonOwner() public {
        VestraVault newImpl = new VestraVault();

        vm.prank(user1);
        vm.expectRevert(MonerioVault.OnlyOwner.selector);
        vault.upgradeToAndCall(address(newImpl), "");
    }
}
