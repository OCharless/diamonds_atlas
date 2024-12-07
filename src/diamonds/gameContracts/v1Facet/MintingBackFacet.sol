// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {IERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import {LibDiamond} from "../../libraries/LibDiamond.sol";
import {LibERC721} from "../../libraries/LibERC721.sol";
import {LibMintBack} from "../../libraries/LibMintBack.sol";
import {LibRefProgram} from "../../libraries/LibRefProgram.sol";
import {LibDataInterface} from "../../libraries/LibDataInterface.sol";

contract MintingBackFacet is Context {
    function OwnerDoMints(address[] memory _tos, uint256[] memory _amounts) external {
        LibDiamond.enforceIsContractOwner();
        LibERC721.ERC721DiamondStorage storage dsERC721 = LibERC721.diamondStorage();
        LibMintBack.MintBackDiamondStorage storage dsMintBack = LibMintBack.diamondStorage();
        require(_tos.length == _amounts.length, "Invalid input");
        for (uint256 i = 0; i < _tos.length; i++) {
            for (uint256 j = 0; j < _amounts[i]; j++) {
                uint256 newTokenId = dsERC721._seed + (dsERC721._totalSupply * 20);
                require(newTokenId < dsERC721._end, "Exceeds the limit");
                LibERC721._mint(_tos[i], newTokenId);
                dsERC721._totalSupply++;
            }
            dsMintBack.Done[_tos[i]] = true;
        }
    }

    function HaveMinted(address _to) external view returns (bool) {
        LibDiamond.enforceIsContractOwner();
        LibMintBack.MintBackDiamondStorage storage dsMintBack = LibMintBack.diamondStorage();
        return dsMintBack.Done[_to];
    }
}
