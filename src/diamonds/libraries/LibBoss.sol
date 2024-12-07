// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Utils} from "@/notDiamonds/userType.sol";

library LibBoss {
    struct BossDiamondStorage {
        uint256 _levelCap;
        bool _initialized;
    }

    // Returns the struct from a specified position in contract storage
    // ds is short for DiamondStorage
    function diamondStorage() internal pure returns (BossDiamondStorage storage ds) {
        // Specifies a random position from a hash of a string
        bytes32 storagePosition = keccak256("diamond.standard.boss.storage");

        // Set the position of our struct in contract storage
        assembly {
            ds.slot := storagePosition
        }
    }
}
