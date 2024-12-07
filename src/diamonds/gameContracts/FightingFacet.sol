// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibFighting} from "../libraries/LibFighting.sol";
import {LibERC721} from "../libraries/LibERC721.sol";
import {LibDataInterface} from "../libraries/LibDataInterface.sol";
import {LibLeveling} from "../libraries/LibLeveling.sol";
import {IArtefact} from "@/notDiamonds/gameContracts/IArtefact.sol";
import {IAtlasExpToken} from "@/notDiamonds/gameContracts/IAtlasExpToken.sol";

contract FightingFacet {
    modifier requireNFTFacet() {
        LibERC721.ERC721DiamondStorage storage dsNFT = LibERC721.diamondStorage();
        require(dsNFT.initialized, "NFT facet not found");
        _;
    }

    modifier requireDataInterface() {
        LibDataInterface.DataInterfaceDiamondStorage storage dsDataInterface = LibDataInterface.diamondStorage();
        require(dsDataInterface.initialized, "DataInterfaceFacet not found");
        _;
    }

    modifier requireInitialized() {
        LibFighting.FightingDiamondStorage storage dsFighting = LibFighting.diamondStorage();
        require(dsFighting.initialized, "facet not initialized");
        _;
    }

    event CommitMade(address indexed user, uint256 indexed petId, bytes32 commitHash);
    event ResultMade(address indexed user, uint256 indexed petId, bool outcome);
    event CommitCleared(address indexed user, uint256 indexed petId, bytes32 commitHash);

    function initialize(address artefactAddress_) external {
        LibDiamond.enforceIsContractOwner();
        LibFighting.FightingDiamondStorage storage dsFighting = LibFighting.diamondStorage();
        require(!dsFighting.initialized, "FightingFacet: facet instance has already been initialized");
        dsFighting.initialized = true;
        dsFighting._winningCap = 15;
        dsFighting._artefactAddress = artefactAddress_;
    }

    function setArtefactContract(address _address) external requireInitialized {
        LibDiamond.enforceIsContractOwner();
        LibFighting.FightingDiamondStorage storage dsFighting = LibFighting.diamondStorage();
        dsFighting._artefactAddress = _address;
    }

    function setWinningCap(uint256 _cap) external requireInitialized {
        LibDiamond.enforceIsContractOwner();
        LibFighting.FightingDiamondStorage storage dsFighting = LibFighting.diamondStorage();
        dsFighting._winningCap = _cap;
    }

    function commit(uint256 petId, bytes32 commitHash)
        external
        payable
        requireInitialized
        requireNFTFacet
        requireDataInterface
    {
        LibERC721.ERC721DiamondStorage storage dsERC721 = LibERC721.diamondStorage();
        LibFighting.FightingDiamondStorage storage dsFighting = LibFighting.diamondStorage();
        require(dsERC721._owners[petId] == msg.sender, "Not the owner of the pet");
        require(!dsFighting.usedCommitHashes[commitHash], "Hash already used");
        bytes32 _hash = keccak256(abi.encodePacked(commitHash, petId));
        dsFighting.usedCommitHashes[commitHash] = true;
        require(dsFighting.commits[msg.sender][petId].hash == bytes32(0), "Commit already made");
        uint256 commitFees = LibDataInterface._commitCost(petId, 50);
        require(msg.value >= commitFees, "Insufficient funds");
        dsFighting.commits[msg.sender][petId] = LibFighting.Commit(_hash, false);
        emit CommitMade(msg.sender, petId, _hash);
    }

    function reveal(uint256 petId, bytes32 nonce) external requireInitialized requireNFTFacet requireDataInterface {
        LibERC721.ERC721DiamondStorage storage dsERC721 = LibERC721.diamondStorage();
        LibFighting.FightingDiamondStorage storage dsFighting = LibFighting.diamondStorage();
        require(dsFighting._artefactAddress != address(0), "Artefact address not set");

        require(dsERC721._owners[petId] == msg.sender, "Not the owner of the pet");
        LibFighting.Commit storage _commit = dsFighting.commits[msg.sender][petId];
        require(!_commit.hasRevealed, "Already revealed");
        require(_commit.hash != bytes32(0), "No commit found to reveal");
        bytes32 revealedHash = keccak256(abi.encodePacked(keccak256(abi.encodePacked(nonce)), petId));
        require(revealedHash == _commit.hash, "Invalid nonce");
        (_commit.hasRevealed, _commit.hash) = (true, bytes32(0));
        uint256 _nonce = uint256(nonce) % 100000000;
        uint256 outcome = determineOutcome(petId + _nonce);
        if (outcome > dsFighting._winningCap) {
            uint256 rewards = (
                LibLeveling._rewardForLevel(petId)
                    * (100 + (IArtefact(dsFighting._artefactAddress).balanceOf(msg.sender) * 25))
            ) / 100;
            IAtlasExpToken(LibLeveling._getExpToken()).mint(msg.sender, rewards);
        }
        emit ResultMade(msg.sender, petId, outcome > dsFighting._winningCap);
    }

    function waitingForReveal(uint256 petId) external view requireNFTFacet returns (bool) {
        LibFighting.FightingDiamondStorage storage dsFighting = LibFighting.diamondStorage();
        return dsFighting.commits[msg.sender][petId].hash != bytes32(0);
    }

    function generateRandomHash(uint256 petId) external view requireNFTFacet returns (bytes32) {
        LibFighting.FightingDiamondStorage storage dsFighting = LibFighting.diamondStorage();
        bytes32 _hash = keccak256(abi.encodePacked(block.timestamp, petId, msg.sender));
        while (dsFighting.usedCommitHashes[_hash]) {
            _hash = keccak256(abi.encodePacked(_hash));
        }
        return _hash;
    }

    function clearCommit(uint256 petId) external requireNFTFacet {
        LibERC721.ERC721DiamondStorage storage dsERC721 = LibERC721.diamondStorage();
        LibFighting.FightingDiamondStorage storage dsFighting = LibFighting.diamondStorage();
        require(dsERC721._owners[petId] == msg.sender, "Not the owner of the pet");
        require(dsFighting.commits[msg.sender][petId].hash != bytes32(0), "No commit found");
        emit CommitCleared(msg.sender, petId, dsFighting.commits[msg.sender][petId].hash);
        dsFighting.commits[msg.sender][petId] = LibFighting.Commit(bytes32(0), false);
    }

    function determineOutcome(uint256 nonce) private view returns (uint256) {
        uint256 rand = uint256(keccak256(abi.encodePacked(block.number - 1, nonce)));
        return (rand % 100);
    }
}
