// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AdvertiserRegistry
 * @notice Registry of advertisers (bloggers/streamers) on the Advertising Exchange
 */
contract AdvertiserRegistry is Ownable {
    
    struct Advertiser {
        string username;
        string metadataURI;      // IPFS hash with avatar, description
        uint256 registeredAt;
        bool isActive;
    }

    mapping(address => Advertiser) public advertisers;
    mapping(string => address) public usernameToAddress;
    address[] public allAdvertisers;

    event AdvertiserRegistered(address indexed advertiser, string username);
    event AdvertiserUpdated(address indexed advertiser, string metadataURI);
    event AdvertiserDeactivated(address indexed advertiser);

    constructor() Ownable(msg.sender) {}

    function registerAdvertiser(string calldata username, string calldata metadataURI) external {
        require(bytes(username).length > 0, "Username required");
        require(usernameToAddress[username] == address(0), "Username taken");
        require(!advertisers[msg.sender].isActive, "Already registered");

        advertisers[msg.sender] = Advertiser({
            username: username,
            metadataURI: metadataURI,
            registeredAt: block.timestamp,
            isActive: true
        });

        usernameToAddress[username] = msg.sender;
        allAdvertisers.push(msg.sender);

        emit AdvertiserRegistered(msg.sender, username);
    }

    function updateMetadata(string calldata metadataURI) external {
        require(advertisers[msg.sender].isActive, "Not registered");
        advertisers[msg.sender].metadataURI = metadataURI;
        emit AdvertiserUpdated(msg.sender, metadataURI);
    }

    function deactivate() external {
        require(advertisers[msg.sender].isActive, "Not active");
        advertisers[msg.sender].isActive = false;
        emit AdvertiserDeactivated(msg.sender);
    }

    function getActiveAdvertisers() external view returns (address[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < allAdvertisers.length; i++) {
            if (advertisers[allAdvertisers[i]].isActive) count++;
        }
        address[] memory active = new address[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < allAdvertisers.length; i++) {
            if (advertisers[allAdvertisers[i]].isActive) {
                active[index] = allAdvertisers[i];
                index++;
            }
        }
        return active;
    }

    function getAddressByUsername(string calldata username) external view returns (address) {
        return usernameToAddress[username];
    }
}
