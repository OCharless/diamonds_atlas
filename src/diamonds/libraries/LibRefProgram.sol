// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Utils} from "@/notDiamonds/userType.sol";
import {AggregatorV2V3Interface} from "@/diamonds/interfaces/IAggregator.sol";
import {IAtlasProtocolPoints} from "@/diamonds/interfaces/IRef.sol";

struct UserActions {
    uint256 mints;
    uint256 bridges;
}

library LibRefProgram {
    struct RefProgramDiamondStorage {
        bool initialized;
        bool _reqreferral;
        string _refVar;
        address _prevChainRefProgram;
        mapping(address => bool) _updated;
        mapping(address => bool) _referred;
        mapping(address => address) _isReferredBy;
        mapping(string => address[]) _referrees;
        mapping(string => address) _refCodeToAddress;
        mapping(address => string) _addressToRefCode;
        mapping(address => uint256) _refCodeToYield;
        mapping(address => UserActions) _userActions;
    }

    // Returns the struct from a specified position in contract storage
    // ds is short for DiamondStorage
    function diamondStorage() internal pure returns (RefProgramDiamondStorage storage ds) {
        // Specifies a random position from a hash of a string
        bytes32 storagePosition = keccak256("diamond.standard.refProgram.storage");

        // Set the position of our struct in contract storage
        assembly {
            ds.slot := storagePosition
        }
    }

    function generateRandomRefVar() internal view returns (string memory) {
        RefProgramDiamondStorage storage ds = diamondStorage();
        string memory newRefVar;
        bytes memory randomString;
        uint256 k = 0;
        do {
            randomString = new bytes(5);
            for (uint256 i = 0; i < 5; i++) {
                randomString[i] = bytes1(
                    uint8(
                        (
                            uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender, i + k)))
                                % 26
                        ) + 65
                    )
                );
            }
            newRefVar = string(randomString);
            k++;
        } while (ds._refCodeToAddress[newRefVar] != address(0));

        return newRefVar;
    }

    function addUserMint(address _address) internal {
        RefProgramDiamondStorage storage ds = diamondStorage();
        UserActions storage actions = ds._userActions[_address];
        checkUserIsUpdated(_address);
        actions.mints += 1;
    }

    function addUserBridge(address _address) internal {
        RefProgramDiamondStorage storage ds = diamondStorage();
        UserActions storage actions = ds._userActions[_address];
        checkUserIsUpdated(_address);
        actions.bridges += 1;
    }

    function checkUserIsUpdated(address _address) internal {
        RefProgramDiamondStorage storage ds = diamondStorage();
        require(ds._prevChainRefProgram != address(0), "Ref program not set");
        if (ds._updated[_address] == false) {
            ds._updated[_address] = true;
            (uint256 _mints, uint256 _bridges) = IAtlasProtocolPoints(ds._prevChainRefProgram).getUserActions(_address);
            UserActions storage actions = ds._userActions[_address];
            actions.mints = _mints;
            actions.bridges = _bridges;
        }
    }
}
