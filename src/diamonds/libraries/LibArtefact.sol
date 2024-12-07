// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Utils} from "@/notDiamonds/userType.sol";

library LibArtefact {
    struct ArtefactDiamondStorage {
        address _heroCaller;
    }

    // Returns the struct from a specified position in contract storage
    // ds is short for DiamondStorage
    function diamondStorage() internal pure returns (ArtefactDiamondStorage storage ds) {
        // Specifies a random position from a hash of a string
        bytes32 storagePosition = keccak256("diamond.standard.artefact.storage");

        // Set the position of our struct in contract storage
        assembly {
            ds.slot := storagePosition
        }
    }

    function _heroIsCaller() internal view returns (bool) {
        return msg.sender == LibArtefact.diamondStorage()._heroCaller;
    }
}
