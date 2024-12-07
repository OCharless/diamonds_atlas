// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibERC20} from "../libraries/LibERC20.sol";
import {LibDataInterface} from "../libraries/LibDataInterface.sol";
import {IAtlasExpToken} from "@/notDiamonds/gameContracts/IAtlasExpToken.sol";

contract AtlasERC20Facet is Context, IERC20Upgradeable, IAtlasExpToken {
    function initialize(uint8 decimals_, string memory symbol_, string memory name_, address hero_) public {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        LibERC20.ERC20DiamondStorage storage dsERC20 = LibERC20.diamondStorage();
        require(!dsERC20.initialized, "NFTFacet: facet instance has already been initialized");
        LibERC20._mint(msg.sender, 1 ether * 1 ether);
        /*==================== ERC20DiamondStorage ====================*/
        dsERC20.initialized = true;
        dsERC20._name = name_;
        dsERC20._symbol = symbol_;
        dsERC20._decimals = decimals_;
        dsERC20._heroAddress = hero_;

        /*==================== DiamondStorage ====================*/
        ds.supportedInterfaces[0x5d1fb5f9] = true;
    }

    function name() external view returns (string memory) {
        return LibERC20.diamondStorage()._name;
    }

    function symbol() external view returns (string memory) {
        return LibERC20.diamondStorage()._symbol;
    }

    function decimals() external view returns (uint8) {
        return LibERC20.diamondStorage()._decimals;
    }

    function setHeroAddress(address hero_) external {
        require(LibDiamond.diamondStorage().contractOwner == _msgSender(), "Only owner can set hero address");
        LibERC20.diamondStorage()._heroAddress = hero_;
    }

    function mint(address to, uint256 amount) external override {
        require(_msgSender() == LibERC20.diamondStorage()._heroAddress, "only hero can mint");
        LibERC20._mint(to, amount);
    }

    function burn(address to, uint256 amount) external override {
        require(_msgSender() == LibERC20.diamondStorage()._heroAddress, "only hero can burn");
        LibERC20._burn(to, amount);
    }

    function balanceOf(address owner) external view override(IAtlasExpToken, IERC20Upgradeable) returns (uint256) {
        return LibERC20.diamondStorage()._balances[owner];
    }

    function balanceOfERC20(address owner) external view returns (uint256) {
        return LibERC20.diamondStorage()._balances[owner];
    }

    function totalSupply() external view returns (uint256) {
        return LibERC20.diamondStorage()._totalSupply;
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        address owner = _msgSender();
        require(owner != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        LibERC20.ERC20DiamondStorage storage dsERC20 = LibERC20.diamondStorage();
        uint256 ownerBalance = dsERC20._balances[owner];
        require(ownerBalance >= amount, "ERC20: transfer amount exceeds balance");

        unchecked {
            dsERC20._balances[owner] = ownerBalance - amount;
            // Overflow not possible: the sum of all balances is capped by totalSupply, and the sum is preserved by
            // decrementing then incrementing.
            dsERC20._balances[to] += amount;
        }

        emit Transfer(owner, to, amount);

        return true;
    }

    function transferFrom(address, address, uint256) external pure override returns (bool) {
        revert("Not implemented");
    }

    function approve(address, uint256) external pure override returns (bool) {
        revert("Not implemented");
    }

    function allowance(address, address) external pure returns (uint256) {
        revert("Not implemented");
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return type(IERC20Upgradeable).interfaceId == interfaceId;
    }
}
