// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity >=0.8.0;

import "./PRBMathCommon.sol";

/// @title PRBMathSD59x18
/// @author Paul Razvan Berg
/// @notice Smart contract library for advanced fixed-point math. It works with int256 numbers considered to have 18
/// trailing decimals. We call this number representation signed 59.18-decimal fixed-point, since the numbers can have
/// a sign and there can be up to 59 digits in the integer part and up to 18 digits in the fractional part. The numbers
/// are bound by the minimum and the maximum values permitted by the Solidity type int256.
library PRBMathSD59x18 {
    /// @dev Half the SCALE number.
    int256 internal constant HALF_SCALE = 5e17;

    /// @dev The maximum value a signed 59.18-decimal fixed-point number can have.
    int256 internal constant MAX_SD59x18 = 57896044618658097711785492504343953926634992332820282019728792003956564819967;

    /// @dev The maximum whole value a signed 59.18-decimal fixed-point number can have.
    int256 internal constant MAX_WHOLE_SD59x18 = 57896044618658097711785492504343953926634992332820282019728000000000000000000;

    /// @dev The minimum value a signed 59.18-decimal fixed-point number can have.
    int256 internal constant MIN_SD59x18 = -57896044618658097711785492504343953926634992332820282019728792003956564819968;

    /// @dev The minimum whole value a signed 59.18-decimal fixed-point number can have.
    int256 internal constant MIN_WHOLE_SD59x18 = -57896044618658097711785492504343953926634992332820282019728000000000000000000;

    /// @dev Constant that determines how many decimals can be represented.
    int256 internal constant SCALE = 1e18;

    /// INTERNAL FUNCTIONS ///

    /// @notice Calculate the absolute value of x.
    ///
    /// @dev Requirements:
    /// - x must be higher than min 59.18.
    ///
    /// @param x The number to calculate the absolute for.
    /// @param result The absolute value of x.
    function abs(int256 x) internal pure returns (int256 result) {
        require(x > MIN_SD59x18);
        return x < 0 ? -x : x;
    }

    /// @notice Calculates arithmetic average of x and y, rounding down.
    /// @param x The first operand as a signed 59.18-decimal fixed-point number.
    /// @param y The second operand as a signed 59.18-decimal fixed-point number.
    /// @return result The arithmetic average as a signed 59.18-decimal fixed-point number.
    function avg(int256 x, int256 y) internal pure returns (int256 result) {
        // The operations can never overflow.
        unchecked {
            // The last operand checks if both x and y are odd and if that is the case, we add 1 to the result. We need
            // to do this because if both numbers are odd, the 0.5 remainder gets truncated twice.
            result = (x >> 1) + (y >> 1) + (x & y & 1);
        }
    }

    /// @notice Yields the least greatest signed 59.18 decimal fixed-point number greater than or equal to x.
    ///
    /// @dev Optimised for fractional value inputs, because for every whole value there are (1e18 - 1) fractional counterparts.
    /// See https://en.wikipedia.org/wiki/Floor_and_ceiling_functions.
    ///
    /// Requirements:
    /// - x must be less than or equal to MAX_WHOLE_SD59x18.
    ///
    /// @param x The signed 59.18-decimal fixed-point number to ceil.
    /// @param result The least integer greater than or equal to x.
    function ceil(int256 x) internal pure returns (int256 result) {
        require(x <= MAX_WHOLE_SD59x18);
        unchecked {
            int256 remainder = x % SCALE;
            if (remainder == 0) {
                result = x;
            } else {
                // Solidity uses C fmod style, which returns a modulus with the same sign as x.
                result = x - remainder;
                if (x > 0) {
                    result += SCALE;
                }
            }
        }
    }

    /// @notice Divides two signed 59.18-decimal fixed-point numbers, returning a new signed 59.18-decimal fixed-point number.
    ///
    /// @dev Scales the numerator first, then divides by the denominator.
    ///
    /// Requirements:
    /// - y cannot be zero.
    /// - x * SCALE must not be higher than MAX_SD59x18.
    ///
    /// Caveats:
    /// - Susceptible to phantom overflow when x * SCALE > MAX_SD59x18.
    ///
    /// @param x The numerator as a signed 59.18-decimal fixed-point number.
    /// @param y The denominator as a signed 59.18-decimal fixed-point number.
    /// @param result The quotient as a signed 59.18-decimal fixed-point number.
    function div(int256 x, int256 y) internal pure returns (int256 result) {
        int256 scaledNumerator = x * SCALE;
        // When dividing numbers in Solidity, overflow can happen only when the scaled numerator is MIN_SD59x18 and the
        // denominator is -1, but the scaled numerator ends in 18 zeros so it can't be MIN_SD59x18.
        // See https://ethereum.stackexchange.com/questions/96482/can-division-underflow-or-overflow-in-solidity
        unchecked {
            result = scaledNumerator / y;
        }
    }

    /// @notice Returns Euler's number as a signed 59.18-decimal fixed-point number.
    /// @dev See https://en.wikipedia.org/wiki/E_(mathematical_constant).
    function e() internal pure returns (int256 result) {
        result = 2718281828459045235;
    }

    /// @notice Calculates the natural exponent of x.
    ///
    /// @dev Based on the insight that e^x = 2^(x * log2(e)).
    ///
    /// Requirements:
    /// - x must be lower than 88722839111672999628.
    /// - All from "log2".
    ///
    /// @param x The exponent as a signed 59.18-decimal fixed-point number.
    /// @return result The result as a signed 59.18-decimal fixed-point number.
    function exp(int256 x) internal pure returns (int256 result) {
        // Without this check, the value passed to "exp2" would be higher than 128e18.
        require(x < 88722839111672999628);
        unchecked {
            // The multiplier is log2(e).
            result = exp2(mul(x, 1442695040888963407));
        }
    }

    /// @notice Calculates the binary exponent of x using the binary fraction method.
    ///
    /// @dev See https://ethereum.stackexchange.com/q/79903/24693.
    ///
    /// Requirements:
    /// - x must be 128e18 or lower.
    /// - x cannot be negative.
    /// - result must fit within MAX_SD59x18.
    ///
    /// @param x The exponent as a signed 59.18-decimal fixed-point number.
    /// @return result The result as a signed 59.18-decimal fixed-point number.
    function exp2(int256 x) internal pure returns (int256 result) {
        // 2**128 doesn't fit within the 128.128-bit format used internally in this function.
        require(x < 128e18);

        // TODO: remove this check and make the function compatible with negative numbers.
        require(x >= 0);

        unchecked {
            // Convert x to the 128.128-bit fixed-point format.
            uint256 xb = (uint256(x) << 128) / uint256(SCALE);

            // Start from 0.5 in the 128.128-bit fixed-point format. We need to use uint256 because the intermediary
            // may get very close to 2^256, which doesn't fit in int256.
            uint256 resultAux = 0x80000000000000000000000000000000;

            // Multiply the result by root(2, 2^-i) when the bit at position i is 1. None of the intermediary results overflows
            // because the initial result is 2^127 and all magic factors are lower than 2^129.
            if (xb & 0x80000000000000000000000000000000 > 0) resultAux = (resultAux * 0x16A09E667F3BCC908B2FB1366EA957D3E) >> 128;
            if (xb & 0x40000000000000000000000000000000 > 0) resultAux = (resultAux * 0x1306FE0A31B7152DE8D5A46305C85EDED) >> 128;
            if (xb & 0x20000000000000000000000000000000 > 0) resultAux = (resultAux * 0x1172B83C7D517ADCDF7C8C50EB14A7920) >> 128;
            if (xb & 0x10000000000000000000000000000000 > 0) resultAux = (resultAux * 0x10B5586CF9890F6298B92B71842A98364) >> 128;
            if (xb & 0x8000000000000000000000000000000 > 0) resultAux = (resultAux * 0x1059B0D31585743AE7C548EB68CA417FE) >> 128;
            if (xb & 0x4000000000000000000000000000000 > 0) resultAux = (resultAux * 0x102C9A3E778060EE6F7CACA4F7A29BDE9) >> 128;
            if (xb & 0x2000000000000000000000000000000 > 0) resultAux = (resultAux * 0x10163DA9FB33356D84A66AE336DCDFA40) >> 128;
            if (xb & 0x1000000000000000000000000000000 > 0) resultAux = (resultAux * 0x100B1AFA5ABCBED6129AB13EC11DC9544) >> 128;
            if (xb & 0x800000000000000000000000000000 > 0) resultAux = (resultAux * 0x10058C86DA1C09EA1FF19D294CF2F679C) >> 128;
            if (xb & 0x400000000000000000000000000000 > 0) resultAux = (resultAux * 0x1002C605E2E8CEC506D21BFC89A23A011) >> 128;
            if (xb & 0x200000000000000000000000000000 > 0) resultAux = (resultAux * 0x100162F3904051FA128BCA9C55C31E5E0) >> 128;
            if (xb & 0x100000000000000000000000000000 > 0) resultAux = (resultAux * 0x1000B175EFFDC76BA38E31671CA939726) >> 128;
            if (xb & 0x80000000000000000000000000000 > 0) resultAux = (resultAux * 0x100058BA01FB9F96D6CACD4B180917C3E) >> 128;
            if (xb & 0x40000000000000000000000000000 > 0) resultAux = (resultAux * 0x10002C5CC37DA9491D0985C348C68E7B4) >> 128;
            if (xb & 0x20000000000000000000000000000 > 0) resultAux = (resultAux * 0x1000162E525EE054754457D5995292027) >> 128;
            if (xb & 0x10000000000000000000000000000 > 0) resultAux = (resultAux * 0x10000B17255775C040618BF4A4ADE83FD) >> 128;
            if (xb & 0x8000000000000000000000000000 > 0) resultAux = (resultAux * 0x1000058B91B5BC9AE2EED81E9B7D4CFAC) >> 128;
            if (xb & 0x4000000000000000000000000000 > 0) resultAux = (resultAux * 0x100002C5C89D5EC6CA4D7C8ACC017B7CA) >> 128;
            if (xb & 0x2000000000000000000000000000 > 0) resultAux = (resultAux * 0x10000162E43F4F831060E02D839A9D16D) >> 128;
            if (xb & 0x1000000000000000000000000000 > 0) resultAux = (resultAux * 0x100000B1721BCFC99D9F890EA06911763) >> 128;
            if (xb & 0x800000000000000000000000000 > 0) resultAux = (resultAux * 0x10000058B90CF1E6D97F9CA14DBCC1629) >> 128;
            if (xb & 0x400000000000000000000000000 > 0) resultAux = (resultAux * 0x1000002C5C863B73F016468F6BAC5CA2C) >> 128;
            if (xb & 0x200000000000000000000000000 > 0) resultAux = (resultAux * 0x100000162E430E5A18F6119E3C02282A6) >> 128;
            if (xb & 0x100000000000000000000000000 > 0) resultAux = (resultAux * 0x1000000B1721835514B86E6D96EFD1BFF) >> 128;
            if (xb & 0x80000000000000000000000000 > 0) resultAux = (resultAux * 0x100000058B90C0B48C6BE5DF846C5B2F0) >> 128;
            if (xb & 0x40000000000000000000000000 > 0) resultAux = (resultAux * 0x10000002C5C8601CC6B9E94213C72737B) >> 128;
            if (xb & 0x20000000000000000000000000 > 0) resultAux = (resultAux * 0x1000000162E42FFF037DF38AA2B219F07) >> 128;
            if (xb & 0x10000000000000000000000000 > 0) resultAux = (resultAux * 0x10000000B17217FBA9C739AA5819F44FA) >> 128;
            if (xb & 0x8000000000000000000000000 > 0) resultAux = (resultAux * 0x1000000058B90BFCDEE5ACD3C1CEDC824) >> 128;
            if (xb & 0x4000000000000000000000000 > 0) resultAux = (resultAux * 0x100000002C5C85FE31F35A6A30DA1BE51) >> 128;
            if (xb & 0x2000000000000000000000000 > 0) resultAux = (resultAux * 0x10000000162E42FF0999CE3541B9FFFD0) >> 128;
            if (xb & 0x1000000000000000000000000 > 0) resultAux = (resultAux * 0x100000000B17217F80F4EF5AADDA45554) >> 128;
            if (xb & 0x800000000000000000000000 > 0) resultAux = (resultAux * 0x10000000058B90BFBF8479BD5A81B51AE) >> 128;
            if (xb & 0x400000000000000000000000 > 0) resultAux = (resultAux * 0x1000000002C5C85FDF84BD62AE30A74CD) >> 128;
            if (xb & 0x200000000000000000000000 > 0) resultAux = (resultAux * 0x100000000162E42FEFB2FED257559BDAA) >> 128;
            if (xb & 0x100000000000000000000000 > 0) resultAux = (resultAux * 0x1000000000B17217F7D5A7716BBA4A9AF) >> 128;
            if (xb & 0x80000000000000000000000 > 0) resultAux = (resultAux * 0x100000000058B90BFBE9DDBAC5E109CCF) >> 128;
            if (xb & 0x40000000000000000000000 > 0) resultAux = (resultAux * 0x10000000002C5C85FDF4B15DE6F17EB0E) >> 128;
            if (xb & 0x20000000000000000000000 > 0) resultAux = (resultAux * 0x1000000000162E42FEFA494F1478FDE05) >> 128;
            if (xb & 0x10000000000000000000000 > 0) resultAux = (resultAux * 0x10000000000B17217F7D20CF927C8E94D) >> 128;
            if (xb & 0x8000000000000000000000 > 0) resultAux = (resultAux * 0x1000000000058B90BFBE8F71CB4E4B33E) >> 128;
            if (xb & 0x4000000000000000000000 > 0) resultAux = (resultAux * 0x100000000002C5C85FDF477B662B26946) >> 128;
            if (xb & 0x2000000000000000000000 > 0) resultAux = (resultAux * 0x10000000000162E42FEFA3AE53369388D) >> 128;
            if (xb & 0x1000000000000000000000 > 0) resultAux = (resultAux * 0x100000000000B17217F7D1D351A389D41) >> 128;
            if (xb & 0x800000000000000000000 > 0) resultAux = (resultAux * 0x10000000000058B90BFBE8E8B2D3D4EDF) >> 128;
            if (xb & 0x400000000000000000000 > 0) resultAux = (resultAux * 0x1000000000002C5C85FDF4741BEA6E77F) >> 128;
            if (xb & 0x200000000000000000000 > 0) resultAux = (resultAux * 0x100000000000162E42FEFA39FE95583C3) >> 128;
            if (xb & 0x100000000000000000000 > 0) resultAux = (resultAux * 0x1000000000000B17217F7D1CFB72B45E3) >> 128;
            if (xb & 0x80000000000000000000 > 0) resultAux = (resultAux * 0x100000000000058B90BFBE8E7CC35C3F2) >> 128;
            if (xb & 0x40000000000000000000 > 0) resultAux = (resultAux * 0x10000000000002C5C85FDF473E242EA39) >> 128;
            if (xb & 0x20000000000000000000 > 0) resultAux = (resultAux * 0x1000000000000162E42FEFA39F02B772C) >> 128;
            if (xb & 0x10000000000000000000 > 0) resultAux = (resultAux * 0x10000000000000B17217F7D1CF7D83C1A) >> 128;
            if (xb & 0x8000000000000000000 > 0) resultAux = (resultAux * 0x1000000000000058B90BFBE8E7BDCBE2E) >> 128;
            if (xb & 0x4000000000000000000 > 0) resultAux = (resultAux * 0x100000000000002C5C85FDF473DEA871F) >> 128;
            if (xb & 0x2000000000000000000 > 0) resultAux = (resultAux * 0x10000000000000162E42FEFA39EF44D92) >> 128;
            if (xb & 0x1000000000000000000 > 0) resultAux = (resultAux * 0x100000000000000B17217F7D1CF79E949) >> 128;
            if (xb & 0x800000000000000000 > 0) resultAux = (resultAux * 0x10000000000000058B90BFBE8E7BCE545) >> 128;
            if (xb & 0x400000000000000000 > 0) resultAux = (resultAux * 0x1000000000000002C5C85FDF473DE6ECA) >> 128;
            if (xb & 0x200000000000000000 > 0) resultAux = (resultAux * 0x100000000000000162E42FEFA39EF366F) >> 128;
            if (xb & 0x100000000000000000 > 0) resultAux = (resultAux * 0x1000000000000000B17217F7D1CF79AFA) >> 128;
            if (xb & 0x80000000000000000 > 0) resultAux = (resultAux * 0x100000000000000058B90BFBE8E7BCD6E) >> 128;
            if (xb & 0x40000000000000000 > 0) resultAux = (resultAux * 0x10000000000000002C5C85FDF473DE6B3) >> 128;
            if (xb & 0x20000000000000000 > 0) resultAux = (resultAux * 0x1000000000000000162E42FEFA39EF359) >> 128;
            if (xb & 0x10000000000000000 > 0) resultAux = (resultAux * 0x10000000000000000B17217F7D1CF79AC) >> 128;

            // Multiply the result by the integer part 2^n + 1. We have to shift by one bit extra because we have already divided
            // by two when we set the result equal to 0.5 above.
            resultAux = resultAux << ((xb >> 128) + 1);

            // Convert the result to the signed 59.18-decimal fixed-point format.
            resultAux = PRBMathCommon.mulDiv(resultAux, uint256(SCALE), 2**128);
            require(resultAux <= uint256(MAX_SD59x18));
            result = int256(resultAux);
        }
    }

    /// @notice Yields the greatest signed 59.18 decimal fixed-point number less than or equal to x.
    ///
    /// @dev Optimised for fractional value inputs, because for every whole value there are (1e18 - 1) fractional counterparts.
    /// See https://en.wikipedia.org/wiki/Floor_and_ceiling_functions.
    ///
    /// Requirements:
    /// - x must be greater than or equal to MIN_WHOLE_SD59x18.
    ///
    /// @param x The signed 59.18-decimal fixed-point number to floor.
    /// @param result The greatest integer less than or equal to x.
    function floor(int256 x) internal pure returns (int256 result) {
        require(x >= MIN_WHOLE_SD59x18);
        unchecked {
            int256 remainder = x % SCALE;
            if (remainder == 0) {
                result = x;
            } else {
                // Solidity uses C fmod style, which returns a modulus with the same sign as x.
                result = x - remainder;
                if (x < 0) {
                    result -= SCALE;
                }
            }
        }
    }

    /// @notice Yields the excess beyond the floor of x for positive numbers and the part of the number to the right
    /// of the radix point for negative numbers.
    /// @dev Based on the odd function definition. https://en.wikipedia.org/wiki/Fractional_part
    /// @param x The signed 59.18-decimal fixed-point number to get the fractional part of.
    /// @param result The fractional part of x as a signed 59.18-decimal fixed-point number.
    function frac(int256 x) internal pure returns (int256 result) {
        unchecked {
            result = x % SCALE;
        }
    }

    /// @notice Calculates geometric mean of x and y, i.e. sqrt(x * y), rounding down.
    ///
    /// @dev Requirements:
    /// - x * y must be lower than MAX_SD59x18.
    /// - x * y cannot be negative.
    ///
    /// @param x The first operand as a signed 59.18-decimal fixed-point number.
    /// @param y The second operand as a signed 59.18-decimal fixed-point number.
    /// @return result The result as a signed 59.18-decimal fixed-point number.
    function gm(int256 x, int256 y) internal pure returns (int256 result) {
        int256 xy = x * y;
        require(xy >= 0);

        // We don't need to multiply by the SCALE here because the x*y product had already picked up a factor of SCALE
        // during multiplication. See the comments within the "sqrt" function.
        result = int256(PRBMathCommon.sqrt(uint256(xy)));
    }

    /// @notice Calculates 1 / x, rounding towards zero.
    ///
    /// @dev Requirements:
    /// - x cannot be zero.
    ///
    /// @param x The signed 59.18-decimal fixed-point number for which to calculate the inverse.
    /// @return result The inverse as a signed 59.18-decimal fixed-point number.
    function inv(int256 x) internal pure returns (int256 result) {
        unchecked {
            // 1e36 is SCALE * SCALE.
            result = 1e36 / x;
        }
    }

    /// @notice Calculates the natural logarithm of x.
    ///
    /// @dev Based on the insight that ln(x) = log2(x) * ln(2).
    ///
    /// Requirements:
    /// - All from "log2".
    ///
    /// Caveats:
    /// - All from "log2".
    /// - This doesn't return exactly 1 for 2.718281828459045235, for that we would need more fine-grained precision.
    ///
    /// @param x The signed 59.18-decimal fixed-point number for which to calculate the natural logarithm.
    /// @return result The natural logarithm as a signed 59.18-decimal fixed-point number.
    function ln(int256 x) internal pure returns (int256 result) {
        // The multiplier is ln(2).
        result = mul(log2(x), 693147180559945309);
    }

    /// @notice Calculates the common logarithm of x.
    ///
    /// @dev First checks if x is an exact power of ten and it stops if yes. If it's not, calculates the common
    /// logarithm based on the insight that log10(x) = log2(x) / log2(10).
    ///
    /// Requirements:
    /// - All from "log2".
    ///
    /// Caveats:
    /// - All from "log2".
    ///
    /// @param x The signed 59.18-decimal fixed-point number for which to calculate the common logarithm.
    /// @return result The common logarithm as a signed 59.18-decimal fixed-point number.
    function log10(int256 x) internal pure returns (int256 result) {
        require(x > 0);

        // Note that the "mul" in this block is the assembly mul operation, not the "mul" function defined in this contract.
        // prettier-ignore
        assembly {
            switch x
            case 1 { result := mul(SCALE, sub(0, 18)) }
            case 10 { result := mul(SCALE, sub(1, 18)) }
            case 100 { result := mul(SCALE, sub(2, 18)) }
            case 1000 { result := mul(SCALE, sub(3, 18)) }
            case 10000 { result := mul(SCALE, sub(4, 18)) }
            case 100000 { result := mul(SCALE, sub(5, 18)) }
            case 1000000 { result := mul(SCALE, sub(6, 18)) }
            case 10000000 { result := mul(SCALE, sub(7, 18)) }
            case 100000000 { result := mul(SCALE, sub(8, 18)) }
            case 1000000000 { result := mul(SCALE, sub(9, 18)) }
            case 10000000000 { result := mul(SCALE, sub(10, 18)) }
            case 100000000000 { result := mul(SCALE, sub(11, 18)) }
            case 1000000000000 { result := mul(SCALE, sub(12, 18)) }
            case 10000000000000 { result := mul(SCALE, sub(13, 18)) }
            case 100000000000000 { result := mul(SCALE, sub(14, 18)) }
            case 1000000000000000 { result := mul(SCALE, sub(15, 18)) }
            case 10000000000000000 { result := mul(SCALE, sub(16, 18)) }
            case 100000000000000000 { result := mul(SCALE, sub(17, 18)) }
            case 1000000000000000000 { result := 0 }
            case 10000000000000000000 { result := SCALE }
            case 100000000000000000000 { result := mul(SCALE, 2) }
            case 1000000000000000000000 { result := mul(SCALE, 3) }
            case 10000000000000000000000 { result := mul(SCALE, 4) }
            case 100000000000000000000000 { result := mul(SCALE, 5) }
            case 1000000000000000000000000 { result := mul(SCALE, 6) }
            case 10000000000000000000000000 { result := mul(SCALE, 7) }
            case 100000000000000000000000000 { result := mul(SCALE, 8) }
            case 1000000000000000000000000000 { result := mul(SCALE, 9) }
            case 10000000000000000000000000000 { result := mul(SCALE, 10) }
            case 100000000000000000000000000000 { result := mul(SCALE, 11) }
            case 1000000000000000000000000000000 { result := mul(SCALE, 12) }
            case 10000000000000000000000000000000 { result := mul(SCALE, 13) }
            case 100000000000000000000000000000000 { result := mul(SCALE, 14) }
            case 1000000000000000000000000000000000 { result := mul(SCALE, 15) }
            case 10000000000000000000000000000000000 { result := mul(SCALE, 16) }
            case 100000000000000000000000000000000000 { result := mul(SCALE, 17) }
            case 1000000000000000000000000000000000000 { result := mul(SCALE, 18) }
            case 10000000000000000000000000000000000000 { result := mul(SCALE, 19) }
            case 100000000000000000000000000000000000000 { result := mul(SCALE, 20) }
            case 1000000000000000000000000000000000000000 { result := mul(SCALE, 21) }
            case 10000000000000000000000000000000000000000 { result := mul(SCALE, 22) }
            case 100000000000000000000000000000000000000000 { result := mul(SCALE, 23) }
            case 1000000000000000000000000000000000000000000 { result := mul(SCALE, 24) }
            case 10000000000000000000000000000000000000000000 { result := mul(SCALE, 25) }
            case 100000000000000000000000000000000000000000000 { result := mul(SCALE, 26) }
            case 1000000000000000000000000000000000000000000000 { result := mul(SCALE, 27) }
            case 10000000000000000000000000000000000000000000000 { result := mul(SCALE, 28) }
            case 100000000000000000000000000000000000000000000000 { result := mul(SCALE, 29) }
            case 1000000000000000000000000000000000000000000000000 { result := mul(SCALE, 30) }
            case 10000000000000000000000000000000000000000000000000 { result := mul(SCALE, 31) }
            case 100000000000000000000000000000000000000000000000000 { result := mul(SCALE, 32) }
            case 1000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 33) }
            case 10000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 34) }
            case 100000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 35) }
            case 1000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 36) }
            case 10000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 37) }
            case 100000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 38) }
            case 1000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 39) }
            case 10000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 40) }
            case 100000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 41) }
            case 1000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 42) }
            case 10000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 43) }
            case 100000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 44) }
            case 1000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 45) }
            case 10000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 46) }
            case 100000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 47) }
            case 1000000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 48) }
            case 10000000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 49) }
            case 100000000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 50) }
            case 1000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 51) }
            case 10000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 52) }
            case 100000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 53) }
            case 1000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 54) }
            case 10000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 55) }
            case 100000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 56) }
            case 1000000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 57) }
            case 10000000000000000000000000000000000000000000000000000000000000000000000000000 { result := mul(SCALE, 58) }
            default {
                result := MAX_SD59x18
            }
        }

        if (result == MAX_SD59x18) {
            // Do the fixed-point division inline to save gas. The denominator is log2(10).
            unchecked {
                result = (log2(x) * SCALE) / 332192809488736234;
            }
        }
    }

    /// @notice Calculates the binary logarithm of x.
    ///
    /// @dev Based on the iterative approximation algorithm.
    /// https://en.wikipedia.org/wiki/Binary_logarithm#Iterative_approximation
    ///
    /// Requirements:
    /// - x must be greater than zero.
    ///
    /// Caveats:
    /// - The results are nor perfectly accurate to the last digit, due to the lossy precision of the iterative approximation.
    ///
    /// @param x The signed 59.18-decimal fixed-point number for which to calculate the binary logarithm.
    /// @return result The binary logarithm as a signed 59.18-decimal fixed-point number.
    function log2(int256 x) internal pure returns (int256 result) {
        require(x > 0);
        unchecked {
            // This works because log2(x) = -log2(1/x).
            int256 sign;
            if (x >= SCALE) {
                sign = 1;
            } else {
                sign = -1;
                // Do the fixed-point inversion inline to save gas. The numeretor is SCALE * SCALE.
                assembly {
                    x := div(1000000000000000000000000000000000000, x)
                }
            }

            // Calculate the integer part of the logarithm and add it to the result and finally calculate y = x * 2^(-n).
            uint256 n = PRBMathCommon.mostSignificantBit(uint256(x / SCALE));

            // The integer part of the logarithm as a signed 59.18-decimal fixed-point number. The operation can't overflow
            // beacuse n is maximum 255, SCALE is 1e18 and sign is either 1 or -1.
            result = int256(n) * SCALE;

            // This is y = x * 2^(-n).
            int256 y = x >> n;

            // If y = 1, the fractional part is zero.
            if (y == SCALE) {
                return result * sign;
            }

            // Calculate the fractional part via the iterative approximation.
            // The "delta >>= 1" part is equivalent to "delta /= 2", but shifting bits is faster.
            for (int256 delta = int256(HALF_SCALE); delta > 0; delta >>= 1) {
                y = (y * y) / SCALE;

                // Is y^2 > 2 and so in the range [2,4)?
                if (y >= 2 * SCALE) {
                    // Add the 2^(-m) factor to the logarithm.
                    result += delta;

                    // Corresponds to z/2 on Wikipedia.
                    y >>= 1;
                }
            }
            result *= sign;
        }
    }

    /// @notice Multiplies two signed 59.18-decimal fixed-point numbers, returning a new signed 59.18-decimal fixed-point number.
    ///
    /// @dev Requirements:
    /// - x * y must not be higher than MAX_SD59x18 or smaller than MIN_SD59x18.
    /// - x * y +/- HALF_SCALE must not be higher than MAX_SD59x18/ smaller than MIN_SD59x18.
    ///
    /// Caveats:
    /// - Susceptible to phantom overflow when the intermediary result does not between MIN_SD59x18 and MAX_SD59x18.
    ///
    /// @param x The multiplicand as a signed 59.18-decimal fixed-point number.
    /// @param y The multiplier as a signed 59.18-decimal fixed-point number.
    /// @param result The product as a signed 59.18-decimal fixed-point number.
    function mul(int256 x, int256 y) internal pure returns (int256 result) {
        int256 doubleScaledProduct = x * y;

        // Before dividing, we add half the SCALE for positive products and subtract half the SCALE for negative products,
        // so that we get rounding instead of truncation. Without this, 6.6e-19 would be truncated to 0 instead of being
        // rounded to 1e-18. See "Listing 6" and text above it at https://accu.org/index.php/journals/1717
        int256 doubleScaledProductWithHalfScale =
            doubleScaledProduct > 0 ? (doubleScaledProduct + HALF_SCALE) : (doubleScaledProduct - HALF_SCALE);

        unchecked {
            result = doubleScaledProductWithHalfScale / SCALE;
        }
    }

    /// @notice Returns PI as a signed 59.18-decimal fixed-point number.
    function pi() internal pure returns (int256 result) {
        result = 3141592653589793238;
    }

    /// @notice Raises x to the power of y using the famous algorithm "exponentiation by squaring".
    ///
    /// @dev See https://en.wikipedia.org/wiki/Exponentiation_by_squaring
    ///
    /// Requirements:
    /// - All from "abs" and "mulDiv".
    ///
    /// Caveats:
    /// - Assumes 0^0 is 1.
    /// - All from "mul".
    ///
    /// @param x The base as a signed 59.18-decimal fixed-point number.
    /// @param y The exponent as an uint256.
    /// @return result The result as a signed 59.18-decimal fixed-point number.
    function pow(int256 x, uint256 y) internal pure returns (int256 result) {
        uint256 absX = uint256(abs(x));

        // Calculate the first iteration of the loop in advance.
        uint256 absResult = y & 1 > 0 ? absX : uint256(SCALE);

        // Euivalent to "for(y /= 2; y > 0; y /= 2)" but faster.
        for (y >>= 1; y > 0; y >>= 1) {
            absX = PRBMathCommon.mulDiv(absX, absX, uint256(SCALE));

            // Equivalent to "y % 2 == 1".
            if (y & 1 > 0) {
                absResult = PRBMathCommon.mulDiv(absResult, absX, uint256(SCALE));
            }
        }

        require(absResult <= uint256(MAX_SD59x18));
        // Is the base negative and the exponent an odd number?
        bool isNegative = x < 0 && y & 1 == 1;
        result = isNegative ? -int256(absResult) : int256(absResult);
    }

    /// @notice Returns 1 as a signed 59.18-decimal fixed-point number.
    function scale() internal pure returns (int256 result) {
        result = SCALE;
    }

    /// @notice Calculates the square root of x, rounding down.
    /// @dev Uses the Babylonian method https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method.
    ///
    /// Requirements:
    /// - x cannot be negative.
    /// - x must be lower than MAX_SD59x18 / SCALE.
    ///
    /// Caveats:
    /// - The maximum fixed-point number permitted is 57896044618658097711785492504343953926634.992332820282019729.
    ///
    /// @param x The signed 59.18-decimal fixed-point number for which to calculate the square root.
    /// @return result The result as a signed 59.18-decimal fixed-point .
    function sqrt(int256 x) internal pure returns (int256 result) {
        require(x >= 0);
        require(x < 57896044618658097711785492504343953926634992332820282019729);
        unchecked {
            // Multiply x by the SCALE to account for the factor of SCALE that is picked up when multiplying two signed
            // 59.18-decimal fixed-point numbers together (in this case, those two numbers are both the square root).
            result = int256(PRBMathCommon.sqrt(uint256(x * SCALE)));
        }
    }
}