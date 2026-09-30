// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AdExchangeToken
 * @notice Mock USDG token for testing the Advertising Exchange on Robinhood Chain testnet
 * @dev USDG uses 6 decimals, EIP-712 domain: {"name": "Global Dollar", "version": "1"}
 */
contract AdExchangeToken is ERC20, Ownable {
    uint8 private constant DECIMALS = 6;

    constructor() ERC20("Ad Exchange USDG", "axUSDG") Ownable(msg.sender) {
        _mint(msg.sender, 1_000_000 * 10 ** DECIMALS);
    }

    function decimals() public pure override returns (uint8) {
        return DECIMALS;
    }

    /// @notice Mint new tokens (test only)
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
