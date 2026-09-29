// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title CreatorRegistry
 * @notice Реестр блогеров для платформы
 */
contract CreatorRegistry is Ownable {
    
    struct Creator {
        string username;
        string metadataURI; // IPFS хеш с аватаркой, описанием
        uint256 registeredAt;
        bool isActive;
    }

    mapping(address => Creator) public creators;
    mapping(string => address) public usernameToAddress;
    address[] public allCreators;

    event CreatorRegistered(address indexed creator, string username);
    event CreatorUpdated(address indexed creator, string metadataURI);
    event CreatorDeactivated(address indexed creator);

    constructor() Ownable(msg.sender) {}

    function registerCreator(string calldata username, string calldata metadataURI) external {
        require(bytes(username).length > 0, "Username required");
        require(usernameToAddress[username] == address(0), "Username taken");
        require(!creators[msg.sender].isActive, "Already registered");

        creators[msg.sender] = Creator({
            username: username,
            metadataURI: metadataURI,
            registeredAt: block.timestamp,
            isActive: true
        });

        usernameToAddress[username] = msg.sender;
        allCreators.push(msg.sender);

        emit CreatorRegistered(msg.sender, username);
    }

    function updateMetadata(string calldata metadataURI) external {
        require(creators[msg.sender].isActive, "Not registered");
        creators[msg.sender].metadataURI = metadataURI;
        emit CreatorUpdated(msg.sender, metadataURI);
    }

    function deactivate() external {
        require(creators[msg.sender].isActive, "Not active");
        creators[msg.sender].isActive = false;
        emit CreatorDeactivated(msg.sender);
    }

    function getActiveCreators() external view returns (address[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < allCreators.length; i++) {
            if (creators[allCreators[i]].isActive) count++;
        }

        address[] memory active = new address[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < allCreators.length; i++) {
            if (creators[allCreators[i]].isActive) {
                active[index] = allCreators[i];
                index++;
            }
        }
        return active;
    }

    function getAddressByUsername(string calldata username) external view returns (address) {
        return usernameToAddress[username];
    }
}

