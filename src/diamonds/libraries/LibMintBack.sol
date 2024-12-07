// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library LibMintBack {
    struct MintBackDiamondStorage {
        mapping(address => bool) Done;
    }

    // Returns the struct from a specified position in contract storage
    // ds is short for DiamondStorage
    function diamondStorage() internal pure returns (MintBackDiamondStorage storage ds) {
        // Specifies a random position from a hash of a string
        bytes32 storagePosition = keccak256("diamond.standard.mintBack.storage");

        // Set the position of our struct in contract storage
        assembly {
            ds.slot := storagePosition
        }
    }
}
