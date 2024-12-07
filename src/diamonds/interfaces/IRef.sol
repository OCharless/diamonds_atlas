// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IAtlasProtocolPoints {
    function getUserActions(address _address) external view returns (uint256, uint256);
}
