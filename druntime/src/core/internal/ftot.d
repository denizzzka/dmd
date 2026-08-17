/// Floating to text conversion
module core.internal.ftot;

version(linux)
    version = ComparisonWithLibc;
else version(Windows)
    version = ComparisonWithLibc;

version(none)
unittest
{
    static void testIt(T)(T val, string phobos_std, string phobos_exp)
    {
        enum precision = 6;
        char[20] buf;
        //~ const asPhobosStd = floatingToTempString(val, Format.Std);
        const asPhobosExp = floatingToTempString(val, buf, precision, false);

        //~ assert(asPhobosStd == phobos_std, `"`~asPhobosStd~`" but expected "`~phobos_std~`" (as prints writeln())`);
        assert(asPhobosExp == phobos_exp, `"`~asPhobosExp~`" but expected "`~phobos_exp~`" (as prints writefln())`);

        version(ComparisonWithLibc)
        {
            static string getLibcText(T val, bool expForm)
            {
                import core.stdc.stdio: snprintf;

                const fmt = expForm ? "%e" : "%f";

                char[256] buf = 'a';
                const len = snprintf(buf.ptr, buf.length, &fmt[0], val);
                return buf[0 .. len].idup;
            }

            const stdcTextStd = getLibcText(val, false);
            const stdcTextExp = getLibcText(val, true);

            //~ const asLibcStd = floatingToTempString(val, buf, precision);
            const asLibcExp = floatingToTempString(val, buf, precision, true);

            //~ assert(asLibcStd == stdcTextStd, `"`~asLibcStd~`" but stdc snprintf() returns: "`~stdcTextStd~`"`);
            assert(asLibcExp == stdcTextExp, `"`~asLibcExp~`" but stdc snprintf() returns: "`~stdcTextExp~`"`);
        }
    }

    // Test on all posible types
    static void onAll(T, ARGS...)(T val, ARGS args)
    {
        static if(T.dig <= float.dig)
            testIt(cast(float) val, args);
        else static if(T.dig <= double.dig)
            testIt(cast(double) val, args);
        //TODO: implement
        //~ else static if(T.dig <= real.dig)
            //~ testIt(cast(real) val, args);
    }

    //TODO: add test with leading zero
    //TODO: add tests for all numeric types

    onAll(1.0f, "1", "1.0e+00");
    //~ onAll(0.0f, "0", "0.0e+00");
    //~ onAll(float.nan, "nan", "nan");
    //~ onAll(float.infinity, "inf", "inf");
    //~ onAll(-float.infinity, "-inf", "-inf");
    //~ onAll(-123.45678f, "-123.456779" /* FIXME: should be -123.456 */, "-1.234568e+02");
    //~ onAll(1e3f, "1000", "1.0e+03" /* FIXME: should be 1e+03 */);
    //~ onAll(0.001f, "0.001", "1.0e-03" /* FIXME: should be 1e-03 */);
    //~ onAll(1000.0f, "1000", "1.0e+03" /* FIXME: should be 1e+03 */);
    //~ onAll(0.001f, "0.001", "1.0e-03");
    //~ onAll(0.0001f, "0.0001", "1.0e-04");
    //~ onAll(double(-1.0e-8), "errrr 111", "errrr xxxxx");
}

//~ pure:
//~ nothrow:
//~ @nogc:
//~ @safe:

private char[] toCharsWithDot(size_t bufLen, T)(ref scope char[bufLen] buf, T val, ref size_t dotIdx, bool noTrailingZeros)
{
    scope char[bufLen - 1 /* no dot here */] tmp;
    const digits = to_chars_reverse(tmp, val, noTrailingZeros);
    char[] ret;

    const len = digits.length;
    if(dotIdx == 0 || dotIdx > len)
    {
        ret = buf[$-len .. $];
        ret[] = digits;

        if(dotIdx > 0)
            dotIdx -= len;
    }
    else
    {
        ret = buf[$-len-1 .. $];

        ret[0 .. dotIdx] = digits[0 .. dotIdx];
        ret[dotIdx] = '.';

        if(dotIdx < digits.length)
            ret[dotIdx + 1 .. $] = digits[dotIdx .. $];

        dotIdx = 0;
    }

    return ret;
}

unittest
{
    char[100] buf;
    size_t dotIdx = 23;

    assert(toCharsWithDot(buf, 1234567890u, dotIdx, false) == "1234567890");
    assert(dotIdx == 13);
    assert(toCharsWithDot(buf, 1234567890u, dotIdx, true) == "123456789");
    assert(dotIdx == 4);
    assert(toCharsWithDot(buf, 1234567890u, dotIdx, true) == "1234.56789");
    assert(dotIdx == 0);
}

