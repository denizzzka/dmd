/// Floating to text conversion
module core.internal.ftot;

import core.internal.string: signedToTempString, unsignedToTempString;

//~ pure:
//~ nothrow:
//~ @nogc:
//~ @safe:

//TODO: remove
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

        res = dtoa_puff!(true, true, uint)(buf, v, precision, false);
        assert(res == expected);

        res = dtoa_puff!(true, true, ushort)(buf, v, precision, false);
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
char[] floatingToTempString(bool expForm, bool stdcCompat, T)(T value, return scope char[] buf, in ushort precision, bool enableTrailingZeroes)
if(__traits(isFloating, T))
{
    //TODO: try to use uint on 64-bit systems to increase performance
    alias BigitType = ushort;

    char[] slice = dtoa_puff!(expForm, stdcCompat, BigitType)(buf, value, precision, enableTrailingZeroes);

    return slice;
}

unittest
{
    char[20] buf;
    auto r = floatingToTempString!(true, true)(-123.456789, buf, 6, false);

    assert(r == "-1.23457e+02");
}

version(linux)
    version = ComparisonWithLibc;
else version(Windows)
    version = ComparisonWithLibc;

unittest
{
    static void testIt(T)(T val, string phobos_std, string phobos_exp)
    {
        enum precision = 7;

        {
            void cmp(bool expForm)()
            {
                //FIXME: hardcoded buf size
                char[10000] buf;
                buf[$-1] = '\0';

                const shouldBe = expForm ? phobos_exp : phobos_std;

                if(shouldBe == "disabled")
                    return;

                const r = floatingToTempString!(expForm, false)(val, buf, precision, false);

                assert(r == shouldBe, `"`~r~`" but expected "`~shouldBe~`" (as implemented in Phobos, expForm=`~(expForm ? "true" : "false")~`)`);
            }

            cmp!false;
            cmp!true;
        }

        version(ComparisonWithLibc)
        {
            static string fmtStr(bool expForm)
            {
                static if(!is(T==real))
                    return expForm ? "%e" : "%f";
                else
                    return expForm ? "%Le" : "%Lf";
            }

            static string getLibcText(T val, bool expForm)
            {
                import core.stdc.stdio: snprintf;

                const fmt = fmtStr(expForm);

                //FIXME: hardcoded buf size
                //~ char[precision * 2 + 1 /*dot*/] buf = '|';
                char[10000] buf = '|';
                buf[$-1] = '\0';

                auto len = snprintf(buf.ptr, buf.length, &fmt[0], val);
                assert(len > 0);
                assert(len <= buf.length);

                return buf[0 .. len].idup;
            }

            void libcCmp(bool expForm)()
            {
                const stdcText = getLibcText(val, expForm);

                //TODO: test dtoa_puff() using both storage types, not floatingToTempString()
                mixin Estimation!ushort;

                char[maxBufSize!T] buf = '|';
                buf[$-1] = '\0';

                const asLibc = floatingToTempString!(expForm, true)(val, buf, precision, true);
                assert(asLibc == stdcText, `"`~asLibc~`" but stdc snprintf("`~fmtStr(expForm)~`") returns: "`~stdcText~`"`);
            }

            libcCmp!(false);
            libcCmp!(true);
        }
    }

    // Test on all posible types
    static void onAll(T, ARGS...)(T val, ARGS args)
    {
        static if(T.dig <= float.dig)
            testIt(float(val), args);

        static if(T.dig <= double.dig)
            testIt(double(val), args);

        static if(T.dig <= real.dig)
            testIt(real(val), args);
    }

    //TODO: add test with leading zero
    //TODO: add tests for all numeric types

    onAll(1.0f, "1", "1e+00");
    onAll(0.0f, "0", "0e+00");
    onAll(float.nan, "nan", "nan");
    onAll(float.infinity, "inf", "inf");
    onAll(-float.infinity, "-inf", "-inf");
    onAll(-123.45678f, "-123.456779", "-1.234568e+02");
    onAll(1e3f, "1000", "1e+03");
    onAll(0.001f, "0.001", "1e-03");
    onAll(-1.0e-8f, "-0", "-1e-08");
    onAll(-3.75733371660706733e+254, "-375733371660706733350021703837468260693310962815288025942112652778731979228624690746182101684187633634076761835259805303946874579012812170352826319278230807411175518153951956765533871792968837984915446671623313976187557599924035579899807743068455080820736", "-3.757334e+254");
    onAll(-3.75733371660706733e-254, "-0", "-3.757334e-254");
    onAll(float.max, "340282346638528859811704183484516925440" /* well-known maximum 32 bit IEEE-754 floating value */, "3.402823e+38");
    onAll(-float.max, "-340282346638528859811704183484516925440" /* ditto */, "-3.402823e+38");
    onAll(double.max, "179769313486231570814527423731704356798070567525844996598917476803157260780028538760589558632766878171540458953514382464234321326889464182768467546703537516986049910576551282076245490090389328944075868508455133942304583236903222948165808559332123348274797826204144723168738177180919299881250404026184124858368", "1.797693e+308");
    onAll(-double.max, "-179769313486231570814527423731704356798070567525844996598917476803157260780028538760589558632766878171540458953514382464234321326889464182768467546703537516986049910576551282076245490090389328944075868508455133942304583236903222948165808559332123348274797826204144723168738177180919299881250404026184124858368", "-1.797693e+308");

    // Comparison with predefined string disabled because it is should be a huge string
    onAll(real.max, "disabled", "disabled");
    onAll(-real.max, "disabled", "disabled");
}

