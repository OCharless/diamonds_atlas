// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./userType.sol";

struct Fees {
    uint256 mintingFees;
    uint256 fightFee;
}

interface INFTDataInterface {
    function getFees() external view returns (Fees memory);

    function commitCost(uint256 petId, uint256 modulo) external view returns (uint256);
}
