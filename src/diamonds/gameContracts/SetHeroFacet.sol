// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibERC20} from "../libraries/LibERC20.sol";

contract SetHeroFacet is Context {
    function setHeroAddress(address hero_) external {
        LibDiamond.enforceIsContractOwner();
        LibERC20.diamondStorage()._heroAddress = hero_;
    }

    function getHeroAddress() external view returns (address) {
        return LibERC20.diamondStorage()._heroAddress;
    }

    function initialize(address heroCaller_) public {
        LibERC20.ERC20DiamondStorage storage dsERC20 = LibERC20.diamondStorage();
        dsERC20._heroAddress = heroCaller_;
    }
}
