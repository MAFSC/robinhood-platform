// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MockUSDG
 * @notice Тестовый токен для имитации USDG в тестовой сети Robinhood Chain
 * @dev USDG использует 6 decimals, EIP-712 domain: {"name": "Global Dollar", "version": "1"}
 */
contract MockUSDG is ERC20, Ownable {
    uint8 private constant DECIMALS = 6;

    constructor() ERC20("Mock USDG", "mUSDG") Ownable(msg.sender) {
        // Mint 1,000,000 токенов deployer'у
        _mint(msg.sender, 1_000_000 * 10 ** DECIMALS);
    }

    function decimals() public pure override returns (uint8) {
        return DECIMALS;
    }

    /// @notice Функция для минта токенов (только для тестов)
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
