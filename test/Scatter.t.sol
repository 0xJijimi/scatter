// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "lib/forge-std/src/Test.sol";
import {Scatter} from "../src/Scatter.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockERC1155} from "./mocks/MockERC1155.sol";
import {GasConsumingMock} from "./mocks/GasConsumingMock.sol";
import {RevertingMock} from "./mocks/RevertingMock.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";


contract ScatterTest is Test, ERC1155Holder {
    Scatter public scatter;
    MockERC20 public token;
    MockERC1155 public token1155;

    address public owner;
    address public alice;
    address public bob;
    address public charlie;

    function setUp() public {
        owner = makeAddr("owner");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        vm.startPrank(owner);
        scatter = new Scatter();
        token = new MockERC20();
        token1155 = new MockERC1155();
        vm.stopPrank();

        // Fund test addresses
        vm.deal(owner, 100 ether);
        vm.deal(alice, 100 ether);

        // Mint tokens for testing
        token.mint(alice, 1000e18);
        token1155.mint(alice, 1, 100);
        token1155.mint(alice, 2, 100);
    }

    function testScatterNativeCurrency() public {
        address[] memory recipients = new address[](3);
        recipients[0] = bob;
        recipients[1] = charlie;
        recipients[2] = alice;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 1 ether;
        amounts[1] = 2 ether;
        amounts[2] = 3 ether;

        uint256 totalAmount = 6 ether;
        uint256 bobInitialBalance = bob.balance;
        uint256 charlieInitialBalance = charlie.balance;
        uint256 aliceInitialBalance = alice.balance;

        scatter.scatterNativeCurrency{value: totalAmount}(recipients, amounts);

        assertEq(bob.balance, bobInitialBalance + 1 ether);
        assertEq(charlie.balance, charlieInitialBalance + 2 ether);
        assertEq(alice.balance, aliceInitialBalance + 3 ether);
        assertEq(scatter.totalNativeScattered(), totalAmount);
    }

    function testScatterERC20() public {
        vm.startPrank(alice);

        address[] memory recipients = new address[](2);
        recipients[0] = bob;
        recipients[1] = charlie;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100e18;
        amounts[1] = 200e18;

        token.approve(address(scatter), 300e18);
        scatter.scatterERC20Token(address(token), recipients, amounts);

        assertEq(token.balanceOf(bob), 100e18);
        assertEq(token.balanceOf(charlie), 200e18);
        assertEq(scatter.totalTokenScattered(address(token)), 300e18);

        vm.stopPrank();
    }

    function testScatterERC1155Single() public {
        vm.startPrank(alice);

        address[] memory recipients = new address[](1);
        recipients[0] = bob;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 50;

        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;

        token1155.setApprovalForAll(address(scatter), true);
        scatter.scatterERC1155Token(address(token1155), recipients, amounts, ids);

        assertEq(token1155.balanceOf(bob, 1), 50);
        assertEq(scatter.totalERC1155Scattered(address(token1155), 1), 50);

        vm.stopPrank();
    }

    function testScatterERC1155Multiple() public {
        vm.startPrank(alice);

        address[] memory recipients = new address[](2);
        recipients[0] = bob;
        recipients[1] = charlie;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 30;
        amounts[1] = 20;

        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;

        token1155.setApprovalForAll(address(scatter), true);
        scatter.scatterERC1155Token(address(token1155), recipients, amounts, ids);

        assertEq(token1155.balanceOf(bob, 1), 30);
        assertEq(token1155.balanceOf(charlie, 2), 20);

        vm.stopPrank();
    }

    function test_RevertWhen_InsufficientValue() public {
        address[] memory recipients = new address[](1);
        recipients[0] = bob;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1 ether;

        vm.expectRevert(Scatter.InsufficientValue.selector);
        scatter.scatterNativeCurrency{value: 0.5 ether}(recipients, amounts);
    }

    function test_RevertWhen_ZeroAddress() public {
        address[] memory recipients = new address[](1);
        recipients[0] = address(0);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1 ether;

        vm.expectRevert(Scatter.ZeroAddress.selector);
        scatter.scatterNativeCurrency{value: 1 ether}(recipients, amounts);
    }

    function testWithdrawStuckETH() public {
        // Send some ETH to the contract
        (bool success,) = address(scatter).call{value: 1 ether}("");
        require(success, "Transfer failed");

        uint256 initialBalance = owner.balance;
        vm.prank(owner);
        scatter.withdrawStuckETH();
        assertEq(owner.balance, initialBalance + 1 ether);
    }

    function testWithdrawStuckERC20() public {
        // Send some tokens to the contract
        token.mint(address(scatter), 100e18);

        uint256 initialBalance = token.balanceOf(owner);
        vm.prank(owner);
        scatter.withdrawStuckERC20(address(token));
        assertEq(token.balanceOf(owner), initialBalance + 100e18);
    }

    function testWithdrawStuckERC1155() public {
        // Send some tokens to the contract
        token1155.mint(address(scatter), 1, 50);

        uint256 initialBalance = token1155.balanceOf(owner, 1);
        vm.prank(owner);
        scatter.withdrawStuckERC1155(address(token1155), 1);
        assertEq(token1155.balanceOf(owner, 1), initialBalance + 50);
    }

    function testPauseUnpause() public {
        vm.startPrank(owner);

        // Test pausing
        scatter.pause();
        assertTrue(scatter.paused());

        // Test unpausing
        scatter.unpause();
        assertFalse(scatter.paused());

        vm.stopPrank();
    }

    function test_RevertWhen_PauseNonOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        scatter.pause();
    }

    function test_RevertWhen_ScatterWhilePaused() public {
        // Setup test data
        address[] memory recipients = new address[](1);
        recipients[0] = bob;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1 ether;

        // Pause the contract
        vm.prank(owner);
        scatter.pause();

        // Try to scatter while paused (should fail)
        vm.expectRevert(Pausable.EnforcedPause.selector);
        scatter.scatterNativeCurrency{value: 1 ether}(recipients, amounts);
    }

    function test_RevertWhen_ERC20ScatterWhilePaused() public {
        vm.startPrank(alice);

        address[] memory recipients = new address[](1);
        recipients[0] = bob;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100e18;

        token.approve(address(scatter), 100e18);

        // Pause the contract
        vm.stopPrank();
        vm.prank(owner);
        scatter.pause();

        // Try to scatter while paused (should fail)
        vm.prank(alice);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        scatter.scatterERC20Token(address(token), recipients, amounts);
    }

    function testScatterNativeCurrencyWithExcess() public {
        address[] memory recipients = new address[](2);
        recipients[0] = bob;
        recipients[1] = charlie;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1 ether;
        amounts[1] = 2 ether;

        uint256 excessAmount = 1 ether;
        uint256 totalSent = 4 ether; // 3 ether needed + 1 ether excess
        uint256 senderInitialBalance = address(this).balance;

        scatter.scatterNativeCurrency{value: totalSent}(recipients, amounts);

        // Check that excess was returned
        assertEq(address(this).balance, senderInitialBalance - (totalSent - excessAmount));
    }

    function testScatterERC20WithExcess() public {
        vm.startPrank(alice);

        address[] memory recipients = new address[](2);
        recipients[0] = bob;
        recipients[1] = charlie;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100e18;
        amounts[1] = 200e18;

        uint256 approvalAmount = 400e18; // 100e18 excess
        token.approve(address(scatter), approvalAmount);

        uint256 aliceInitialBalance = token.balanceOf(alice);
        scatter.scatterERC20Token(address(token), recipients, amounts);

        // Check that only the necessary amount was transferred
        assertEq(token.balanceOf(alice), aliceInitialBalance - 300e18);

        vm.stopPrank();
    }

    function testScatterERC1155WithExcess() public {
        vm.startPrank(alice);

        address[] memory recipients = new address[](1);
        recipients[0] = bob;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 50;

        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;

        uint256 aliceInitialBalance = token1155.balanceOf(alice, 1);
        token1155.setApprovalForAll(address(scatter), true);
        scatter.scatterERC1155Token(address(token1155), recipients, amounts, ids);

        // Check that only the necessary amount was transferred
        assertEq(token1155.balanceOf(alice, 1), aliceInitialBalance - 50);

        vm.stopPrank();
    }

    function testScatterNativeCurrencyWithHighGasConsumer() public {
        // Deploy a contract that consumes lots of gas in receive
        GasConsumingMock gasConsumer = new GasConsumingMock();
        
        address[] memory recipients = new address[](2);
        recipients[0] = address(gasConsumer);
        recipients[1] = alice;
        
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 0.1 ether;
        amounts[1] = 0.1 ether;
        
        uint256 aliceInitialBalance = alice.balance;
        
        // Should succeed despite high gas consumption in first recipient
        scatter.scatterNativeCurrency{value: 0.2 ether}(recipients, amounts);
        
        // Verify transfers succeeded
        assertEq(address(gasConsumer).balance, 0.1 ether);
        assertEq(alice.balance, aliceInitialBalance + 0.1 ether);  // Account for initial balance
    }

    function testScatterNativeCurrencyWithFailingReceive() public {
        // Deploy a contract that reverts in receive
        RevertingMock reverter = new RevertingMock();
        
        address[] memory recipients = new address[](1);
        recipients[0] = address(reverter);
        
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0.1 ether;
        
        // Should revert when trying to send to reverting contract
        vm.expectRevert(Scatter.ETHTransferFailed.selector);
        scatter.scatterNativeCurrency{value: 0.1 ether}(recipients, amounts);
    }

    function test_RevertWhen_SetTransferGasLimitNonOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        scatter.setTransferGasLimit(100000);
    }

    function testSetTransferGasLimitOwner() public {
        uint256 newLimit = 100000;
        vm.prank(owner);
        scatter.setTransferGasLimit(newLimit);
        assertEq(scatter.transferGasLimit(), newLimit);
    }

    receive() external payable {}
}
