// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library LibFighting {
    struct Commit {
        bytes32 hash; // Hash of the secret and nonce
        bool hasRevealed; // Flag to check if the pet has already revealed
    }

    struct FightingDiamondStorage {
        address _artefactAddress;
        uint256 _winningCap;
        bool initialized;
        mapping(address => mapping(uint256 => Commit)) commits; // Maps user address and pet ID to their commit
        mapping(bytes32 => bool) usedCommitHashes; // Ensures each commit hash is only used once
    }

    // Returns the struct from a specified position in contract storage
    // ds is short for DiamondStorage
    function diamondStorage() internal pure returns (FightingDiamondStorage storage ds) {
        // Specifies a random position from a hash of a string
        bytes32 storagePosition = keccak256("diamond.standard.fighting.storage");

        // Set the position of our struct in contract storage
        assembly {
            ds.slot := storagePosition
        }
    }
}
