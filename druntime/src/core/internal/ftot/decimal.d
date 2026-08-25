///
module core.internal.ftot.decimal;

//~ pure:
//~ nothrow:
//~ @nogc:
//~ @safe:

package:

import core.stdc.stdio: printf; //TODO: remove

mixin template Estimation(BigitT)
if(is(BigitT == ushort) || is(BigitT == uint))
{
    // Set decimal exponent. The most effective is to use
    // the largest power of 10 that is less than T.max.
    static if(BigitT.sizeof == 4)
    {
        enum decimalExp = 9; // 10^9 - largest decimal number less than 32-bit value
        enum bigitBitWidth = 29; // 2^29 - largest binary number less than 10^9
        alias UL = ulong; // Twice longer than BigitT
    }
    else static if(BigitT.sizeof == 2)
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

mixin template BufSizeCalculation(BigitT, F)
if(__traits(isFloating, F))
{
    enum isNotReal = !is(F == real) ||
        (
            real.mant_dig == double.mant_dig
            && real.min_10_exp == double.min_10_exp
            && real.max_10_exp == double.max_10_exp
        );

    mixin Estimation!BigitT;

    // Floating value fits into two bigits?
    static if(is(F == float) || (UL.sizeof == 8 && isNotReal))
    {
        /// A type that is guaranteed to fit a integral part of floating T
        alias GF = UL;

        /// Bigits number needed to fit GF
        enum intPartBigitsNum = 2;
    }
    else
    {
        alias GF = ulong;

        /// Maximum number of decimal digits in the ulong type
        private enum ulongMaxDigits = 20;

        static if(isNotReal)
        {
            private enum maxDigits = ulongMaxDigits;
            enum intPartBigitsNum = maxDigits / decimalExp + (maxDigits % decimalExp == 0 ? 0 : 1);
            static assert(intPartBigitsNum == 5);
        }
        else
        {
            // Special case for "true" real (other than double)
            private enum bits = bigitBitWidth;
            private enum intPartBigitsNum = real.mant_dig / bits + (real.mant_dig % bits == 0 ? 0 : 1);
        }
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

    // TODO: remove
    private int exp;

    this(F)(F d)
    if(__traits(isFloating, F))
    {
        import core.stdc.math;

        mixin BufSizeCalculation!(T, F);

        enum numBits = d.mant_dig;
        //TODO: remove
        enum isNotReal = !is(F == real) ||
            (
                real.mant_dig == double.mant_dig
                && real.min_10_exp == double.min_10_exp
                && real.max_10_exp == double.max_10_exp
            );

        static if(is(F == float))
            const integralPart = frexpf(d, &exp) * (1U << numBits);
        else static if(is(F == double) || isNotReal)
            const integralPart = frexp(cast(double) d, &exp) * (1UL << numBits);
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
            while(true)
            {
                assert(intPartIdx > 0);
                intPartIdx--;

                const lessSig = v % bigitBound;
                v /= bigitBound;

                bigitsArr[intPartIdx] = lessSig;
                numBigits++;

                printf("lessSig added: %d to pos=%d intPartBigitsNum=%d\n", cast(int)lessSig, intPartIdx, intPartBigitsNum);

                if(v == 0)
                    break;
            }
        }

        static if(isNotReal)
        {
            auto v = cast(GF) (integralPart < 0 ? -integralPart : integralPart);
            addIntPartAsInteger(v);
        }
        else
        {{
            // Fetch unsigned values from a big mantiss

            //TODO: first shift integer result is 0 and can be replaced by zero const
            short shift = F.mant_dig;

            while(true)
            {
                printf("shift=%d mant=%Lf\n", shift, mant);

                if(shift == 0)
                {
                    const word = cast(GF) mant;
                    addIntPartAsInteger(word);
                    break;
                }

                const scaled = ldexpl(mant, shift);
                const word = cast(GF) scaled;
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