unittest
{
    double val = 9999999.0;
    auto d = Decimal!(uint, 20)(val);
    d.bigitsArr = 0; // resets bigits storage

    d.bigits[0] = 1;

    foreach(i, b; d.bigits)
        printf("%llu %d\n", i, b);

    d.shiftFewBitsLeft(1);
    assert(d.bigits[0] == 2);

    d.shiftFewBitsLeft(d.maxLeftShift);
    assert(d.bigits[0] == 1);
}

unittest
{
    double val = 123.456;
    auto d = Decimal!(uint, 16)(val);
    d.numBigits = 2;

    const initial = d.bigits;

    // Shift right to 32 bits:
    d.shiftFewBitsRight(1);
    d.shiftFewBitsRight(2);
    d.shiftFewBitsRight(5);
    d.shiftFewBitsRight(8);
    d.shiftFewBitsRight(8);
    d.shiftFewBitsRight(8);

    // Shift left to the initial state:
    d.shiftFewBitsLeft(1);
    d.shiftFewBitsLeft(2);
    d.shiftFewBitsLeft(5);
    d.shiftFewBitsLeft(8);
    d.shiftFewBitsLeft(16);

    assert(initial[0 .. 2] == d.bigits[0 .. 2]);
}

unittest
{
    char[100] buf = '|';
    // Just in case of debugging using stdc:
    buf[$-1] = '\0';

    void testIt(T)(T v, string expected, ushort precision = 6)
    {
        char[] res;

        res = dtoa_puff!uint(buf, v, precision, false);
        assert(res == expected);

        res = dtoa_puff!ushort(buf, v, precision, false);
        assert(res == expected);
    }

    testIt(-12.345f, "-1.2345e+01");
    testIt(-12.345f, "-1.2345e+01", 5);
    testIt(2.0, "2.0e+00");
    testIt(-1.23456789101112, "-1.23457e+00");
    testIt(0.0000123456789, "1.23457e-05");
}

/**
Converts an floating value to a string of characters.

Can be used when compiling with -betterC. Does not allocate memory.

Params:
    value = the floating value to convert
    buf   = the pre-allocated buffer used to store the result
    precision = required count of significant digits

Returns:
    The floating value as a string of characters
*/
char[] floatingToTempString(T)(T value, return scope char[] buf, in ushort precision = 6, bool enableTrailingZeroes = false)
if(is(T == float) || is(T == double))
{
    //TODO: try to use ushort on 32-bit systems to increase performance
    alias BigitType = uint;

    auto d = Decimal!(BigitType, 20 /*FIXME*/)(value);
    auto slice = dtoa_puff!ushort(buf, value, precision, enableTrailingZeroes);

    return slice;
}

unittest
{
    char[20] buf;
    auto r = floatingToTempString(-123.456789, buf);

    assert(r == "-1.23457e+2");
}

/**
 * A fixed-point decimal number.
 *
 * Implements a fixed-point decimal number using a base-10^9 positional system.
 * It represents large numbers by breaking them into "bigits" (blocks),
 * where each block is a 9-digit decimal integer stored in a integer type.
 *
 * Params:
 *  T = unsigned integer of size 16 or 32
 */
