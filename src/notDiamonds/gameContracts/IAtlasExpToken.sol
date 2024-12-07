// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAtlasExpToken {
    function mint(address _to, uint256 _qty) external;

    function burn(address owner, uint256 _qty) external;

    function balanceOf(address account) external view returns (uint256);
}
