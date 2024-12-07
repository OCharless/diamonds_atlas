// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Utils} from "@/notDiamonds/userType.sol";
import {AggregatorV2V3Interface} from "@/diamonds/interfaces/IAggregator.sol";

library LibDataInterface {
    struct DataInterfaceDiamondStorage {
        bool initialized;
        uint256 _mintingFee;
        uint256 _fightFee;
        uint8 _modulo;
        AggregatorV2V3Interface[3] _priceFeeds;
    }

    // Returns the struct from a specified position in contract storage
    // ds is short for DiamondStorage
    function diamondStorage() internal pure returns (DataInterfaceDiamondStorage storage ds) {
        // Specifies a random position from a hash of a string
        bytes32 storagePosition = keccak256("diamond.standard.dataInterface.storage");

        // Set the position of our struct in contract storage
        assembly {
            ds.slot := storagePosition
        }
    }

    function _commitCost(uint256 petId, uint256 modulo) internal view returns (uint256) {
        uint256 _fightFees = fightingFeesToEth();
        return Utils.calculateFee(_fightFees, petId, modulo);
    }

    function mintingFeesToEth() internal view returns (uint256) {
        LibDataInterface.DataInterfaceDiamondStorage storage ds = LibDataInterface.diamondStorage();
        uint256 _fees = ds._mintingFee;
        for (uint8 i = 0; i < ds._priceFeeds.length; i++) {
            if (address(ds._priceFeeds[i]) != address(0)) {
                (, int256 _price,,,) = ds._priceFeeds[i].latestRoundData();
                if (i == 0) _fees = ((_fees * 1 ether) / uint256(_price));
                if (i == 1) _fees = ((_fees * uint256(_price)) / 1 ether);
            }
        }
        return _fees;
    }

    function fightingFeesToEth() internal view returns (uint256) {
        LibDataInterface.DataInterfaceDiamondStorage storage ds = LibDataInterface.diamondStorage();
        uint256 _fees = ds._fightFee;
        for (uint8 i = 0; i < ds._priceFeeds.length; i++) {
            if (address(ds._priceFeeds[i]) != address(0)) {
                (, int256 _price,,,) = ds._priceFeeds[i].latestRoundData();
                if (i == 0) _fees = ((_fees * 1 ether) / uint256(_price));
                if (i == 1) _fees = ((_fees * uint256(_price)) / 1 ether);
            }
        }
        return _fees;
    }
}
