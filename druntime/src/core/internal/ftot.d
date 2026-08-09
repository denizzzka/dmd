/// Floating to text conversion
module core.internal.ftot;

unittest
{
    char[100] buf;
    dtoa_puff(buf, 123.456, 6);

    assert(false, buf);
}

pure:
nothrow:
@nogc:
@safe:

private T checkedCast(T, V)(V val)
if(__traits(isIntegral, T) && __traits(isUnsigned, T))
{
    assert(val <= T.max);
    return cast(T) val;
}

//TODO: implement floatingToTempString()

/// A fixed-point decimal number.
struct Decimal(size_t maxLen)
{
    // Each bigit is a 9-digit decimal number.
    uint[maxLen] bigits;
    //TODO: decrease type size?
    uint numBigits;
    enum bigitBound = 10 ^^ 9;
    /// Fraction part delimiter index
    uint fractionStart;

    void shiftLeft(int n)
    {
        const int offset = bigits[0] >= (bigitBound >> n) ? 1 : 0;
        uint carry;

        foreach_reverse(i, bigit; bigits)
        {
            bigit = (bigit << n) + carry;

            if(bigit < bigitBound)
                carry = 0;
            else
            {
                bigit = bigit % bigitBound;
                carry = bigit / bigitBound;
            }

            bigits[i + offset] = bigit;
        }

        if(offset != 0)
        {
            bigits[0] = carry;
            numBigits++;
        }
    }

    void shiftRight(int n)
    {
        const uint mask = (1 << n) - 1;
        uint borrow;
        int offset;

        if((bigits[0] >> n) == 0 && bigits[0] != 0)
        {
            offset = 1;
            numBigits--;
            fractionStart--;

            borrow = (ulong(bigits[0]) * bigitBound >> n).checkedCast!uint;
        }

        foreach(i; 0 .. numBigits)
        {
            //TODO: why ulong?
            const ulong bigit = bigits[i + offset];

            bigits[i] = (borrow + (bigit >> n)).checkedCast!uint;
            borrow = ((bigit & mask) * bigitBound >> n).checkedCast!uint;
        }

        if(borrow != 0)
        {
            bigits[numBigits] = borrow;
            numBigits++;
        }
    }

    // TODO: remove
    private int expTmp;

    this(double d)
    {
        //TODO: replace libc call by core.internal.convert
        import core.stdc.math: frexp;

        enum numBits = double.dig;
        const e4l = frexp(d, &expTmp) * (1UL << numBits);
        long v = cast(long) e4l;

        if(v < 0)
            v = -v;

        const int exp = expTmp - numBits;

        if(exp >= 0)
        {
            if(v >= bigitBound)
            {
                const uint upper = (v / bigitBound).checkedCast!uint;
                if(upper != 0)
                {
                    bigits[numBigits] = upper;
                    numBigits++;
                }
            }

            bigits[numBigits] = (v % bigitBound).checkedCast!uint;
            numBigits++;

            enum bits_per_iteration = 29; // 2^^29 fits in one bigit
            assert(exp >= bits_per_iteration);

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
                const uint upper = (v / bigitBound).checkedCast!uint;
                if(upper != 0)
                {
                    bigits[numBigits] = upper;
                    numBigits++;
                    fractionStart++;
                }
            }

            bigits[numBigits] = (v % bigitBound).checkedCast!uint;
            numBigits++;

            enum bits_per_iteration = 9; // 10^^9 can only be shifted left 9 bits
            //FIXME:
            //~ assert(exp >= bits_per_iteration);

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
}

void dtoa_puff(char[] buf, double val, in ushort precision)
{
    import core.internal.string: unsignedToTempString;

    auto d = Decimal!100(val);

    //TODO: I don't know what is this conditional does yet
    uint bigitIndex = d.bigits[0] > 0 ? 0 : 1;

    debug
    {
        import core.stdc.math: log10l;
        assert(buf.length >= ulong.max.log10l + 1);
    }

    const char[] intPart = unsignedToTempString(d.bigits[bigitIndex], buf[0 .. precision]);
    bigitIndex++;

    uint count = precision;
    int exp = (d.fractionStart - bigitIndex) * 9 + count - 1;

    for(; bigitIndex < d.numBigits && count <= precision; bigitIndex++)
    {
        const nextBlockIdx = count + 9;
        auto block = buf[count .. nextBlockIdx];
        const char[] digits = unsignedToTempString(d.bigits[bigitIndex], block);

        //FIXME:
        //~ if(digits.length < 9)
        //~ {
            //~ memmove(block + num_zeros, block, num_digits);
            //~ memcpy(block, "00000000", num_zeros);
        //~ }

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
    //FIXME:
    //~ memmove(buf + 2 + (negative ? 1 : 0), buf + 1, count - 1);

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

    if (exp >= 0)
        buf[count++] = '+';

    //FIXME:
    //~ *std::to_chars(buf + count, buf + count + 4, exp).ptr = '\0';
}
