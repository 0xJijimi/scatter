// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "lib/forge-std/src/Script.sol";
import {Scatter} from "../src/Scatter.sol";

contract DeployScatter is Script {
    function run() external returns (Scatter) {
        // Retrieve deployer's private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the contract with deployer as owner
        Scatter scatter = new Scatter();

        vm.stopBroadcast();

        // Log the deployment and chain info
        console2.log("Network Chain ID:", block.chainid);
        console2.log("Scatter deployed to:", address(scatter));
        console2.log("Owner set to:", scatter.owner());

        return scatter;
    }
}