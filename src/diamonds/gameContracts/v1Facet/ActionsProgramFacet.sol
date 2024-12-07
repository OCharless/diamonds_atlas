// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import {LibDiamond} from "../../libraries/LibDiamond.sol";
import {LibRefProgram, UserActions} from "../../libraries/LibRefProgram.sol";

contract AtlasProtocolPointsFacet is Ownable {
    function initialize(address prevChainRefProgram_) external {
        LibDiamond.enforceIsContractOwner();
        LibRefProgram.RefProgramDiamondStorage storage dsRefProgram = LibRefProgram.diamondStorage();
        require(!dsRefProgram.initialized, "Already initialized");

        dsRefProgram.initialized = true;
        dsRefProgram._referred[0x000000000000000000000000000000000000dEaD] = true;
        dsRefProgram._refCodeToAddress[dsRefProgram._refVar] = 0x000000000000000000000000000000000000dEaD;
        dsRefProgram._addressToRefCode[0x000000000000000000000000000000000000dEaD] = "NOCODE";
        dsRefProgram._refVar = LibRefProgram.generateRandomRefVar();
        dsRefProgram._prevChainRefProgram = prevChainRefProgram_;
    }

    function addActionsToUsers(address[] calldata _address, uint256[] calldata mints, uint256[] calldata bridges)
        external
    {
        LibDiamond.enforceIsContractOwner();
        LibRefProgram.RefProgramDiamondStorage storage dsRefProgram = LibRefProgram.diamondStorage();
        require(_address.length == mints.length && _address.length == bridges.length, "Invalid input");
        require(_address.length <= 100, "provide less than 100 inputs");
        for (uint256 i = 0; i < _address.length; i++) {
            UserActions storage actions = dsRefProgram._userActions[_address[i]];
            actions.mints += mints[i];
            actions.bridges += bridges[i];
        }
    }

    function getUserActions(address _address) external view returns (uint256, uint256) {
        LibRefProgram.RefProgramDiamondStorage storage dsRefProgram = LibRefProgram.diamondStorage();

        UserActions memory actions = dsRefProgram._userActions[_address];
        return (actions.mints, actions.bridges);
    }

    function UserUpdated(address _address) external view returns (bool) {
        LibRefProgram.RefProgramDiamondStorage storage dsRefProgram = LibRefProgram.diamondStorage();

        return dsRefProgram._updated[_address];
    }

    function SetPrevChainRefProgram(address _address) external {
        LibDiamond.enforceIsContractOwner();
        LibRefProgram.RefProgramDiamondStorage storage dsRefProgram = LibRefProgram.diamondStorage();
        dsRefProgram._prevChainRefProgram = _address;
    }
}
