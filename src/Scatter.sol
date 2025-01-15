// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

/// @title Scatter
/// @notice A contract for distributing native currency, ERC20, and ERC1155 tokens to multiple recipients
/// @dev Implements multiple security features:
///      - ReentrancyGuardTransient: Prevents reentrant calls during token distributions
///      - Ownable: Restricts admin functions to the contract owner
///      - Pausable: Allows emergency pause of all distribution functions
///      - ERC1155Holder: Enables the contract to receive ERC1155 tokens to be able to withdraw stuck tokens
contract Scatter is ReentrancyGuardTransient, Ownable, Pausable, ERC1155Holder {
    // Events emitted when tokens are scattered
    event NativeCurrencyScattered(address indexed sender, address[] recipients, uint256[] amounts);
    event ERC20Scattered(address indexed sender, address indexed token, address[] recipients, uint256[] amounts);
    event ERC1155Scattered(address indexed sender, address indexed token, address[] recipients, uint256[] ids, uint256[] amounts);

    // Custom errors for better gas efficiency and clearer error messages
    error ArrayLengthMismatch();
    error InsufficientValue();
    error ZeroAddress();
    error ZeroAmount();
    error NoTokensToWithdraw();
    error NoETHToWithdraw();
    error ETHTransferFailed();
    error TokenTransferFailed();
    error ERC1155TransferFailed();

    // State variables to track total amounts scattered
    mapping(address => uint256) public totalTokenScattered;
    mapping(address => mapping(uint256 => uint256)) public totalERC1155Scattered;
    uint256 public totalNativeScattered;

    constructor() Ownable(msg.sender) {}

    /// @notice Distributes native currency to multiple recipients
    /// @dev Validates input arrays, calculates total amount needed, transfers ETH to each recipient,
    ///      and returns any excess ETH to the sender. Prevents reentrancy and can be paused.
    /// @param recipients Array of recipient addresses
    /// @param amounts Array of amounts to send to each recipient
    function scatterNativeCurrency(address[] memory recipients, uint256[] memory amounts) external payable nonReentrant whenNotPaused {
        require(recipients.length == amounts.length, ArrayLengthMismatch());
        require(recipients.length > 0, ArrayLengthMismatch());
        
        // Calculate total amount needed
        uint256 totalAmount;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }
        require(msg.value >= totalAmount, InsufficientValue());

        // Transfer to each recipient
        for (uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i] != address(0), ZeroAddress());
            require(amounts[i] > 0, ZeroAmount());
            
            payable(recipients[i]).transfer(amounts[i]);
            totalNativeScattered += amounts[i];
        }
        
        // Return excess ETH if any
        uint256 excess = msg.value - totalAmount;
        if (excess > 0) {
            (bool success, ) = payable(msg.sender).call{value: excess}("");
            require(success, ETHTransferFailed());
        }
        
        emit NativeCurrencyScattered(msg.sender, recipients, amounts);
    }

    /// @notice Distributes ERC20 tokens to multiple recipients
    /// @dev Uses transferFrom to move tokens directly from sender to recipients.
    ///      Requires prior approval from sender. Returns any excess tokens that may have been
    ///      directly transferred to the contract. Prevents reentrancy and can be paused.
    /// @param token Address of the ERC20 token contract
    /// @param recipients Array of recipient addresses
    /// @param amounts Array of token amounts to send to each recipient
    function scatterERC20Token(address token, address[] memory recipients, uint256[] memory amounts) external nonReentrant whenNotPaused {
        require(recipients.length == amounts.length, ArrayLengthMismatch());
        require(recipients.length > 0, ArrayLengthMismatch());
        require(token != address(0), ZeroAddress());

        uint256 totalAmount;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }

        // Transfer tokens from sender to recipients
        for (uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i] != address(0), ZeroAddress());
            require(amounts[i] > 0, ZeroAmount());
            
            IERC20(token).transferFrom(msg.sender, recipients[i], amounts[i]);
            totalTokenScattered[token] += amounts[i];
        }

        // Return excess tokens if any were transferred to the contract
        uint256 contractBalance = IERC20(token).balanceOf(address(this));
        if (contractBalance > 0) {
            require(IERC20(token).transfer(msg.sender, contractBalance), TokenTransferFailed());
        }
        
        emit ERC20Scattered(msg.sender, token, recipients, amounts);
    }

    /// @notice Distributes ERC1155 tokens to multiple recipients
    /// @dev Optimizes for gas by using batch transfer when there's only one recipient.
    ///      For multiple recipients, performs individual transfers. Requires prior approval
    ///      from sender. Prevents reentrancy and can be paused.
    /// @param token Address of the ERC1155 token contract
    /// @param recipients Array of recipient addresses
    /// @param amounts Array of token amounts to send to each recipient
    /// @param ids Array of token IDs to send to each recipient
    function scatterERC1155Token(
        address token,
        address[] memory recipients,
        uint256[] memory amounts,
        uint256[] memory ids
    ) external nonReentrant whenNotPaused {
        require(recipients.length == amounts.length && recipients.length == ids.length, ArrayLengthMismatch());
        require(recipients.length > 0, ArrayLengthMismatch());
        require(token != address(0), ZeroAddress());

        if (recipients.length == 1) {
            // For single recipient, use batch transfer for gas efficiency
            require(recipients[0] != address(0), ZeroAddress());
            require(amounts[0] > 0, ZeroAmount());

            IERC1155(token).safeBatchTransferFrom(msg.sender, recipients[0], ids, amounts, "");
            for (uint256 i = 0; i < ids.length; i++) {
                totalERC1155Scattered[token][ids[i]] += amounts[i];
            }
        } else {
            // Multiple recipients - transfer tokens individually
            for (uint256 i = 0; i < recipients.length; i++) {
                require(recipients[i] != address(0), ZeroAddress());
                require(amounts[i] > 0, ZeroAmount());
                
                IERC1155(token).safeTransferFrom(msg.sender, recipients[i], ids[i], amounts[i], "");
                totalERC1155Scattered[token][ids[i]] += amounts[i];
            }
        }
        
        emit ERC1155Scattered(msg.sender, token, recipients, ids, amounts);
    }

    /// @notice Allows owner to withdraw any ETH accidentally sent to the contract
    /// @dev Safety function to recover ETH. Only callable by contract owner.
    ///      Transfers entire contract ETH balance to owner.
    function withdrawStuckETH() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, NoETHToWithdraw());
        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, ETHTransferFailed());
    }

    /// @notice Allows owner to withdraw any ERC20 tokens accidentally sent to the contract
    /// @dev Safety function to recover ERC20 tokens. Only callable by contract owner.
    ///      Transfers entire token balance to owner.
    /// @param token Address of the ERC20 token contract to withdraw
    function withdrawStuckERC20(address token) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        require(balance > 0, NoTokensToWithdraw());
        require(IERC20(token).transfer(owner(), balance), TokenTransferFailed());
    }

    /// @notice Allows owner to withdraw any ERC1155 tokens accidentally sent to the contract
    /// @dev Safety function to recover a single ERC1155 token. Only callable by contract owner.
    ///      Transfers entire token balance to owner.
    /// @param token Address of the ERC1155 token contract
    /// @param id ID of the token to withdraw
    function withdrawStuckERC1155(address token, uint256 id) external onlyOwner {
        uint256 balance = IERC1155(token).balanceOf(address(this), id);
        require(balance > 0, NoTokensToWithdraw());
        IERC1155(token).safeTransferFrom(
            address(this),
            owner(),
            id,
            balance,
            ""
        );
    }

    /// @notice Allows owner to withdraw multiple ERC1155 tokens in a single transaction
    /// @dev Safety function to recover multiple ERC1155 tokens in one transaction.
    ///      Only callable by contract owner. Checks if at least one token has positive balance
    ///      before attempting withdrawal.
    /// @param token Address of the ERC1155 token contract
    /// @param ids Array of token IDs to withdraw
    function withdrawStuckERC1155Batch(
        address token,
        uint256[] calldata ids
    ) external onlyOwner {
        uint256[] memory balances = new uint256[](ids.length);
        bool hasTokens = false;
        
        for (uint256 i = 0; i < ids.length; i++) {
            balances[i] = IERC1155(token).balanceOf(address(this), ids[i]);
            if (balances[i] > 0) hasTokens = true;
        }
        
        require(hasTokens, NoTokensToWithdraw());
        IERC1155(token).safeBatchTransferFrom(
            address(this),
            owner(),
            ids,
            balances,
            ""
        );
    }

    /// @notice Allows the contract to receive ETH
    /// @dev Required for contract to receive ETH transfers and refunds
    receive() external payable {}

    /// @notice Pauses all token scattering operations
    /// @dev Emergency function to pause all scatter operations.
    ///      Only callable by contract owner.
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpauses all token scattering operations
    /// @dev Resumes scatter operations after emergency pause.
    ///      Only callable by contract owner.
    function unpause() external onlyOwner {
        _unpause();
    }
}