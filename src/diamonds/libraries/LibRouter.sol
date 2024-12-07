// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library LibRouter {
    struct HyperLaneDiamondStorage {
        bool initialized;
        bool erc20Transfer;
    }

    function diamondStorage() internal pure returns (HyperLaneDiamondStorage storage ds) {
        // Specifies a random position from a hash of a string
        bytes32 storagePosition = keccak256("diamond.standard.hyperlane.storage");

        // Set the position of our struct in contract storage
        assembly {
            ds.slot := storagePosition
        }
    }
}
