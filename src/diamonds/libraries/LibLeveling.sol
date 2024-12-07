// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibDataInterface} from "./LibDataInterface.sol";

library LibLeveling {
    using LibDataInterface for uint256;

    struct LevelingDiamondStorage {
        bool initialized;
        uint256[50] lvlToExp;
        uint256[50] lvlToRew;
        address _expToken;
    }

    // Returns the struct from a specified position in contract storage
    // ds is short for DiamondStorage
    function diamondStorage() internal pure returns (LevelingDiamondStorage storage ds) {
        // Specifies a random position from a hash of a string
        bytes32 storagePosition = keccak256("diamond.standard.leveling.storage");

        // Set the position of our struct in contract storage
        assembly {
            ds.slot := storagePosition
        }
    }

    function _rewardForLevel(uint256 tokenId) internal view returns (uint256) {
        LibLeveling.LevelingDiamondStorage storage dsLeveling = LibLeveling.diamondStorage();
        LibDataInterface.DataInterfaceDiamondStorage storage dsDataInterface = LibDataInterface.diamondStorage();
        return (dsLeveling.lvlToRew[tokenId % dsDataInterface._modulo]) * 1 ether;
    }

    function _expForLevel(uint256 tokenId) internal view returns (uint256) {
        LibLeveling.LevelingDiamondStorage storage dsLeveling = LibLeveling.diamondStorage();
        LibDataInterface.DataInterfaceDiamondStorage storage dsDataInterface = LibDataInterface.diamondStorage();
        return dsLeveling.lvlToExp[tokenId % dsDataInterface._modulo] * 1 ether;
    }

    function _getExpToken() internal view returns (address) {
        return LibLeveling.diamondStorage()._expToken;
    }
}
