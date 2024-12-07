// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

enum UserType {
    BASIC,
    LOW_KOL,
    HIGH_KOL
}

library Utils {
    function power(uint256 base, uint256 exp) internal pure returns (uint256) {
        uint256 result = 10 ** 18; // Start with 1 in fixed-point representation
        for (uint256 i = 0; i < exp; i++) {
            result = (result * base) / 10 ** 18;
        }
        return result;
    }

    function calculateFee(uint256 initialFee, uint256 petID, uint256 modulo) internal pure returns (uint256) {
        uint256 exponent = petID % modulo;
        uint256 base = 110 * 10 ** 16; // 1.15 in fixed-point representation
        uint256 powerResult = power(base, exponent);
        return (initialFee * powerResult) / 10 ** 18;
    }
}
