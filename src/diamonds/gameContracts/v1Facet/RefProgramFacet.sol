// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import {LibDiamond} from "../../libraries/LibDiamond.sol";
import {LibRefProgram, UserActions} from "../../libraries/LibRefProgram.sol";

contract RefProgramFacet is Ownable {
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

    function setReferral(string memory _code) external {
        LibRefProgram.RefProgramDiamondStorage storage dsRefProgram = LibRefProgram.diamondStorage();
        require(dsRefProgram._referred[_msgSender()] == false, "You have already been referred");
        require(validRefCode(_code), "Invalid referral code");
        dsRefProgram._referred[_msgSender()] = true;
        dsRefProgram._isReferredBy[_msgSender()] = dsRefProgram._refCodeToAddress[_code];
        dsRefProgram._referrees[_code].push(_msgSender());
        dsRefProgram._refCodeToAddress[dsRefProgram._refVar] = _msgSender();
        dsRefProgram._addressToRefCode[_msgSender()] = dsRefProgram._refVar;
        dsRefProgram._refVar = LibRefProgram.generateRandomRefVar();
    }

    function validRefCode(string memory _code) public view returns (bool) {
        LibRefProgram.RefProgramDiamondStorage storage dsRefProgram = LibRefProgram.diamondStorage();

        return dsRefProgram._refCodeToAddress[_code] != address(0);
    }

    function getReferrees() external view returns (address[] memory) {
        LibRefProgram.RefProgramDiamondStorage storage dsRefProgram = LibRefProgram.diamondStorage();

        return dsRefProgram._referrees[dsRefProgram._addressToRefCode[_msgSender()]];
    }

    function getReferrees(address _address) external view onlyOwner returns (address[] memory) {
        LibRefProgram.RefProgramDiamondStorage storage dsRefProgram = LibRefProgram.diamondStorage();

        return dsRefProgram._referrees[dsRefProgram._addressToRefCode[_address]];
    }

    function isReferred(address _address) external view returns (bool) {
        LibRefProgram.RefProgramDiamondStorage storage dsRefProgram = LibRefProgram.diamondStorage();

        return dsRefProgram._referred[_address];
    }

    function getReferrer(address _address) external view returns (address) {
        LibRefProgram.RefProgramDiamondStorage storage dsRefProgram = LibRefProgram.diamondStorage();

        return dsRefProgram._isReferredBy[_address];
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

    function addRefcodesToUsers(address[] calldata _address, string[] calldata refCodes) external {
        LibDiamond.enforceIsContractOwner();
        LibRefProgram.RefProgramDiamondStorage storage dsRefProgram = LibRefProgram.diamondStorage();
        require(_address.length == refCodes.length, "Invalid input");
        require(_address.length <= 100, "provide less than 100 inputs");
        for (uint256 i = 0; i < _address.length; i++) {
            dsRefProgram._referred[_address[i]] = true;
            dsRefProgram._addressToRefCode[_address[i]] = refCodes[i];
            dsRefProgram._refCodeToAddress[refCodes[i]] = _address[i];
        }
        for (uint256 i = 0; i < _address.length; i++) {
            dsRefProgram._referrees[refCodes[i]].push(_address[i]);
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