private mixin template Estimation(T)
if(is(T == ushort) || is(T == uint))
{
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

    template maxBufSize(F)
    {
        //TODO: implement more precise calculation
        //~ enum maxBufSize = F.dig * 2 /*twice for libc-style precission*/ + 1 /*sign*/ + 1 /*dot*/ + 5 /*exponent*/;
        //FIXME:
        enum maxBufSize = 10000;
    }
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

    mixin Estimation!T;

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
        enum intPartBigitsNum = 20 / decimalExp + (20 % decimalExp == 0 ? 0 : 1) + 5 /*FIXME: hardcoded 5 for real values only*/;
        //~ static assert(intPartBigitsNum == 5);
    }
    else
    {
        alias GF = UL;
        enum intPartBigitsNum = 2 + 5 /*FIXME: hardcoded 5 for real values only*/;
    }

    // TODO: remove
    private int exp;

    this(F)(F d)
    if(__traits(isFloating, F))
    {
        //TODO: replace libc frexp() call
        import core.stdc.math;

        enum numBits = d.mant_dig;

        static if(is(F == float))
            const integralPart = frexpf(d, &exp) * (1U << numBits);
        else static if(is(F == double)) // TODO: add "real same as double" case here
            const integralPart = frexp(d, &exp) * (1UL << numBits);
        else static if(is(F == real))
        {
            auto mant = frexpl(d, &exp).fabsl;
            printf("REAL value to process: mant=%Lg exp=%d\n", mant, exp);
        }

        //TODO: make exp const
        exp -= numBits;

        byte intPartIdx = intPartBigitsNum;

        void addIntPartAsInteger(GF v)
        {
            assert(intPartIdx > 0);

            while(true)
            {
                intPartIdx--;

                const lessSig = v % bigitBound;
                v /= bigitBound;

                bigitsArr[intPartIdx] = lessSig;
                numBigits++;

                printf("lessSig added: %llu to pos=%d\n", lessSig, intPartIdx);

                if(v == 0)
                    break;
            }
        }

        void addIntPart(F integralPart)
        {
            auto v = cast(GF) (integralPart < 0 ? -integralPart : integralPart);
            addIntPartAsInteger(v);
        }

        static if(!is(F == real))
            addIntPart(integralPart);
        else
        {{
            // Fetch unsigned values from a big mantiss

            short shift = F.mant_dig;

            while(true)
            {
                printf("shift=%d\n", shift);

                if(shift == 0)
                {
                    const word = cast(ulong) mant;
                    addIntPartAsInteger(word);
                    break;
                }

                const scaled = ldexpl(mant, shift);
                //TODO: replace cast(ulong) by cast(T)?
                const word = cast(ulong) scaled;
                addIntPartAsInteger(word);

                // Remove fetched bits
                mant -= ldexpl(cast(real) word, -shift);

                if(mant < mant.epsilon)
                    break;

                shift -= bigitBitWidth;

                // In case incomplete last word when .mant_dig isn't multiple of bigitBitWidth
                static if(F.mant_dig % bigitBitWidth != 0)
                    if(shift < 0)
                        shift = 0;
            }
        }}

        assert(intPartIdx >= 0);

        // Skip leading zero bigits
        bigits = bigitsArr[intPartIdx .. $];


        //TODO: remove
        foreach(i, b; bigits[0 .. numBigits+1])
            printf("bigit[%d]=%d\n", cast(int)i, b);

        if(exp >= 0)
        {
            massiveLeftShift(exp);
            fractionStart = numBigits;
        }
        else
        {
            const integralBigitsAcquired = intPartBigitsNum - intPartIdx;
            fractionStart = integralBigitsAcquired;

            massiveRightShift(-exp);
        }

        // Assigning again for better boundary control
        version(D_NoBoundsChecks){} else
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

//TODO: enableTrailingZeroes -> enableTrailingZeros
char[] dtoa_puff(bool expForm, bool stdcCompat, T, F)(return scope char[] buf, F val, ushort precision, in bool enableTrailingZeroes)
{
    static char[] setRet(return scope char[] buf, string s)
    {
        auto ret = buf[0 .. s.length];
        ret[] = s.dup;
        return ret;
    }

    // Special cases
    if(val != val)
        return setRet(buf, "nan");
    else if(val > F.max)
        return setRet(buf, "inf");
    else if(val < -F.max)
        return setRet(buf, "-inf");

    const d = Decimal!(T, 10000 /* FIXME: remove magic number */)(val);

    uint bigitIndex;

    void blockOut(bool enableLeadingZeros)()
    {
        ref const bigit = d.bigits[bigitIndex];

        const end = count + d.decimalExp;
        auto block = buf[count .. end];

        const digits = to_chars_reverse(block, bigit);
        assert(digits.length <= d.decimalExp);

        static if(enableLeadingZeros)
        {
            block[0 .. $ - digits.length] = '0';
            digitsCount += block.length;
        }
        else
            digitsCount += digits.length;

        count = end;
        bigitIndex++;
    }

    // First bigit output
    size_t digitsCount;
    size_t count = 1; // possible minus sign
    size_t firstDigitIdx;

    if(!expForm && d.fractionStart <= 0)
    {
        // At first need to add leading zeros
        auto zNum = -d.fractionStart * d.decimalExp;
        if(zNum > precision)
            zNum = precision;

        firstDigitIdx = count;
        const end = count + zNum + 1;
        buf[count .. end] = '0';
        count = end;

        digitsCount += zNum;

        blockOut!true;
    }
    else
    {
        blockOut!false;
        firstDigitIdx = count - digitsCount;
    }

    size_t startIdx = firstDigitIdx;
    if(val < 0)
        buf[--startIdx] = '-';

    printf("bigit=%d\n", d.bigits[bigitIndex]);
    printf("buf=%s\n", buf.ptr);
    printf("count=%d\n", cast(int)count);
    printf("digitsCount=%d\n", cast(uint)digitsCount);
    printf("fractionStart=%d\n", cast(int)d.fractionStart);
    printf("bigitIndex=%d\n", cast(int)bigitIndex);

    //~ foreach(i, b; d.bigits)
        //~ printf("bigits[%d] = %d\n", cast(uint)i, cast(uint)b);

    static if(!expForm)
    {
        size_t dotPlace = d.fractionStart <= 0 ? 1 : digitsCount;
    }
    else
    {
        const dotPlace = 1;
        const remainedIntDigits = (d.fractionStart - bigitIndex) * d.decimalExp;
        int exp = cast(int)digitsCount - dotPlace + remainedIntDigits;

        printf("remainedIntDigits=%d\n", cast(int)remainedIntDigits);
        printf("exp=%d\n", cast(int)exp);
    }

    assert(dotPlace > 0);

    printf("Remaining bigits output\n");

    // Remaining bigits output
    //TODO: first bigit can be printed in this loop too
    while(bigitIndex < d.numBigits)
    {
        static if(expForm)
            const currPrecision = digitsCount;
        else
        {
            const onIntegerPart = (bigitIndex < d.fractionStart);
            const currPrecision = onIntegerPart ? 0 : digitsCount - dotPlace;
        }

        printf("precision=%d\n", cast(int)precision);
        printf("currPrecision=%d\n", cast(int)currPrecision);

        if(currPrecision > precision)
            break;

        blockOut!true;

        static if(!expForm)
        {
            if(onIntegerPart && d.fractionStart > 0)
                    dotPlace = digitsCount;
        }
    }

    static if(!expForm)
    {
        // Precision value is taken into account only after dot
        precision += dotPlace - 1;
    }

    printf("firstDigitIdx=%d\n", cast(int)firstDigitIdx);

    if(digitsCount > precision)
    {
        auto toRound = buf[firstDigitIdx .. count];
        count += precision - toRound.length;
        auto deltaExp = round(toRound, precision, d.bigits[bigitIndex .. $]);

        static if(expForm)
            exp += deltaExp;

        digitsCount = precision;
        printf("aft round buf=%s\n", buf.ptr);
    }

    printf("startIdx=%d\n", cast(int)startIdx);
    printf("digitsCount=%d\n", cast(uint)digitsCount);
    printf("precision=%d\n", precision);
    printf("numBigits=%d\n", d.numBigits);

    // Add decimal dot
    //TODO: _dotIdx -> dotIdx
    const _dotIdx= firstDigitIdx + dotPlace;

    if(stdcCompat || _dotIdx != count)
    {
        printf("before dot buf=%s\n", buf.ptr);

        count++;

        //TODO: char-by-char shift is too slow
        //TODO: seems, shifting from right to left will be faster, because most values have dot at left size
        foreach_reverse(i; _dotIdx .. count)
            buf[i] = buf[i-1];

        buf[_dotIdx] = '.';

        printf("after  dot buf=%s\n", buf.ptr);
    }

    if(enableTrailingZeroes)
    {
        for(; digitsCount < precision; digitsCount++)
            buf[count++] = '0';
    }
    else
    {
        printf("remove trailing zeros branch\n");

        static if(stdcCompat)
        {
            // Special case for adding 0 after dot if no more digits after dot
            if(_dotIdx == count - 1)
                buf[count++] = '0';
        }

        // Remove trailing zeros
        for(; count > _dotIdx; count--)
        {
            const c = buf[count-1];

            static if(stdcCompat)
            {
                if(buf[count-2] == '.')
                    break;
            }
            else
            {
                if(c == '.')
                {
                    count--;
                    break;
                }
            }

            if(c != '0')
                break;
        }
    }

    static if(expForm)
        exponentOutput!stdcCompat(buf, count, exp);

    return buf[startIdx .. count];
}

private auto round(T)(return scope char[] buf, in uint precision, in T[] notProcessedBigits)
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

    int expDelta;
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
            expDelta++;
        }
    }

    return expDelta;
}

private void exponentOutput(bool stdcCompat)(char[] buf, ref size_t count, int exp)
in(exp <= 9999)
in(exp >= -9999)
{
    buf[count++] = 'e';

    void append(bool signed)(int n)
    {
        auto digits = signed ? signedToTempString(n) : unsignedToTempString(n);

        const end = count + digits.length;
        buf[count .. end] = digits;
        count = end;
    }

    version(all)
    {
        if(exp >= 0)
            buf[count] = '+';
        else
        {
            buf[count] = '-';
            exp = -exp;
        }

        count++;

        if(exp > 99)
        {
            append!false(exp);
            return;
        }

        const tens = exp / 10;
        buf[count++] = cast(char)('0' + tens);
        buf[count++] = cast(char)('0' + exp % 10);
    }
}

/// Same as C++ std::to_chars but outputs from right boundary
private char[] to_chars_reverse(T)(scope char[] buf, T val, bool noTrailingZeros = false)
if(__traits(isUnsigned, T))
{
    char[] digits;

    if(noTrailingZeros)
        digits = unsignedToTempString!(10, false, true)(val, buf);
    else
        digits = unsignedToTempString(val, buf);

    //TODO: return len, not slice
    return digits;
}
