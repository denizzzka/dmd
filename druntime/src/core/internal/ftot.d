/// Floating to text conversion
module core.internal.ftot;

import core.stdc.stdio;

//~ @safe:

unittest
{
    double val = 123.456;
    auto d = Decimal!(uint, 16)(val);
    assert(d.numBigits == 7);

    const initial = d.bigits.idup;

    // Shift right to 32 bits:
    d.shiftRight(1);
    d.shiftRight(2);
    d.shiftRight(5);
    d.shiftRight(8);
    d.shiftRight(8);
    d.shiftRight(8);

    //~ assert(d.numBigits == 4);

    //~ const onRightSide = d.bigits.idup;
    foreach(b; d.bigits)
        printf(">>>Rbigit=%d\n", b);

    // Shift left to the initial state:
    d.shiftLeft(1);
    d.shiftLeft(2);
    d.shiftLeft(5);
    d.shiftLeft(8);
    d.shiftLeft(16);

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
        res = dtoa_puff!uint(buf, v, 6);
        assert(res == expected, res);

        res = dtoa_puff!ushort(buf, v, 6);
        assert(res == expected, res);
    }

    testIt(-12.345f, "-1.23450e+1");
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
    // Each bigit is a 9-digit decimal number.
    T[maxLen] bigits; //TODO: = void;

    // Set decimal exponent. The most effective is to use
    // the largest power of 10 that is less than T.max.
    static if(T.sizeof == 4)
    {
        enum decimalExp = 9;
        alias UL = ulong; // Twice longer than T
    }
    else static if(T.sizeof == 2)
    {
        enum decimalExp = 4;
        alias UL = uint;
    }

    /// Radix
    enum T bigitBound = 10 ^^ decimalExp;

    //TODO: decrease type size?
    uint numBigits;
    int fractionStart;

    private enum maxLeftShift =  T.sizeof * 8 - 2; //FIXME why -2

    void shiftLeft(in int n)
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

    void shiftRight(in int n)
    in(n > 0)
    in(n <= decimalExp)
    {
        const T mask = assumeSafeCastT((1 << n) - 1);
        T borrow;
        int offset;

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

    // TODO: remove
    private int exp;

    this(F)(F d)
    if(__traits(isFloating, F))
    {
        //TODO: replace libc call by core.internal.convert
        import core.stdc.math: frexp;

        enum numBits = d.mant_dig;
        const integralPart = frexp(d, &exp) * (1UL << numBits);
        const v = cast(ulong) (integralPart < 0 ? -integralPart : integralPart);

        printf("prev exp=%d\n", exp);

        //TODO: make exp const
        exp -= numBits;

        //~ printf("numBits=%d integral part=%f ulong=%lld exp=%d value=%g\n", numBits, integralPart, v, exp, d);

        if(exp >= 0)
        {
            if(v >= bigitBound)
            {
                const T upper = assumeSafeCastT(v / bigitBound);
                if(upper != 0)
                {
                    bigits[numBigits] = upper;
                    numBigits++;
                }
            }

            bigits[numBigits] = assumeSafeCastT(v % bigitBound);
            numBigits++;

            enum bits_per_iteration = maxLeftShift;

            int i = 0;
            for(; i <= exp - bits_per_iteration; i += bits_per_iteration)
                shiftLeft(bits_per_iteration);

            if(i != exp)
            {
                assert(exp > i);
                shiftLeft(exp - i);
            }

            fractionStart = numBigits;
        }
        else
        {
            fractionStart = 1;

            if(v >= bigitBound)
            {
                const T upper = assumeSafeCastT(v / bigitBound); // FIXME: fails here on 16-bit
                if(upper != 0)
                {
                    bigits[numBigits] = upper;
                    numBigits++;
                    fractionStart++;
                }
            }

            bigits[numBigits] = assumeSafeCastT(v % bigitBound);
            numBigits++;

            enum bits_per_iteration = decimalExp;

            int i = 0;
            for (; i - bits_per_iteration >= exp; i -= bits_per_iteration)
                shiftRight(bits_per_iteration);

            if (i != exp)
            {
                assert(i > exp);
                shiftRight(i - exp);
            }
        }
    }

    private static T assumeSafeCastT(V)(V val, size_t line = __LINE__)
    if(__traits(isIntegral, V))
    {
        assert(val >= 0);
        printf("line: %llu\n", line);
        assert(val <= T.max);
        return cast(T) val;
    }
}

char[] dtoa_puff(T, F)(return scope char[] buf, F val, in ushort precision)
{
    auto d = Decimal!(T, 100)(val);

    //TODO: I don't know what is this conditional does yet
    uint bigitIndex = d.bigits[0] > 0 ? 0 : 1;

    debug
    {
        import core.stdc.math: log10l;
        //TODO: templatize buf len?
        assert(buf.length >= ulong.max.log10l + 1);
    }

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
