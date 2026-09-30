// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Script, console2 } from "forge-std/Script.sol";
import { MockUSDG } from "../src/MockUSDG.sol";
import { CreatorRegistry } from "../src/CreatorRegistry.sol";
import { MockSablierFlow } from "../src/MockSablierFlow.sol";
import { PlatformStreamManager } from "../src/PlatformStreamManager.sol";

contract DeployMockPlatform is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // 1. MockUSDG
        MockUSDG mockUSDG = new MockUSDG();
        console2.log("MockUSDG:", address(mockUSDG));

        // 2. MockSablierFlow
        MockSablierFlow mockFlow = new MockSablierFlow();
        console2.log("MockSablierFlow:", address(mockFlow));

        // 3. CreatorRegistry
        CreatorRegistry registry = new CreatorRegistry();
        console2.log("CreatorRegistry:", address(registry));

        // 4. PlatformStreamManager (с Mock Flow)
        PlatformStreamManager manager = new PlatformStreamManager(
            address(mockFlow),
            address(mockUSDG),
            deployer
        );
        console2.log("PlatformStreamManager:", address(manager));

        vm.stopBroadcast();
    }
}
