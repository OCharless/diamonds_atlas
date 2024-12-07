// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibRefProgram} from "../libraries/LibRefProgram.sol";

contract PrevChainRefProgramSetterFacet {
    function initialize(address _address) public {
        LibRefProgram.RefProgramDiamondStorage storage dsRefProgram = LibRefProgram.diamondStorage();
        dsRefProgram._prevChainRefProgram = _address;
    }
}
