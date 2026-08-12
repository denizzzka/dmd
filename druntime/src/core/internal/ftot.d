/// Floating to text conversion
module core.internal.ftot;

import core.stdc.stdio;

//~ @safe:

unittest
{
    double val = 0.0;
    auto d = Decimal!(uint, 20)(val);
    d.bigits = 0;

    d.addBigit(1);
    assert(d.bigits[1] == 1);

    d.shiftFewBitsLeft(d.maxLeftShift);
    d.shiftFewBitsLeft(1);
    assert(d.bigits[0] == 1);

    d.shiftFewBitsLeft(d.maxLeftShift);
    d.shiftFewBitsLeft(1);
    assert(d.bigits[0] == 1);
}

unittest
{
    double val = 123.456;
    auto d = Decimal!(uint, 16)(val);
    //~ assert(d.numBigits == 7);

    const initial = d.bigits.idup;

    // Shift right to 32 bits:
    d.shiftFewBitsRight(1);
    d.shiftFewBitsRight(2);
    d.shiftFewBitsRight(5);
    d.shiftFewBitsRight(8);
    d.shiftFewBitsRight(8);
    d.shiftFewBitsRight(8);

    //~ assert(d.numBigits == 4);

    //~ const onRightSide = d.bigits.idup;
    foreach(b; d.bigits)
        printf(">>>Rbigit=%d\n", b);

    // Shift left to the initial state:
    d.shiftFewBitsLeft(1);
    d.shiftFewBitsLeft(2);
    d.shiftFewBitsLeft(5);
    d.shiftFewBitsLeft(8);
    d.shiftFewBitsLeft(16);

    printf(">>> numBigits=%d\n", d.numBigits);

    foreach(b; d.bigits)
        printf(">>> bigit=%d\n", b);

    assert(initial[0 .. 2] == d.bigits[0 .. 2]);
}

unittest
{
    static char[100] buf = '|';
    // Just in case of debugging using stdc:
    buf[$-1] = '\0';

    static char[] res;

    void testIt(T)(T v, string expected)
    {
        //~ res = dtoa_puff!uint(buf, v, 6);
        //~ assert(res == expected, res);

        res = dtoa_puff!ushort(buf, v, 6);
        assert(res == expected, res);
    }

    testIt(-12.345f, "-1.23450e+1");
    testIt(2.0, "2.00000e+0");
    testIt(-1.23456789101112, "-1.23457e+0");
    testIt(0.0000123456789, "1.23457e-5");
}

//~ pure:
nothrow:
@nogc:

//TODO: implement floatingToTempString()

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
    T[maxLen] bigits; //TODO: = void;

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
        const ubyte offset = bigits[0] >= (bigitBound >> n) ? 1 : 0;
        T carry;

        foreach_reverse(i; 0 .. numBigits)
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
            bigits[0] = carry;
            numBigits++;
        }
    }

    void shiftFewBitsRight(in int n)
    in(n > 0)
    in(n <= decimalExp)
    {
        enum ubyte bigitIdx = 0;

        const T mask = assumeSafeCastT((1 << n) - 1);
        T borrow;
        int offset;

        // Number was here and moved completely to the right?
        if((bigits[bigitIdx] >> n) == 0 && bigits[bigitIdx] != 0)
        {
            offset = 1;
            numBigits--;
            fractionStart--;

            borrow = assumeSafeCastT(UL(bigits[bigitIdx]) * bigitBound >> n);
        }

        foreach(i; bigitIdx .. numBigits)
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

    void addBigit(T val)
    in(val >= 0)
    in(val < bigitBound)
    {
        bigits[numBigits] = val;
        numBigits++;
    }

    //TODO: naming
    enum bool tooBig = (T.sizeof == 2 && !is(F == float));

    // A type that is guaranteed to fit a integral part
    static if(tooBig)
    {
        alias GF = ulong;

        // ulong fits 20 decimal digits
        enum intPartBigitsNum = 20 / decimalExp + (20 % decimalExp == 0 ? 0 : 1);
        static assert(intPartBigitsNum == 5);
    }
    else
    {
        alias GF = UL;
        enum intPartBigitsNum = 1;
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

        printf("mantis=%f exp=%d\n", integralPart, exp);

        const v = cast(GF) (integralPart < 0 ? -integralPart : integralPart);

        //TODO: make exp const
        exp -= numBits;

        //~ printf("numBits=%d integral part=%f ulong=%lld exp=%d value=%g\n", numBits, integralPart, v, exp, d);

        if(v >= bigitBound)
        {
            GF upper = v / bigitBound;

            //~ printf("v=%llu  upper=%llu\n", v, upper);

            // Additional division for small numbers which store large mantissa
            static if(tooBig)
            {
                auto intPartIdx = intPartBigitsNum - 1;

                while(upper >= bigitBound)
                {
                    const lessSig = upper % bigitBound;
                    bigits[intPartIdx] = lessSig;

                    upper /= bigitBound;
                    intPartIdx--;
                    fractionStart++;

                    //~ printf("while loop, upper=%llu\n", upper);
                }
            }

            addBigit(upper % bigitBound);
            fractionStart++;

            foreach(idx, b; bigits[0 .. 9])
                printf("bigit[%llu] %d\n", idx, b);
        }

        addBigit(v % bigitBound);

        if(exp >= 0)
        {
            massiveLeftShift(exp);
            fractionStart = numBigits;
        }
        else
        {
            massiveRightShift(-exp);
            fractionStart++;
        }

        printf("frac start=%d\n", fractionStart);
    }

    private static T assumeSafeCastT(V)(V val, size_t line = __LINE__)
    if(__traits(isIntegral, V))
    {
        assert(val >= 0);
        //~ printf("line: %llu\n", line);
        assert(val <= T.max);
        return cast(T) val;
    }
}

