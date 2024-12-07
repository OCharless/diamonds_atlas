// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {INFTDataInterface, Fees} from "../../notDiamonds/INFTDataInterface.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {AggregatorV2V3Interface} from "../interfaces/IAggregator.sol";
import {LibDataInterface} from "../libraries/LibDataInterface.sol";
import {Utils} from "../../notDiamonds/userType.sol";

contract DataInterfaceFacet {
    using Utils for uint256;

    function initialize() public {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        LibDataInterface.DataInterfaceDiamondStorage storage dsDataInterface = LibDataInterface.diamondStorage();
        require(!dsDataInterface.initialized, "DataInterface: facet instance has already been initialized");

        // ERC721DiamondStorage
        dsDataInterface.initialized = true;
        dsDataInterface._mintingFee = 0.00057 ether;
        dsDataInterface._fightFee = 0.0000355 ether;
        dsDataInterface._modulo = 50;

        // DiamondStorage
        ds.supportedInterfaces[0x80ac58cd] = true;
    }

    function getFees() external view returns (Fees memory) {
        return Fees(LibDataInterface.mintingFeesToEth(), LibDataInterface.fightingFeesToEth());
    }

    function ownerSetMintingFees(uint256 fees) external {
        LibDiamond.enforceIsContractOwner();
        LibDataInterface.DataInterfaceDiamondStorage storage ds = LibDataInterface.diamondStorage();
        ds._mintingFee = fees;
    }

    function ownerSetFightingFees(uint256 fees) external {
        LibDiamond.enforceIsContractOwner();
        LibDataInterface.DataInterfaceDiamondStorage storage ds = LibDataInterface.diamondStorage();
        ds._fightFee = fees;
    }

    function commitCost(uint256 petId, uint256 modulo) external view returns (uint256) {
        return LibDataInterface._commitCost(petId, modulo);
    }

    function setPriceFeed(uint8 _index, address _priceFeed) external {
        LibDiamond.enforceIsContractOwner();
        LibDataInterface.DataInterfaceDiamondStorage storage ds = LibDataInterface.diamondStorage();
        ds._priceFeeds[_index] = AggregatorV2V3Interface(_priceFeed);
    }

    function withdrawFees() external {
        LibDiamond.enforceIsContractOwner();
        (bool success,) = payable(LibDiamond.contractOwner()).call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }
}
