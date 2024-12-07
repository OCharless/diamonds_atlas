// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC-20 standard as defined in the ERC.
 */
interface IArtefact {
    function balanceOf(address account) external view returns (uint256);
    function alreadyMinted(address account) external view returns (bool);
    function mintArtefact(address account) external payable;
}
