// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library LibERC721 {
    struct ERC721DiamondStorage {
        bool initialized;
        // Token name
        string _name;
        // Token symbol
        string _symbol;
        // Number of minted tokens
        uint256 _totalSupply;
        //Atlas params
        uint256 _start;
        uint256 _end;
        uint256 _seed;
        // all tokens for enumerable
        uint256[] _allTokens;
        // Mapping from token ID to owner address
        mapping(uint256 => address) _owners;
        mapping(uint256 => uint256) _ownedTokensIndex;
        mapping(address => mapping(uint256 => uint256)) _ownedTokens;
        mapping(uint256 => uint256) _allTokensIndex;
        mapping(address => bool) mintedYet;
        // Mapping owner address to token count
        mapping(address => uint256) _balances;
        // Mapping from owner to operator approvals
        mapping(address => mapping(address => bool)) _operatorApprovals;
    }

    // Declare the Transfer event
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    // Returns the struct from a specified position in contract storage
    // ds is short for DiamondStorage
    function diamondStorage() internal pure returns (ERC721DiamondStorage storage ds) {
        // Specifies a random position from a hash of a string
        bytes32 storagePosition = keccak256("diamond.standard.erc721.storage");

        // Set the position of our struct in contract storage
        assembly {
            ds.slot := storagePosition
        }
    }

    function _mint(address to, uint256 tokenId) internal {
        ERC721DiamondStorage storage ds = diamondStorage();
        require(to != address(0), "Mint to the zero address");
        require(ds._owners[tokenId] == address(0), "Token already minted");
        _beforeTokenTransfer(address(0), to, tokenId);
        unchecked {
            ds._balances[to] += 1;
        }
        ds._owners[tokenId] = to;
        emit Transfer(address(0), to, tokenId);
    }

    function _burn(uint256 tokenId) internal {
        ERC721DiamondStorage storage ds = diamondStorage();
        address owner = ds._owners[tokenId];
        require(owner != address(0), "Burn of nonexistent token");
        require(
            owner == msg.sender || ds._operatorApprovals[owner][msg.sender], "Burn caller is not owner nor approved"
        );
        _beforeTokenTransfer(owner, address(0), tokenId);
        ds._balances[owner] -= 1;
        delete ds._owners[tokenId];
        emit Transfer(owner, address(0), tokenId);
    }

    function _ownerOf(uint256 tokenId) internal view returns (address) {
        ERC721DiamondStorage storage ds = diamondStorage();
        address owner = ds._owners[tokenId];
        require(owner != address(0), "Owner query for nonexistent token");
        return owner;
    }

    function _balanceOf(address owner) internal view returns (uint256) {
        ERC721DiamondStorage storage ds = diamondStorage();
        return ds._balances[owner];
    }

    function _tokenOfOwnerByIndex(address owner, uint256 index) internal view returns (uint256) {
        ERC721DiamondStorage storage ds = diamondStorage();
        require(index < ds._balances[owner], "ERC721Enumerable: owner index out of bounds");
        return ds._ownedTokens[owner][index];
    }

    function _tokensOfOwner(address owner) internal view returns (uint256[] memory) {
        ERC721DiamondStorage storage ds = diamondStorage();
        uint256 tokenCount = ds._balances[owner];
        uint256[] memory tokenIds = new uint256[](tokenCount);
        for (uint256 i = 0; i < tokenCount; i++) {
            tokenIds[i] = ds._ownedTokens[owner][i];
        }
        return tokenIds;
    }

    function __removeTokenFromOwnerEnumeration(address from, uint256 tokenId) private {
        ERC721DiamondStorage storage ds = diamondStorage();

        uint256 lastTokenIndex = ds._balances[from] - 1;
        uint256 tokenIndex = ds._ownedTokensIndex[tokenId];
        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = ds._ownedTokens[from][lastTokenIndex];

            ds._ownedTokens[from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            ds._ownedTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index
        }

        // This also deletes the contents at the last position of the array
        delete ds._ownedTokensIndex[tokenId];
        delete ds._ownedTokens[from][lastTokenIndex];
    }

    function __removeTokenFromAllTokensEnumeration(uint256 tokenId) private {
        ERC721DiamondStorage storage ds = diamondStorage();

        uint256 lastTokenIndex = ds._allTokens.length - 1;
        uint256 tokenIndex = ds._allTokensIndex[tokenId];
        uint256 lastTokenId = ds._allTokens[lastTokenIndex];

        ds._allTokens[tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
        ds._allTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index

        delete ds._allTokensIndex[tokenId];
        ds._allTokens.pop();
    }

    function __addTokenToAllTokensEnumeration(uint256 tokenId) private {
        ERC721DiamondStorage storage ds = diamondStorage();
        ds._allTokensIndex[tokenId] = ds._allTokens.length;
        ds._allTokens.push(tokenId);
    }

    function __addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        ERC721DiamondStorage storage ds = diamondStorage();
        uint256 length = ds._balances[to];
        ds._ownedTokens[to][length] = tokenId;
        ds._ownedTokensIndex[tokenId] = length;
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) private {
        if (from == address(0)) {
            __addTokenToAllTokensEnumeration(tokenId);
        } else if (from != to) {
            __removeTokenFromOwnerEnumeration(from, tokenId);
        }
        if (to == address(0)) {
            __removeTokenFromAllTokensEnumeration(tokenId);
        } else if (to != from) {
            __addTokenToOwnerEnumeration(to, tokenId);
        }
    }
}
