// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {IERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibERC721} from "../libraries/LibERC721.sol";
import {LibDataInterface} from "../libraries/LibDataInterface.sol";
import {LibArtefact} from "../libraries/LibArtefact.sol";
import {IArtefact} from "@/notDiamonds/gameContracts/IArtefact.sol";

contract AtlasArtefactFacet is Context, IERC721Upgradeable, IArtefact {
    function initialize(uint8 seed_, string memory symbol_, string memory name_, address heroCaller_) public {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        LibERC721.ERC721DiamondStorage storage dsERC721 = LibERC721.diamondStorage();
        LibDataInterface.DataInterfaceDiamondStorage storage dsDataInterface = LibDataInterface.diamondStorage();
        LibArtefact.ArtefactDiamondStorage storage dsArtefact = LibArtefact.diamondStorage();
        require(!dsERC721.initialized, "NFTFacet: facet instance has already been initialized");
        require(dsDataInterface.initialized, "NFTFacet: Data interface facet instance should be initialized before");

        /*==================== ERC721DiamondStorage ====================*/
        dsERC721.initialized = true;
        dsERC721._name = name_;
        dsERC721._symbol = symbol_;
        dsERC721._start = 0;
        dsERC721._end = 100_000;
        dsERC721._seed = seed_;

        /*==================== ArtefactDiamondStorage ====================*/

        dsArtefact._heroCaller = heroCaller_;

        /*==================== DataInterfaceDiamondStorage ====================*/

        dsDataInterface._modulo = 10;

        /*==================== DiamondStorage ====================*/
        ds.supportedInterfaces[0x689078e4] = true;
    }

    function name() external view returns (string memory) {
        return LibERC721.diamondStorage()._name;
    }

    function symbol() external view returns (string memory) {
        return LibERC721.diamondStorage()._symbol;
    }

    function totalSupply() external view returns (uint256) {
        return LibERC721.diamondStorage()._totalSupply;
    }

    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256) {
        return LibERC721._tokenOfOwnerByIndex(owner, index);
    }

    function tokensOfOwner(address owner) external view returns (uint256[] memory) {
        return LibERC721._tokensOfOwner(owner);
    }

    function alreadyMinted(address owner) external view returns (bool) {
        return LibERC721.diamondStorage().mintedYet[owner];
    }

    function mintArtefact(address account) external payable override {
        LibERC721.ERC721DiamondStorage storage dsERC721 = LibERC721.diamondStorage();
        require(!dsERC721.mintedYet[account], "User has minted");

        LibDataInterface.DataInterfaceDiamondStorage storage dsDataInterface = LibDataInterface.diamondStorage();
        require(LibArtefact.diamondStorage()._heroCaller == _msgSender(), "Only hero can mint");

        uint256 newTokenId = dsERC721._seed + dsERC721._start + (dsERC721._totalSupply * dsDataInterface._modulo);
        require(newTokenId < dsERC721._end, "Exceeds the limit");
        LibERC721._mint(account, newTokenId);
        dsERC721._totalSupply++;
        dsERC721.mintedYet[account] = true;
    }

    function burn(uint256 tokenId) external {
        LibERC721._burn(tokenId);
    }

    function balanceOf(address owner) external view override(IArtefact, IERC721Upgradeable) returns (uint256) {
        return LibERC721.diamondStorage()._balances[owner];
    }

    function ownerOf(uint256 tokenId) external view override returns (address) {
        return LibERC721.diamondStorage()._owners[tokenId];
    }

    function safeTransferFrom(address, address, uint256, bytes calldata) external pure override {
        revert("Not implemented");
    }

    function safeTransferFrom(address, address, uint256) external pure override {
        revert("Not implemented");
    }

    function transferFrom(address, address, uint256) external pure override {
        revert("Not implemented");
    }

    function approve(address, uint256) external pure override {
        revert("Not implemented");
    }

    function setApprovalForAll(address, bool) external pure override {
        revert("Not implemented");
    }

    function getApproved(uint256) external pure override returns (address) {
        revert("Not implemented");
    }

    function isApprovedForAll(address, address) external pure override returns (bool) {
        revert("Not implemented");
    }

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return type(IERC721Upgradeable).interfaceId == interfaceId || type(IArtefact).interfaceId == interfaceId
            || interfaceId == this.mintArtefact.selector;
    }
}
