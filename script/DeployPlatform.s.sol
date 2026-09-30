// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Script, console2 } from "forge-std/Script.sol";
import { MockUSDG } from "../src/MockUSDG.sol";
import { CreatorRegistry } from "../src/CreatorRegistry.sol";
import { PlatformStreamManager } from "../src/PlatformStreamManager.sol";

contract DeployPlatform is Script {
    // Адреса Sablier Flow для разных сетей
    // Robinhood Chain MAINNET (4663):
    address constant SABLIER_FLOW_MAINNET = 0x6A99492B94765842808e332143296c8ADE09a922;
    
    // Для TESTNET (46630) — если развернёте Sablier Flow сами, укажите свой адрес
    // address constant SABLIER_FLOW_TESTNET = 0x...; 

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Деплоим MockUSDG (тестовый токен)
        MockUSDG mockUSDG = new MockUSDG();
        console2.log("MockUSDG deployed to:", address(mockUSDG));

        // 2. Деплоим CreatorRegistry
        CreatorRegistry registry = new CreatorRegistry();
        console2.log("CreatorRegistry deployed to:", address(registry));

        // 3. Определяем адрес Sablier Flow в зависимости от сети
        address sablierFlow;
        if (block.chainid == 4663) {
            sablierFlow = SABLIER_FLOW_MAINNET;
            console2.log("Using MAINNET Sablier Flow");
        } else if (block.chainid == 46630) {
            // ЗАМЕНИТЕ на адрес вашего развернутого Sablier Flow в testnet
            sablierFlow = vm.envAddress("SABLIER_FLOW_TESTNET");
            console2.log("Using TESTNET Sablier Flow:", sablierFlow);
        } else {
            revert("Unsupported chain");
        }

        // 4. Деплоим PlatformStreamManager
        PlatformStreamManager streamManager = new PlatformStreamManager(
            sablierFlow,
            address(mockUSDG),
            deployer  // platformFeeRecipient = deployer (ваш кошелёк)
        );
        console2.log("PlatformStreamManager deployed to:", address(streamManager));

        vm.stopBroadcast();

        // Итоговый вывод
        console2.log("\n=== DEPLOYMENT SUMMARY ===");
        console2.log("Chain ID:", block.chainid);
        console2.log("MockUSDG:", address(mockUSDG));
        console2.log("CreatorRegistry:", address(registry));
        console2.log("PlatformStreamManager:", address(streamManager));
        console2.log("Sablier Flow used:", sablierFlow);
    }
}
