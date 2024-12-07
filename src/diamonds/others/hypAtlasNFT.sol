// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import {HypERC721} from "@HyperLane/token/HypERC721.sol";

contract hypAtlasNFT is HypERC721 {
    constructor(address _mailbox) HypERC721(_mailbox) {}

    receive() external payable {}
}
