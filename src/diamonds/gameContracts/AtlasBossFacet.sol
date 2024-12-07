// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibFighting} from "../libraries/LibFighting.sol";
import {LibERC721} from "../libraries/LibERC721.sol";
import {LibDataInterface} from "../libraries/LibDataInterface.sol";
import {LibLeveling} from "../libraries/LibLeveling.sol";
import {LibBoss} from "../libraries/LibBoss.sol";
import {IArtefact} from "@/notDiamonds/gameContracts/IArtefact.sol";
import {IAtlasExpToken} from "@/notDiamonds/gameContracts/IAtlasExpToken.sol";

contract AtlasBossFacet {
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

    event BossFight(address indexed user, uint256 indexed petId);

    function initialize() external {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        LibBoss.BossDiamondStorage storage dsBoss = LibBoss.diamondStorage();

        /*==================== BossDiamondStorage ====================*/

        require(!dsBoss._initialized, "BossFacet: Facet instance has already been initialized");

        dsBoss._initialized = true;
        dsBoss._levelCap = 29;

        /*==================== DiamondStorage ====================*/

        ds.supportedInterfaces[0x80ac58cd] = true;
    }

    function fightBoss(uint256 petId) external payable requireNFTFacet requireDataInterface {
        LibERC721.ERC721DiamondStorage storage dsERC721 = LibERC721.diamondStorage();
        LibDataInterface.DataInterfaceDiamondStorage storage dsDataInterface = LibDataInterface.diamondStorage();
        LibFighting.FightingDiamondStorage storage dsFighting = LibFighting.diamondStorage();
        LibBoss.BossDiamondStorage storage dsBoss = LibBoss.diamondStorage();
        IArtefact artefact = IArtefact(dsFighting._artefactAddress);
        require(dsERC721._owners[petId] == msg.sender, "Not the owner of the hero");
        require(dsERC721._start < petId && dsERC721._end > petId, "Hero isn't from this world");
        require(petId % dsDataInterface._modulo > dsBoss._levelCap, "Hero is too weak");
        require(!artefact.alreadyMinted(msg.sender), "Boss fight already done");
        artefact.mintArtefact(msg.sender);
        emit BossFight(msg.sender, petId);
    }

    function setLevelCap(uint256 levelCap) external {
        LibDiamond.enforceIsContractOwner();
        LibBoss.BossDiamondStorage storage dsBoss = LibBoss.diamondStorage();
        dsBoss._levelCap = levelCap;
    }

    function getLevelCap() external view returns (uint256) {
        return LibBoss.diamondStorage()._levelCap;
    }
}
