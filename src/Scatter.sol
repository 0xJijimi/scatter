// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";


contract Scatter is ReentrancyGuard {
    event NativeCurrencyScattered(address indexed sender, address[] recipients, uint256[] amounts);
    event ERC20Scattered(address indexed sender, address indexed token, address[] recipients, uint256[] amounts);
    event ERC1155Scattered(address indexed sender, address indexed token, address[] recipients, uint256[] ids, uint256[] amounts);

    error ArrayLengthMismatch();
    error InsufficientValue();
    error ZeroAddress();
    error ZeroAmount();

    mapping(address => uint256) public totalTokenScattered;
    mapping(address => mapping(uint256 => uint256)) public totalERC1155Scattered;
    uint256 public totalNativeScattered;

    function scatterNativeCurrency(address[] memory recipients, uint256[] memory amounts) external payable nonReentrant {
        if (recipients.length != amounts.length) revert ArrayLengthMismatch();
        if (recipients.length == 0) revert ArrayLengthMismatch();
        
        uint256 totalAmount;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }
        if (msg.value < totalAmount) revert InsufficientValue();

        for (uint256 i = 0; i < recipients.length; i++) {
            if (recipients[i] == address(0)) revert ZeroAddress();
            if (amounts[i] == 0) revert ZeroAmount();
            
            payable(recipients[i]).transfer(amounts[i]);
            totalNativeScattered += amounts[i];
        }
        
        emit NativeCurrencyScattered(msg.sender, recipients, amounts);
    }

    function scatterERC20Token(address token, address[] memory recipients, uint256[] memory amounts) external nonReentrant {
        if (recipients.length != amounts.length) revert ArrayLengthMismatch();
        if (recipients.length == 0) revert ArrayLengthMismatch();
        if (token == address(0)) revert ZeroAddress();

        for (uint256 i = 0; i < recipients.length; i++) {
            if (recipients[i] == address(0)) revert ZeroAddress();
            if (amounts[i] == 0) revert ZeroAmount();
            
            IERC20(token).transferFrom(msg.sender, recipients[i], amounts[i]);
            totalTokenScattered[token] += amounts[i];
        }
        
        emit ERC20Scattered(msg.sender, token, recipients, amounts);
    }

    function scatterERC1155Token(
        address token,
        address[] memory recipients,
        uint256[] memory amounts,
        uint256[] memory ids
    ) external nonReentrant {
        if (recipients.length != amounts.length || recipients.length != ids.length) revert ArrayLengthMismatch();
        if (recipients.length == 0) revert ArrayLengthMismatch();
        if (token == address(0)) revert ZeroAddress();

        for (uint256 i = 0; i < recipients.length; i++) {
            if (recipients[i] == address(0)) revert ZeroAddress();
            if (amounts[i] == 0) revert ZeroAmount();
            
            IERC1155(token).safeTransferFrom(msg.sender, recipients[i], ids[i], amounts[i], "");
            totalERC1155Scattered[token][ids[i]] += amounts[i];
        }
        
        emit ERC1155Scattered(msg.sender, token, recipients, ids, amounts);
    }

    function scatterERC1155TokenSingle(
        address token,
        address[] memory recipients,
        uint256 id,
        uint256 amount
    ) external nonReentrant {
        if (recipients.length == 0) revert ArrayLengthMismatch();
        if (token == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        uint256[] memory amounts = new uint256[](recipients.length);
        uint256[] memory ids = new uint256[](recipients.length);
        
        for (uint256 i = 0; i < recipients.length; i++) {
            if (recipients[i] == address(0)) revert ZeroAddress();
            
            IERC1155(token).safeTransferFrom(msg.sender, recipients[i], id, amount, "");
            amounts[i] = amount;
            ids[i] = id;
            totalERC1155Scattered[token][id] += amount;
        }
        
        emit ERC1155Scattered(msg.sender, token, recipients, ids, amounts);
    }
}