char[] dtoa_puff(T, F)(return scope char[] buf, F val, in ushort precision)
{
    auto d = Decimal!(T, 100)(val);

    uint bigitIndex;

    // Skip leading zeroes
    foreach(i; 0 .. d.intPartBigitsNum)
        if(d.bigits[i] == 0)
            bigitIndex++;
        else
            break;

    debug
    {
        import core.stdc.math: log10l;
        //TODO: templatize buf len?
        assert(buf.length >= ulong.max.log10l + 1);
    }

    // Integer part output
    uint count = to_chars(buf[0 .. precision], d.bigits[bigitIndex]);
    bigitIndex++;

    int exp = (d.fractionStart - bigitIndex) * d.decimalExp + count - 1;

    for(; bigitIndex < d.numBigits && count <= precision; bigitIndex++)
    {
        const nextBlockIdx = count + d.decimalExp;
        auto block = buf[count .. nextBlockIdx];

        const digLen = to_chars(block, d.bigits[bigitIndex]);
        assert(digLen <= d.decimalExp);
        const zLen = d.decimalExp - digLen;
        assert(zLen >= 0);

        if(zLen != 0)
        {
            //FIXME: Causes "range violation" because ranges may overlap
            //block[zLen .. d.decimalExp] = block[0 .. digLen];
            //block[0 .. zLen] = 0;

            () @trusted
            {
                import core.stdc.string: memmove, memcpy;

                memmove(&block[zLen], &block[0], digLen);
                memcpy(&block[0], "00000000".ptr, zLen);
            }();

        }

        count = nextBlockIdx;
    }

    bool has_nonzero()
    {
        for(int i = precision + 1; i < count; i++)
            if (buf[i] != '0')
                return true;

        for(int i = bigitIndex + 1; i < d.numBigits; i++)
            if (d.bigits[i] != 0)
                return true;

        return false;
    };

    if (count > precision)
    {
        const digit = buf[precision];

        if (digit > '5' || digit == '5' && ((buf[precision - 1] % 2) == 1 || has_nonzero()))
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

        count = precision;
    }

    const bool negative = val < 0;

    //TODO: replace by native D code:
    () @trusted
    {
        import core.stdc.string: memmove;
        memmove(&buf[2 + (negative ? 1 : 0)], &buf[1], count - 1);
    }();

    int offset = 1;
    if (negative)
    {
        buf[1] = buf[0];
        buf[0] = '-';
        ++offset;
    }

    buf[offset] = '.';

    for (count += offset; count <= precision; ++count)
        buf[count] = '0';

    buf[count++] = 'e';

    if(exp >= 0)
        buf[count++] = '+';
    else { /* '-' is output by the integer-to-text function */ }

    const expLen = to_chars(buf[count .. $], exp);

    return buf[0 .. count + expLen];
}

/// Same as C++ std::to_chars
private uint to_chars(T)(scope char[] buf, T val)
if(__traits(isIntegral, T))
{
    import core.internal.string;

    char[100] tmpBuf;

    static if(__traits(isUnsigned, T))
        char[] digits = unsignedToTempString(val, tmpBuf);
    else
        char[] digits = signedToTempString(val, tmpBuf);

    assert(digits.length <= buf.length);

    () @trusted
    {
        // It needs to be moved because (un)signedToTempString
        // writes from the end of the buffer
        import core.stdc.string: memmove;
        memmove(&buf[0], &digits[0], digits.length);
    }();

    return cast(uint) digits.length;
}
