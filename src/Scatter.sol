// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

interface IERC1155 {
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data) external;
}

contract Scatter {
    function scatterNativeCurrency(address[] memory recipients, uint256[] memory amounts) external payable {
        for (uint256 i = 0; i < recipients.length; i++) {
            payable(recipients[i]).transfer(amounts[i]);
        }
    }

    function scatterERC20Token(address token, address[] memory recipients, uint256[] memory amounts) external {
        for (uint256 i = 0; i < recipients.length; i++) {
            IERC20(token).transfer(recipients[i], amounts[i]);
        }
    }

    function scatterERC1155Token(address token, address[] memory recipients, uint256[] memory amounts, uint256[] memory ids) external {
        for (uint256 i = 0; i < recipients.length; i++) {
            IERC1155(token).safeTransferFrom(msg.sender, recipients[i], ids[i], amounts[i], "");
        }
    }
}