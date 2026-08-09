/// Floating to text conversion
module core.internal.ftot;

pure:
nothrow:
@nogc:
//~ @safe: FIXME

//TODO: implement floatingToTempString()

/// A fixed-point decimal number.
struct Decimal(size_t maxLen)
{
    // Each bigit is a 9-digit decimal number.
    uint[maxLen] bigits;
    //TODO: decrease type size?
    size_t numBigits;
    enum bigitBound = 10 ^^ 9;
    /// Fraction part delimiter index
    size_t fractionStart;

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

            const newBorrow = ulong(bigits[0]) * bigitBound >> n;
            assert(newBorrow <= borrow.max);
            borrow = cast(uint) newBorrow;
        }

        foreach(i; 0 .. numBigits)
        {
            const ulong bigit = bigits[i + offset];

            //TODO: use some sort of "checked cast"?
            bigits[i] = cast(uint)(borrow + (bigit >> n));

            const newBorrow = (bigit & mask) * bigitBound >> n;
            assert(newBorrow <= borrow.max);
            borrow = cast(uint) newBorrow;
        }

        if(borrow != 0)
        {
            bigits[numBigits] = borrow;
            numBigits++;
        }
    }

    this(double d)
    {
        int exp;
        //TODO: remove?
        enum numBits = double.dig;
        //FIXME:
        //~ long v = cast(long)(frexp(d, &exp) * (1UL << num_bits));
        long v;

        if(v < 0)
            v = -v;

        //TODO: move to exp init
        exp -= numBits;

        if(exp >= 0)
        {
            if(v >= bigitBound)
            {
                //TODO: add check to cast
                uint upper = cast(uint)(v / bigitBound);
                if(upper != 0)
                {
                    bigits[numBigits] = upper;
                    numBigits++;
                }
            }

            bigits[numBigits] = cast(uint)(v % bigitBound);
            numBigits++;

            enum bits_per_iteration = 29; // 2^^29 fits in one bigit
            int i = 0;
            for(; i <= exp - bits_per_iteration; i += bits_per_iteration)
                shiftLeft(bits_per_iteration);

            if(i != exp)
                shiftLeft(exp - i);

            fractionStart = numBigits;
        }
        else
        {
            fractionStart = 1;

            if(v >= bigitBound)
            {
                const uint upper = cast(uint)(v / bigitBound);
                if(upper != 0)
                {
                    bigits[numBigits] = upper;
                    numBigits++;
                    fractionStart++;
                }
            }

            bigits[numBigits] = cast(uint)(v % bigitBound);
            numBigits++;

            enum bits_per_iteration = 9; // 10^^9 can only be shifted left 9 bits
            int i = 0;
            for (; i - bits_per_iteration >= exp; i -= bits_per_iteration)
                shiftRight(bits_per_iteration);

            if (i != exp)
                shiftRight(i - exp);
        }
    }
}

void dtoa_puff(char[] buf, double val, int precision)
{
    import core.internal.string: unsignedToTempString;

    auto d = Decimal!100(val);
    int bigit_index = d.bigits[0] > 0 ? 0 : 1;

    debug
    {
        import core.stdc.math: log10;
        assert(buf.length >= ulong.max.log10 + 1);
    }

    const char[] intPart = unsignedToTempString(d.bigits[bigit_index], buf);
    bigit_index++;

    size_t count = intPart.length; //FIXME: remove
    int exp = cast(int)((d.fractionStart - bigit_index) * 9 + count - 1); //FIXME

    for (; bigit_index < d.numBigits && count <= precision; ++bigit_index)
    {
        //FIXME:
        //~ char* block = buf + count;
        //FIXME:
        //~ ptr = std::to_chars(block, block + 9, d.bigits[bigit_index]).ptr;
        //~ int num_digits = ptr - block, num_zeros = 9 - num_digits;
        int num_digits; //FIXME: remove
        if (num_digits < 9) {
        //~ memmove(block + num_zeros, block, num_digits);
        //~ memcpy(block, "00000000", num_zeros);
        }
        count += 9;
    }

    bool has_nonzero()
    {
        for(int i = precision + 1; i < count; i++)
            if (buf[i] != '0')
                return true;

        for(int i = bigit_index + 1; i < d.numBigits; i++)
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

unittest
{
    char[1000] buf;
    dtoa_puff(buf, 123.456, 6);
}
