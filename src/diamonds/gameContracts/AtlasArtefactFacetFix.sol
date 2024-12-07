// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {LibERC721} from "../libraries/LibERC721.sol";
import {LibDataInterface} from "../libraries/LibDataInterface.sol";
import {LibArtefact} from "../libraries/LibArtefact.sol";
import {IArtefact} from "@/notDiamonds/gameContracts/IArtefact.sol";

contract AtlasArtefactFacetFix is Context, IArtefact {
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

    function balanceOf(address account) external view override returns (uint256) {}
    function alreadyMinted(address account) external view override returns (bool) {}
}
