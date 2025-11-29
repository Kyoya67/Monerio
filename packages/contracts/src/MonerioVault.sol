// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title MonerioVault
/// @notice A vault contract for automated periodic withdrawals
/// @dev UUPS upgradeable contract for managing user deposits and scheduled payouts
contract MonerioVault is Initializable, UUPSUpgradeable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ State Variables ============

    /// @notice The ERC20 token managed by this vault
    IERC20 public token;

    /// @notice The owner of the contract (can upgrade and emergency withdraw)
    address public owner;

    /// @notice User balances in the vault
    mapping(address => uint256) public balances;

    /// @notice Weekly withdrawal limit per user (named dailyLimit per spec)
    mapping(address => uint256) public dailyLimit;

    /// @notice Timestamp of last payout per user
    mapping(address => uint256) public lastPayout;

    /// @notice Gap for future storage variables
    uint256[50] private __gap;

    // ============ Constants ============

    /// @notice Payout interval (1 minute for testing, change to 7 days for production)
    uint256 public constant PAYOUT_INTERVAL = 1 minutes;

    // ============ Events ============

    event Deposited(address indexed user, uint256 amount);
    event DailyLimitSet(address indexed user, uint256 amount);
    event Payout(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed to, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ============ Errors ============

    error OnlyOwner();
    error ZeroAmount();
    error ZeroAddress();
    error PayoutTooEarly();
    error InsufficientBalance();
    error TransferFailed();

    // ============ Modifiers ============

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    // ============ Initializer ============

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the vault
    /// @param token_ The ERC20 token address to be managed
    function initialize(address token_) public initializer {
        if (token_ == address(0)) revert ZeroAddress();

        token = IERC20(token_);
        owner = msg.sender;
    }

    // ============ External Functions ============

    /// @notice Deposit tokens into the vault
    /// @param amount The amount of tokens to deposit
    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        balances[msg.sender] += amount;
        token.safeTransferFrom(msg.sender, address(this), amount);

        emit Deposited(msg.sender, amount);
    }

    /// @notice Set the weekly withdrawal limit
    /// @param amount The weekly limit amount
    function setDailyLimit(uint256 amount) external {
        dailyLimit[msg.sender] = amount;
        emit DailyLimitSet(msg.sender, amount);
    }

    /// @notice Execute payout to a user (called by CRE or anyone)
    /// @param user The user address to pay out
    function payout(address user) external nonReentrant {
        if (user == address(0)) revert ZeroAddress();

        uint256 limit = dailyLimit[user];
        if (limit == 0) revert ZeroAmount();

        // Check if enough time has passed since last payout
        if (block.timestamp < lastPayout[user] + PAYOUT_INTERVAL) {
            revert PayoutTooEarly();
        }

        // Check if user has sufficient balance
        if (balances[user] < limit) revert InsufficientBalance();

        // Update state before transfer (CEI pattern)
        balances[user] -= limit;
        lastPayout[user] = block.timestamp;

        // Transfer tokens to user
        token.safeTransfer(user, limit);

        emit Payout(user, limit);
    }

    /// @notice Emergency withdraw all tokens (owner only)
    /// @param to The address to send tokens to
    function emergencyWithdraw(address to) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();

        uint256 balance = token.balanceOf(address(this));
        if (balance == 0) revert ZeroAmount();

        token.safeTransfer(to, balance);

        emit EmergencyWithdraw(to, balance);
    }

    /// @notice Transfer ownership to a new address
    /// @param newOwner The new owner address
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();

        address oldOwner = owner;
        owner = newOwner;

        emit OwnershipTransferred(oldOwner, newOwner);
    }

    // ============ View Functions ============

    /// @notice Check if a user can receive payout
    /// @param user The user address to check
    /// @return eligible Whether payout is possible
    /// @return reason The reason if payout is not possible
    function canPayout(address user) external view returns (bool eligible, string memory reason) {
        if (dailyLimit[user] == 0) {
            return (false, "No daily limit set");
        }
        if (block.timestamp < lastPayout[user] + PAYOUT_INTERVAL) {
            return (false, "Payout interval not reached");
        }
        if (balances[user] < dailyLimit[user]) {
            return (false, "Insufficient balance");
        }
        return (true, "");
    }

    /// @notice Get the next payout time for a user
    /// @param user The user address
    /// @return The timestamp when next payout is available
    function nextPayoutTime(address user) external view returns (uint256) {
        return lastPayout[user] + PAYOUT_INTERVAL;
    }

    // ============ Internal Functions ============

    /// @notice Authorize contract upgrades (owner only)
    /// @param newImplementation The new implementation address
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner { }
}
