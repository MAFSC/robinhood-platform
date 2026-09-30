// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Script, console2 } from "forge-std/Script.sol";
import { AdExchangeToken } from "../src/AdExchangeToken.sol";
import { AdvertiserRegistry } from "../src/AdvertiserRegistry.sol";
import { MockStreamFlow } from "../src/MockStreamFlow.sol";
import { AdExchangeManager } from "../src/AdExchangeManager.sol";

/**
 * @title DeployAdExchange
 * @notice Deployment script for Advertising Exchange on Blockchain
 */
contract DeployAdExchange is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy AdExchangeToken (mock USDG)
        AdExchangeToken token = new AdExchangeToken();
        console2.log("AdExchangeToken:", address(token));

        // 2. Deploy MockStreamFlow (mock Sablier Flow)
        MockStreamFlow flow = new MockStreamFlow();
        console2.log("MockStreamFlow:", address(flow));

        // 3. Deploy AdvertiserRegistry
        AdvertiserRegistry registry = new AdvertiserRegistry();
        console2.log("AdvertiserRegistry:", address(registry));

        // 4. Deploy AdExchangeManager
        AdExchangeManager manager = new AdExchangeManager(
            address(flow),
            address(token),
            deployer
        );
        console2.log("AdExchangeManager:", address(manager));

        vm.stopBroadcast();

        console2.log("\n=== DEPLOYMENT SUMMARY ===");
        console2.log("Chain ID:", block.chainid);
        console2.log("AdExchangeToken:", address(token));
        console2.log("MockStreamFlow:", address(flow));
        console2.log("AdvertiserRegistry:", address(registry));
        console2.log("AdExchangeManager:", address(manager));
    }
}
