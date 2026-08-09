/// Floating to text conversion
module core.internal.ftot;

//~ @safe:

unittest
{
    import core.stdc.stdio;

    double val = 123.456;
    auto d = Decimal!16(val);
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
    static char[100] buf = '|'; buf[$-1] = '\0'; //TODO: = void;
    static char[] res;
    res = dtoa_puff(buf, 0.0000123456789101112, 30);

    import core.stdc.stdio;
    printf("%s\n", buf.ptr);

    assert(false, res);
}

//~ pure:
nothrow:
@nogc:

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
    uint[maxLen] bigits; //TODO: = void;
    //TODO: decrease type size?
    uint numBigits;
    enum bigitBound = 10 ^^ 9;
    /// Fraction part delimiter index
    int fractionStart;

    void shiftLeft(in uint n)
    in(n <= 29)
    {
        const ubyte offset = bigits[0] >= (bigitBound >> n) ? 1 : 0;
        uint carry;

        foreach_reverse(i; 0 .. numBigits)
        {
            ulong bigit = bigits[i];
            bigit = (bigit << n) + carry;

            if(bigit < bigitBound)
                carry = 0;
            else
            {
                carry = (bigit / bigitBound).checkedCast!uint;
                bigit = bigit % bigitBound;
            }

            bigits[i + offset] = bigit.checkedCast!uint;
        }

        if(offset != 0)
        {
            bigits[0] = carry;
            numBigits++;
        }
    }

    void shiftRight(in uint n)
    in(n <= 9)
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
            const ulong bigit = bigits[i + offset];

            bigits[i] = borrow + (bigit >> n).checkedCast!uint;
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

        enum numBits = d.mant_dig;
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
            //FIXME:
            //~ assert(exp >= bits_per_iteration);

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

char[] dtoa_puff(return scope char[] buf, double val, in ushort precision)
{
    auto d = Decimal!100(val);

    //TODO: I don't know what is this conditional does yet
    uint bigitIndex = d.bigits[0] > 0 ? 0 : 1;

    debug
    {
        import core.stdc.math: log10l;
        assert(buf.length >= ulong.max.log10l + 1);
    }

    uint count = to_chars(buf[0 .. precision], d.bigits[bigitIndex]);
    bigitIndex++;

    int exp = (d.fractionStart - bigitIndex) * 9 + count - 1;

    for(; bigitIndex < d.numBigits && count <= precision; bigitIndex++)
    {
        const nextBlockIdx = count + 9;
        auto block = buf[count .. nextBlockIdx];

        const digLen = to_chars(block, d.bigits[bigitIndex]);
        const zLen = 9 - digLen;
        assert(zLen >= 0);

        if(zLen != 0)
        {
            block[zLen .. 9] = block[0 .. digLen];
            block[0 .. zLen] = 0;
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

    if (exp >= 0)
        buf[count++] = '+';

    const expLen = to_chars(buf[count .. $], exp);

    return buf[0 .. count + expLen];
}

/// Same as C++ std::to_chars
//TODO: remove
private uint to_chars(scope char[] buf, ulong val)
{
    import core.internal.string: unsignedToTempString;

    char[100] tmpBuf;
    char[] digits = unsignedToTempString(val, tmpBuf);
    assert(digits.length <= buf.length);

    () @trusted
    {
        import core.stdc.string: memmove;
        memmove(&buf[0], &digits[0], digits.length);
    }();

    return cast(uint) digits.length;
}
