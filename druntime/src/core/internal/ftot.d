/// Floating to text conversion
module core.internal.ftot;

pure:
nothrow:
@nogc:
@safe:

//TODO: implement floatingToTempString()

/// A fixed-point decimal number.
struct Decimal(size_t maxLen = 100)
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
        const int offset = *bigits >= (bigitBound >> n) ? 1 : 0;
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
            num_bigits++;
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
            borrow = ulong(bigits[0]) * bigitBound >> n;
        }

        foreach(i; 0 .. num_bigits)
        {
            ulong bigit = bigits[i + offset];
            const uint newBorrow = (bigit & mask) * bigitBound >> n;
            bigits[i] = borrow + (bigit >> n);
            borrow = newBorrow;
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
        long v = cast(long)(frexp(d, &exp) * (1UL << num_bits));

        if(v < 0) v = -v;
        exp -= num_bits;

        if(exp >= 0)
        {
            if(v >= bigitBound)
            {
                uint upper = v / bigitBound;
                if(upper != 0)
                {
                    bigits[numBigits] = upper;
                    numBigits++;
                }
            }

            bigits[numBigits] = v % bigit_bound;
            num_bigits++;

            enum bits_per_iteration = 29; // 2^^29 fits in one bigit
            int i = 0;
            for(; i <= exp - bits_per_iteration; i += bits_per_iteration)
                shiftLeft(bits_per_iteration);

            if(i != exp)
                shiftLeft(exp - i);

            fractionStart = num_bigits;
        }
        else
        {
            fractionStart = 1;

            if(v >= bigit_bound)
            {
                const uint upper = v / bigit_bound;
                if(upper != 0)
                {
                    bigits[num_bigits] = upper;
                    num_bigits++;
                    fraction_start++;
                }
            }

            bigits[num_bigits] = v % bigit_bound;
            num_bigits++;

            enum bits_per_iteration = 9; // 10^^9 can only be shifted left 9 bits
            int i = 0;
            for (; i - bits_per_iteration >= exp; i -= bits_per_iteration)
                shiftRight(bits_per_iteration);

            if (i != exp) shift_right(i - exp);
        }
    }
}

void dtoa_puff(char* buf, double val, int precision)
{
    auto d = Decimal(val);
    int bigit_index = d.bigits[0] > 0 ? 0 : 1;

    //replace by unsignedToTempString()
    char* ptr = std::to_chars(buf, buf + precision, d.bigits[bigit_index++]).ptr;

    int count = ptr - buf;
    int exp = (d.fraction_start - bigit_index) * 9 + count - 1;
    for (; bigit_index < d.num_bigits && count <= precision; ++bigit_index)
    {
        char* block = buf + count;
        ptr = std::to_chars(block, block + 9, d.bigits[bigit_index]).ptr;
        int num_digits = ptr - block, num_zeros = 9 - num_digits;
        if (num_digits < 9) {
        memmove(block + num_zeros, block, num_digits);
        memcpy(block, "00000000", num_zeros);
        }
        count += 9;
    }

auto has_nonzero = [=]() {
for (int i = precision + 1; i < count; ++i) {
if (buf[i] != '0') return true;
}
for (int i = bigit_index + 1; i < d.num_bigits; ++i) {
if (d.bigits[i] != 0) return true;
}
return false;
};
if (count > precision) {
char digit = buf[precision];
if (digit > '5' || digit == '5' &&
((buf[precision - 1] % 2) == 1 || has_nonzero())) {
int i = precision - 1;
for (; i >= 0 && buf[i] == '9'; --i) buf[i] = '0';
if (i >= 0) {
++buf[i];
} else {
buf[0] = '1';
++exp;
}
}
count = precision;
}
bool negative = signbit(val);
memmove(buf + 2 + (negative ? 1 : 0), buf + 1, count - 1);
int offset = 1;
if (negative) {
buf[1] = buf[0];
buf[0] = '-';
++offset;
}
buf[offset] = '.';
for (count += offset; count <= precision; ++count) buf[count] = '0';
buf[count++] = 'e';
if (exp >= 0) buf[count++] = '+';
*std::to_chars(buf + count, buf + count + 4, exp).ptr = '\0';
}
