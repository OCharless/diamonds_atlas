// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/**
 * \
 * Authors: Timo Neumann <timo@fyde.fi>
 * EIP-2535 Diamonds: https://eips.ethereum.org/EIPS/eip-2535
 * Helper functions for the translation from the jest tests in the original repo
 * to solidity tests.
 * /*****************************************************************************
 */
import {Test, console} from "forge-std/Test.sol";
import {strings} from "solidity-stringutils/strings.sol";
import {IDiamond} from "../../src/diamonds/interfaces/IDiamond.sol";
import {IDiamondLoupe} from "../../src/diamonds/interfaces/IDiamondLoupe.sol";

abstract contract HelperContract is IDiamond, IDiamondLoupe, Test {
    using strings for *;

    // return array of function selectors for given facet name
    function generateSelectors(string memory _facetName) internal returns (bytes4[] memory selectors) {
        //get string of contract methods
        string[] memory cmd = new string[](4);
        cmd[0] = "forge";
        cmd[1] = "inspect";
        cmd[2] = _facetName;
        cmd[3] = "methods";
        bytes memory res = vm.ffi(cmd);
        string memory st = string(res);

        // extract function signatures and take first 4 bytes of keccak
        strings.slice memory s = st.toSlice();

        // Skip TRACE lines if any
        strings.slice memory nl = "\n".toSlice();
        strings.slice memory trace = "TRACE".toSlice();
        while (s.contains(trace)) {
            s.split(nl);
        }

        strings.slice memory colon = ":".toSlice();
        // strings.slice memory comma = ",".toSlice();
        strings.slice memory dbquote = '"'.toSlice();
        selectors = new bytes4[]((s.count(colon)));

        for (uint256 i = 0; i < selectors.length; i++) {
            s.split(dbquote); // advance to next doublequote
            // split at colon, extract string up to next doublequote for methodname
            strings.slice memory method = s.split(colon).until(dbquote);
            selectors[i] = bytes4(method.keccak());
            // strings.slice memory selectr = s.split(comma).until(dbquote); // advance s to the next comma
        }
        return selectors;
    }

    // helper to remove index from bytes4[] array
    function removeElement(uint256 index, bytes4[] memory array) public pure returns (bytes4[] memory) {
        bytes4[] memory newarray = new bytes4[](array.length - 1);
        uint256 j = 0;
        for (uint256 i = 0; i < array.length; i++) {
            if (i != index) {
                newarray[j] = array[i];
                j += 1;
            }
        }
        return newarray;
    }

    // helper to remove value from bytes4[] array
    function removeElement(bytes4 el, bytes4[] memory array) public pure returns (bytes4[] memory) {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == el) {
                return removeElement(i, array);
            }
        }
        return array;
    }

    function containsElement(bytes4[] memory array, bytes4 el) public pure returns (bool) {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == el) {
                return true;
            }
        }

        return false;
    }

    function containsElement(address[] memory array, address el) public pure returns (bool) {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == el) {
                return true;
            }
        }

        return false;
    }

    function sameMembers(bytes4[] memory array1, bytes4[] memory array2) public pure returns (bool) {
        if (array1.length != array2.length) {
            return false;
        }
        for (uint256 i = 0; i < array1.length; i++) {
            if (containsElement(array1, array2[i])) {
                return true;
            }
        }

        return false;
    }

    function getAllSelectors(address diamondAddress) public view returns (bytes4[] memory) {
        Facet[] memory facetList = IDiamondLoupe(diamondAddress).facets();

        uint256 len = 0;
        for (uint256 i = 0; i < facetList.length; i++) {
            len += facetList[i].functionSelectors.length;
        }

        uint256 pos = 0;
        bytes4[] memory selectors = new bytes4[](len);
        for (uint256 i = 0; i < facetList.length; i++) {
            for (uint256 j = 0; j < facetList[i].functionSelectors.length; j++) {
                selectors[pos] = facetList[i].functionSelectors[j];
                pos += 1;
            }
        }
        return selectors;
    }

    function _buildLvlArrays() public pure returns (uint256[] memory lvlToExp, uint256[] memory lvlToRew) {
        lvlToExp = new uint256[](50);
        lvlToRew = new uint256[](50);

        lvlToExp[0] = 13;
        lvlToExp[1] = 16;
        lvlToExp[2] = 21;
        lvlToExp[3] = 28;
        lvlToExp[4] = 37;
        lvlToExp[5] = 48;
        lvlToExp[6] = 62;
        lvlToExp[7] = 81;
        lvlToExp[8] = 106;
        lvlToExp[9] = 137;
        lvlToExp[10] = 179;
        lvlToExp[11] = 232;
        lvlToExp[12] = 302;
        lvlToExp[13] = 393;
        lvlToExp[14] = 511;
        lvlToExp[15] = 665;
        lvlToExp[16] = 865;
        lvlToExp[17] = 1124;
        lvlToExp[18] = 1461;
        lvlToExp[19] = 1900;
        lvlToExp[20] = 2470;
        lvlToExp[21] = 3211;
        lvlToExp[22] = 4175;
        lvlToExp[23] = 5428;
        lvlToExp[24] = 7056;
        lvlToExp[25] = 9173;
        lvlToExp[26] = 11925;
        lvlToExp[27] = 15502;
        lvlToExp[28] = 20153;
        lvlToExp[29] = 26200;
        lvlToExp[30] = 34059;
        lvlToExp[31] = 44277;
        lvlToExp[32] = 57561;
        lvlToExp[33] = 74829;
        lvlToExp[34] = 97278;
        lvlToExp[35] = 126462;
        lvlToExp[36] = 164401;
        lvlToExp[37] = 213721;
        lvlToExp[38] = 277837;
        lvlToExp[39] = 361189;
        lvlToExp[40] = 469545;
        lvlToExp[41] = 610409;
        lvlToExp[42] = 793531;
        lvlToExp[43] = 1031590;
        lvlToExp[44] = 1341070;
        lvlToExp[45] = 1743390;
        lvlToExp[46] = 2266410;
        lvlToExp[47] = 2946330;
        lvlToExp[48] = 3830220;
        lvlToExp[49] = 4979290;

        lvlToRew[0] = 12;
        lvlToRew[1] = 14;
        lvlToRew[2] = 17;
        lvlToRew[3] = 20;
        lvlToRew[4] = 24;
        lvlToRew[5] = 29;
        lvlToRew[6] = 35;
        lvlToRew[7] = 42;
        lvlToRew[8] = 51;
        lvlToRew[9] = 62;
        lvlToRew[10] = 74;
        lvlToRew[11] = 89;
        lvlToRew[12] = 107;
        lvlToRew[13] = 128;
        lvlToRew[14] = 153;
        lvlToRew[15] = 185;
        lvlToRew[16] = 222;
        lvlToRew[17] = 266;
        lvlToRew[18] = 319;
        lvlToRew[19] = 383;
        lvlToRew[20] = 460;
        lvlToRew[21] = 552;
        lvlToRew[22] = 662;
        lvlToRew[23] = 794;
        lvlToRew[24] = 953;
        lvlToRew[25] = 1144;
        lvlToRew[26] = 1373;
        lvlToRew[27] = 1648;
        lvlToRew[28] = 1978;
        lvlToRew[29] = 2373;
        lvlToRew[30] = 2848;
        lvlToRew[31] = 3418;
        lvlToRew[32] = 4101;
        lvlToRew[33] = 4922;
        lvlToRew[34] = 5906;
        lvlToRew[35] = 7088;
        lvlToRew[36] = 8505;
        lvlToRew[37] = 10206;
        lvlToRew[38] = 12248;
        lvlToRew[39] = 14697;
        lvlToRew[40] = 17637;
        lvlToRew[41] = 21164;
        lvlToRew[42] = 25397;
        lvlToRew[43] = 30477;
        lvlToRew[44] = 36572;
        lvlToRew[45] = 43887;
        lvlToRew[46] = 52664;
        lvlToRew[47] = 63197;
        lvlToRew[48] = 75837;
        lvlToRew[49] = 91004;
    }

    // implement dummy override functions
    function diamondCut(FacetCut[] calldata _diamondCut, address _init, bytes calldata _calldata) external {}
    function facetAddress(bytes4 _functionSelector) external view returns (address facetAddress_) {}
    function facetAddresses() external view returns (address[] memory facetAddresses_) {}
    function facetFunctionSelectors(address _facet) external view returns (bytes4[] memory facetFunctionSelectors_) {}
    function facets() external view returns (Facet[] memory facets_) {}
}
