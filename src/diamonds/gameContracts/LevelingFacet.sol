// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAtlasExpToken} from "@/notDiamonds/gameContracts/IAtlasExpToken.sol";
import {hypAtlasNFT} from "@/diamonds/others/hypAtlasNFT.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {IERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibDataInterface} from "../libraries/LibDataInterface.sol";
import {LibLeveling} from "../libraries/LibLeveling.sol";
import {LibERC721} from "../libraries/LibERC721.sol";

contract LevelingFacet is Context {
    event LeveledUp(uint256 newLevel);
    event LeveledDown(uint256 previousLevel, uint256 newLevel);

    modifier tokenOwned(uint256 tokenId) {
        require(LibERC721._ownerOf(tokenId) == msg.sender, "ERC721: caller is not owner nor approved");
        _;
    }

    modifier requireFacets() {
        LibERC721.ERC721DiamondStorage storage dsNFT = LibERC721.diamondStorage();
        require(dsNFT.initialized, "NFT facet not found");
        LibDataInterface.DataInterfaceDiamondStorage storage dsDataInterface = LibDataInterface.diamondStorage();
        require(dsDataInterface.initialized, "DataInterfaceFacet not initialized");
        _;
    }

    function initialize(uint256[] memory lvlToExp_, uint256[] memory lvlToRew_) public {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        LibLeveling.LevelingDiamondStorage storage dsLeveling = LibLeveling.diamondStorage();

        require(!dsLeveling.initialized, "LevelingFacet: Facet instance has already been initialized");

        dsLeveling.initialized = true;
        for (uint256 i = 0; i < lvlToExp_.length; i++) {
            dsLeveling.lvlToExp[i] = lvlToExp_[i];
        }
        for (uint256 i = 0; i < lvlToRew_.length; i++) {
            dsLeveling.lvlToRew[i] = lvlToRew_[i];
        }

        ds.supportedInterfaces[0x80ac58cd] = true;
    }

    function setLvlToExp(uint256[] memory _lvlToExp) external {
        LibDiamond.enforceIsContractOwner();
        LibLeveling.LevelingDiamondStorage storage dsLeveling = LibLeveling.diamondStorage();
        for (uint256 i = 0; i < _lvlToExp.length; i++) {
            dsLeveling.lvlToExp[i] = _lvlToExp[i];
        }
    }

    function setLvlToRew(uint256[] memory _lvlToRew) external {
        LibDiamond.enforceIsContractOwner();
        LibLeveling.LevelingDiamondStorage storage dsLeveling = LibLeveling.diamondStorage();
        for (uint256 i = 0; i < _lvlToRew.length; i++) {
            dsLeveling.lvlToRew[i] = _lvlToRew[i];
        }
    }

    function setExpToken(address _address) external {
        LibDiamond.enforceIsContractOwner();
        LibLeveling.LevelingDiamondStorage storage dsLeveling = LibLeveling.diamondStorage();
        dsLeveling._expToken = _address;
    }

    function levelUp(uint256 tokenId) external requireFacets tokenOwned(tokenId) {
        LibDataInterface.DataInterfaceDiamondStorage storage dsDataInterface = LibDataInterface.diamondStorage();
        IAtlasExpToken expToken = IAtlasExpToken(LibLeveling._getExpToken());
        uint256 modulo = dsDataInterface._modulo;
        uint256 amount = expForLevel(tokenId % modulo);
        require(expToken.balanceOf(msg.sender) >= amount, "Not enough exp");
        require(tokenId % modulo < modulo - 1, "Can't level up past max level");

        LibERC721._burn(tokenId);
        expToken.burn(msg.sender, amount);
        uint256 _id = tokenId + 1;
        LibERC721._mint(msg.sender, _id);
        emit LeveledUp(_id);
    }

    function levelDown(uint256 tokenId) external requireFacets tokenOwned(tokenId) {
        LibDataInterface.DataInterfaceDiamondStorage storage dsDataInterface = LibDataInterface.diamondStorage();
        require(tokenId % dsDataInterface._modulo > 3, "Can't level down past 3");
        LibERC721._burn(tokenId);
        uint256 _id = tokenId - 3;
        LibERC721._mint(_msgSender(), _id);
        emit LeveledDown(tokenId, _id);
    }

    function expForLevel(uint256 tokenId) public view requireFacets returns (uint256) {
        return LibLeveling._expForLevel(tokenId);
    }

    function rewardForLevel(uint256 tokenId) public view requireFacets returns (uint256) {
        return LibLeveling._rewardForLevel(tokenId);
    }

    function _toDecimals(uint256 _amount) private pure returns (uint256) {
        return _amount * 1 ether;
    }
}
