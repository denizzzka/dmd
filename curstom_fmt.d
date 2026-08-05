import std;

//TODO: about maxLen: dig is short for "digits" and specifies the number of digits that signify the precision of the type.

private enum asciiNumStart = ubyte(48); // '0'

scope auto num2ascii(ubyte maxLen = 32 /* TODO: decrease or remove */, T)(T num) //TODO: nothrow @nogc pure
{
    static struct Ret
    {
        private char[maxLen] buf = 'b'; //void;
        const(char)[] slice;
        alias this = slice;
    }

    Ret ret;

    struct BufDeal
    {
        size_t currIdx;

        auto getResult()
        {
            ret.slice = ret.buf[0 .. currIdx];
            return ret;
        }

        /// Returns: unused part of the return buffer
        char[] getFreeBuf() => ret.buf[currIdx .. $];

        void appendSliceWidth(size_t append_len)
        {
            currIdx += append_len;
            assert(currIdx <= ret.buf.length);
        }

        void append(const char[] str)
        {
            const s = currIdx;
            const e = currIdx + str.length;

            appendSliceWidth(str.length);
            ret.buf[s .. e] = str;
        }

        void append(char c)
        {
            const idx = currIdx;

            appendSliceWidth(1);
            ret.buf[idx] = c;
        }
    }

    BufDeal r;

    enum isFloat = __traits(isFloating, T);

    if(num < 0)
    {
        num = -num;
        r.append('-');
    }

    static if(isFloat)
    {
        if(num != num)
        {
            r.append("nan");
            return r.getResult;
        }
        else if(num > T.max)
        {
            r.append("inf");
            return r.getResult;
        }
        else if(num < -T.max)
        {
            r.append("-inf");
            return r.getResult;
        }

        // Calculate the exponent with the appropriate shift of the decimal point
        short exponent;
        //TODO: early stop to ignore non-displayed part
        if(num >= 10)
            while(num >= 10)
            {
                num /= 10;
                exponent++;
            }
        else if (num < 1)
            while(num < 1)
            {
                num *= 10;
                exponent--;
            }
    }

    // TODO: use smaller types if it's worth it
    ulong intPart = cast(ulong) num;
    double fracPart = num - cast(double) intPart;

    if(intPart == 0)
        r.append('0');
    else
    {
        // Using unused part of the return buffer to store numbers
        char[] freeBuf = r.getFreeBuf();

        const intDigitsLen = addDigits(freeBuf, intPart);
        r.appendSliceWidth(intDigitsLen);
    }

    enum fracPrecision = 6;

    if(isFloat)
    {
        {
            char[] freeBuf = r.getFreeBuf();
            assert(freeBuf.length > 0);

            /// freeBuf index
            /// zero is reserved for decimal dot
            ubyte i = 1;
            while(i < fracPrecision)
            {
                fracPart *= 10;
                const digit = cast(ubyte) fracPart;
                freeBuf[i] = cast(char)(asciiNumStart + digit);
                fracPart -= digit;

                i++;
            }

            // Remove insignificant zeros
            if(i > 1)
                foreach_reverse(c; freeBuf[1 .. i])
                {
                    // Zero digit found
                    if(c == asciiNumStart)
                        i--;
                    else
                        break;
                }

            // Decimal dot only remained? Removes it too
            if(i == 1)
                i = 0;
            else
            {
                // Finally, dot is need, adding
                assert(i > 1);
                freeBuf[0] = '.';
            }

            r.appendSliceWidth(i);
        }

        if(exponent != 0)
        {
            if(exponent < 0)
            {
                exponent = cast(short) -exponent;
                r.append("e-");
            }
            else
                r.append("e+");

            const expLen = addDigits(r.getFreeBuf, exponent);
            r.appendSliceWidth(expLen);
        }
    }

    return r.getResult;
}

/// Appends the digits of a positive integer to the buffer
///
/// Returns: number of digits
private size_t addDigits(char[] buf, ulong integer) pure
in(integer > 0)
{
    ubyte i = 0;
    while(integer > 0)
    {
        assert(i < buf.length);

        buf[i] = asciiNumStart + integer % 10;
        integer /= 10;
        i++;
    }

    // Cut a part filled with digits
    char[] digits = buf[0 .. i];

    digits.reverseArray();

    return digits.length;
}


private void reverseArray(T)(ref T arr) pure
{
    assert(arr.length <= ubyte.max);

    size_t left = 0;
    size_t right = cast(ubyte)(arr.length - 1);

    while(left < right)
    {
        ref lval = arr[left];
        ref rval = arr[right];

        auto acc = lval;
        lval = rval;
        rval = acc;

        left++;
        right--;
    }
}

void main()
{
    //~ unittest
    {
        char[] arr = "1234567".dup;
        arr.reverseArray;
        assert(arr == "7654321".dup);
    }

    //~ unittest
    {
        static void testIt(T)(T val, const char[] expected)
        {
            auto res = val.num2ascii;
            assert(res == expected, res.idup);
        }

        //TODO: add test with leading zero
        //TODO: add tests for all numeric types (use templates)

        testIt(float(-123.45678), "-123.456779");

        //~ const r = float(-123.45678).num2ascii;
        //~ const r = float(-0.0012).num2ascii;
        //~ const r = float(-1).num2ascii;
        //~ assert(r == "-123.456779", r.to!string);

        assert(float(1).num2ascii == "1");

        assert(float.nan.num2ascii == "nan");
        assert(float.infinity.num2ascii == "inf");
        assert((-float.infinity).num2ascii == "-inf");
    }
}