struct Decimal(T, size_t maxLen)
if(is(T == ushort) || is(T == uint))
{
    /// Each bigit is a 9-digit decimal number.
    private T[maxLen] bigitsArr;
    T[] bigits;

    // Set decimal exponent. The most effective is to use
    // the largest power of 10 that is less than T.max.
    static if(T.sizeof == 4)
    {
        enum decimalExp = 9; // 10^9 - largest decimal number less than 32-bit value
        enum bigitBitWidth = 29; // 2^29 - largest binary number less than 10^9
        alias UL = ulong; // Twice longer than T
    }
    else static if(T.sizeof == 2)
    {
        enum decimalExp = 4; // 10^4 - largest decimal number less than 16-bit value
        enum bigitBitWidth = 13; // 2^13 - largest binary number less than 10^4
        alias UL = uint;
    }

    //TODO: add bigitsArr.length assert

    static assert(decimalExp <= bigitBitWidth);

    private enum maxLeftShift = bigitBitWidth;

    /// Radix
    enum T bigitBound = 10 ^^ decimalExp;

    //TODO: decrease type size?
    uint numBigits;
    int fractionStart;

    void shiftFewBitsLeft(in int n)
    in(n > 0)
    in(n <= maxLeftShift)
    {
        enum byte bigitIdx = 0;

        // Will number of blocks increase after the shifting?
        // If so, reserves space for a new block
        const ubyte offset = bigits[bigitIdx] >= (bigitBound >> n) ? 1 : 0;
        T carry;

        foreach_reverse(i; bigitIdx .. numBigits)
        {
            UL bigit = bigits[i];
            bigit = (bigit << n) + carry;

            if(bigit < bigitBound)
                carry = 0;
            else
            {
                carry = assumeSafeCastT(bigit / bigitBound);
                bigit = bigit % bigitBound;
            }

            bigits[i + offset] = assumeSafeCastT(bigit);
        }

        if(offset != 0)
        {
            bigits[bigitIdx] = carry;
            numBigits++;
        }
    }

    void shiftFewBitsRight(in int n)
    in(n > 0)
    in(n <= decimalExp)
    {
        const T mask = assumeSafeCastT((1 << n) - 1);
        T borrow;
        int offset;

        // Number was here and moved completely to the right?
        if((bigits[0] >> n) == 0 && bigits[0] != 0)
        {
            offset = 1;
            numBigits--;
            fractionStart--;

            borrow = assumeSafeCastT(UL(bigits[0]) * bigitBound >> n);
        }

        foreach(i; 0 .. numBigits)
        {
            const UL bigit = bigits[i + offset];

            bigits[i] = assumeSafeCastT(borrow + (bigit >> n));
            borrow = assumeSafeCastT((bigit & mask) * bigitBound >> n);
        }

        if(borrow != 0)
        {
            bigits[numBigits] = borrow;
            numBigits++;
        }
    }

    void massiveLeftShift(int n)
    in(n > 0)
    {
        enum bitsPerIteration = maxLeftShift;

        do
        {
            const bits = n < bitsPerIteration ? n : bitsPerIteration;
            shiftFewBitsLeft(bits);
            n -= bits;
        }
        while(n > 0);
    }

    void massiveRightShift(int n)
    in(n > 0)
    {
        enum bitsPerIteration = decimalExp;

        do
        {
            const bits = n < bitsPerIteration ? n : bitsPerIteration;
            shiftFewBitsRight(bits);
            n -= bits;
        }
        while(n > 0);
    }

    //TODO: naming
    enum bool tooBig = (T.sizeof == 2 && !is(F == float));

    static if(tooBig)
    {
        /// A type that is guaranteed to fit a integral part of floating T
        alias GF = ulong;

        /// Bigits number needed to fit GF
        enum intPartBigitsNum = 20 / decimalExp + (20 % decimalExp == 0 ? 0 : 1);
        static assert(intPartBigitsNum == 5);
    }
    else
    {
        alias GF = UL;
        enum intPartBigitsNum = 2;
    }

    // TODO: remove
    private int exp;

    this(F)(F d)
    if(__traits(isFloating, F))
    {
        //TODO: replace libc call by core.internal.convert
        import core.stdc.math: frexp;

        enum numBits = d.mant_dig;
        const integralPart = frexp(d, &exp) * (1UL << numBits);

        auto v = cast(GF) (integralPart < 0 ? -integralPart : integralPart);

        //TODO: make exp const
        exp -= numBits;

        byte intPartIdx = intPartBigitsNum - 1;

        while(true)
        {
            const lessSig = v % bigitBound;
            bigitsArr[intPartIdx] = lessSig;
            numBigits++;

            v /= bigitBound;

            if(v == 0)
                break;

            intPartIdx--;
        }

        const integralBigitsAcquired = intPartBigitsNum - intPartIdx;
        fractionStart = integralBigitsAcquired - 1;

        assert(intPartIdx >= 0);

        // Skip leading zero bigits
        bigits = bigitsArr[intPartIdx .. $];

        if(exp >= 0)
        {
            massiveLeftShift(exp);
        }
        else
        {
            massiveRightShift(-exp);
            fractionStart++;
        }

        // Assigning again for better boundary control
        bigits = bigits[0 .. numBigits + 1];
    }

    private static T assumeSafeCastT(V)(V val, size_t line = __LINE__)
    if(__traits(isIntegral, V))
    {
        assert(val >= 0);
        assert(val <= T.max);

        return cast(T) val;
    }
}

import core.stdc.stdio: printf;

