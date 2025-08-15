// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract OnChainWhitelist is Ownable {
    mapping(address => bool) public whitelist;

    modifier onlyWhitelisted(address _account) {
        require(whitelist[_account], "user not whitelisted!");
        _;
    }

    constructor(address initialOwner) Ownable(initialOwner) {}

    function addToWhitelist(address[] calldata toAddAddresses) external onlyOwner {
        for (uint256 i = 0; i < toAddAddresses.length; i++) {
            whitelist[toAddAddresses[i]] = true;
        }
    }

    function removeFromWhitelist(address[] calldata toRemoveAddresses) external onlyOwner {
        for (uint256 i = 0; i < toRemoveAddresses.length; i++) {
            delete whitelist[toRemoveAddresses[i]];
        }
    }
}
