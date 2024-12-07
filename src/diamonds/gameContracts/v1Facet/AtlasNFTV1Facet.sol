// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {IERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import {LibDiamond} from "../../libraries/LibDiamond.sol";
import {LibERC721} from "../../libraries/LibERC721.sol";
import {LibRefProgram} from "../../libraries/LibRefProgram.sol";
import {LibDataInterface} from "../../libraries/LibDataInterface.sol";

contract AtlasNFTFacetV1 is Context, IERC721Upgradeable {
    modifier enter(uint256 additionalFees) {
        LibDataInterface.DataInterfaceDiamondStorage memory dsData = LibDataInterface.diamondStorage();
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        require(dsData.initialized, "DataInterfaceFacet Not initialized");
        require(msg.value == LibDataInterface.mintingFeesToEth() + additionalFees, "fees not paid");
        require(!ds.locked, "Contract is locked");
        ds.locked = true;
        _;
        ds.locked = false;
    }

    function initialize(uint256 start_, uint256 end_, uint8 seed_, string memory symbol_, string memory name_) public {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        LibERC721.ERC721DiamondStorage storage dsERC721 = LibERC721.diamondStorage();

        require(!dsERC721.initialized, "NFTFacet: facet instance has already been initialized");

        /*==================== ERC721DiamondStorage ====================*/
        dsERC721.initialized = true;
        dsERC721._name = name_;
        dsERC721._symbol = symbol_;
        dsERC721._start = start_;
        dsERC721._end = end_;
        dsERC721._seed = seed_;

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
        return LibERC721.diamondStorage()._allTokens.length;
    }

    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256) {
        return LibERC721._tokenOfOwnerByIndex(owner, index);
    }

    function tokensOfOwner(address owner) external view returns (uint256[] memory) {
        return LibERC721._tokensOfOwner(owner);
    }

    function mint() external payable enter(0) {
        LibERC721.ERC721DiamondStorage storage dsERC721 = LibERC721.diamondStorage();
        LibRefProgram.RefProgramDiamondStorage storage dsRefProgram = LibRefProgram.diamondStorage();
        uint256 newTokenId = dsERC721._seed + (dsERC721._totalSupply * 20);
        require(dsRefProgram._referred[_msgSender()] || !dsRefProgram._reqreferral, "You need to be referred to mint");
        require(newTokenId < dsERC721._end, "Exceeds the limit");
        LibERC721._mint(_msgSender(), newTokenId);
        dsERC721._totalSupply++;
        LibRefProgram.addUserMint(_msgSender());
    }

    function OwnerDoMints(address[] memory _tos, uint256[] memory _amounts) external {
        LibDiamond.enforceIsContractOwner();
        LibERC721.ERC721DiamondStorage storage dsERC721 = LibERC721.diamondStorage();
        require(_tos.length == _amounts.length, "Invalid input");
        for (uint256 i = 0; i < _tos.length; i++) {
            for (uint256 j = 0; j < _amounts[i]; j++) {
                uint256 newTokenId = dsERC721._seed + (dsERC721._totalSupply * 20);
                require(newTokenId < dsERC721._end, "Exceeds the limit");
                LibERC721._mint(_tos[i], newTokenId);
                dsERC721._totalSupply++;
            }
        }
    }

    function burn(uint256 tokenId) external {
        LibERC721._burn(tokenId);
    }

    function balanceOf(address owner) external view override returns (uint256) {
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
        return type(IERC721Upgradeable).interfaceId == interfaceId || interfaceId == this.mint.selector;
    }
}