char[] dtoa_puff(T, F)(return scope char[] buf, F val, in ushort precision, in bool enableTrailingZeroes)
{
    const d = Decimal!(T, 100)(val);

    uint bigitIndex;

    debug
    {
        import core.stdc.math: log10l;
        //TODO: templatize buf len?
        assert(buf.length >= ulong.max.log10l);
    }

    // First bigit output
    enum firstBigitEnd = d.decimalExp + 1 /* possible minus sign */;
    const firstBigit = d.bigits[bigitIndex];
    const dotPlace = 1;
    size_t dotIdx = dotPlace;
    size_t digitsCount = toCharsWithDot(buf[1 .. firstBigitEnd], firstBigit, dotIdx, false).length;
    assert(dotIdx == 0);
    bigitIndex++;

    const firstDigitIdx = firstBigitEnd - digitsCount;
    size_t startIdx = firstDigitIdx;
    if(val < 0)
        buf[--startIdx] = '-';

    // Decimal dot is not longer counted as digit
    digitsCount -= 1;

    size_t count = firstBigitEnd;

    printf("bigit=%d\n", firstBigit);
    printf("buf=%s\n", buf.ptr);
    printf("count=%d\n", cast(int)count);
    printf("digitsCount=%d\n", cast(uint)digitsCount);
    printf("fractionStart=%d\n", cast(int)d.fractionStart);
    printf("bigitIndex=%d\n", cast(int)bigitIndex);

    const remainedIntDigits = (d.fractionStart - bigitIndex) * d.decimalExp;
    int exp = cast(int)digitsCount - dotPlace + remainedIntDigits;

    printf("remainedIntDigits=%d\n", cast(int)remainedIntDigits);
    printf("exp=%d\n", cast(int)exp);

    // Remaining bigits output
    for(; bigitIndex < d.numBigits && digitsCount <= precision; bigitIndex++)
    {
        const nextBlockIdx = count + d.decimalExp;
        auto block = buf[count .. nextBlockIdx];

        const digits = to_chars_reverse(block, d.bigits[bigitIndex]);
        assert(digits.length <= d.decimalExp);

        block[0 .. $ - digits.length] = '0';

        count = nextBlockIdx;
        digitsCount += block.length;
    }

    printf("firstDigitIdx=%d\n", cast(int)firstDigitIdx);

    if(digitsCount > precision)
    {
        auto toRound = buf[firstDigitIdx .. count];
        count = count - toRound.length + round(toRound, precision + 1 /*decimal dot*/, d.bigits[bigitIndex .. $], exp);
        digitsCount = precision;
        printf("aft round buf=%s\n", buf.ptr);
    }

    printf("startIdx=%d\n", cast(int)startIdx);
    printf("digitsCount=%d\n", cast(uint)digitsCount);
    printf("precision=%d\n", precision);
    printf("numBigits=%d\n", d.numBigits);

    if(enableTrailingZeroes)
    {
        for(ushort i = 0; digitsCount < precision; i++)
            buf[count++] = '0';
    }
    else
    {
        // Remove trailing zeros
        for(; count > firstDigitIdx; count--)
        {
            if(buf[count-1] != '0' || buf[count-2] == '.')
                break;
        }
    }

    buf[count++] = 'e';

    {
        if(exp >= 0)
            buf[count] = '+';
        else
        {
            buf[count] = '-';
            exp = -exp;
        }
        count++;

        if(exp > 100)
        {
            assert(exp < 999);

            const hund = exp / 100;
            buf[count++] = cast(char)('0' + hund);
            exp -= hund;
        }

        buf[count++] = cast(char)('0' + exp / 10);
        buf[count++] = cast(char)('0' + exp % 10);
    }

    return buf[startIdx .. count];
}

private ushort round(T)(return scope char[] buf, in uint precision, in T[] notProcessedBigits, ref int exp)
{
    printf("to round buf=%s\n", buf.ptr);
    printf("to round buf.length=%llu\n", buf.length);

    // Checks: exactly 0.5 or a little higher?
    bool hasNonzero()
    {
        foreach(i, ref c; buf[precision + 1 .. $])
            if(c != '0')
            {
                printf("found nonzero at idx=%d\n", cast(int)i);
                return true;
            }

        foreach(i, ref b; notProcessedBigits)
            if(b != 0)
            {
                printf("found nonzero at bigit idx=%d\n", cast(int)i);
                return true;
            }

        return false;
    };

    //~ printf("hasNonzero=%d\n", hasNonzero);

    const digit = buf[precision];

    if(digit > '5' || (digit == '5' && ((buf[precision - 1] % 2) == 1 || hasNonzero)))
    {
        // TODO: foreach_reverse
        int i = precision - 1;
        for (; i >= 0 && buf[i] == '9'; --i)
            buf[i] = '0';

        if (i >= 0)
            ++buf[i];
        else
        {
            buf[0] = '1';
            exp++;
        }
    }

    return cast(ushort) precision;
}

/// Same as C++ std::to_chars but outputs from right boundary
private char[] to_chars_reverse(T)(scope char[] buf, T val, bool noTrailingZeros = false)
if(__traits(isUnsigned, T))
{
    import core.internal.string: unsignedToTempString;

    char[] digits;

    if(noTrailingZeros)
        digits = unsignedToTempString!(10, false, true)(val, buf);
    else
        digits = unsignedToTempString(val, buf);

    return digits;
}
