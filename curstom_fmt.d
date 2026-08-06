import std;

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
        assert(float(1).num2ascii == "1");
        assert(float.nan.num2ascii == "nan");
        assert(float.infinity.num2ascii == "inf");
        assert((-float.infinity).num2ascii == "-inf");

        static void testIt(T)(T val, const bool expForm, const char[] expected, size_t line = __LINE__)
        {
            auto res = num2ascii(val, expForm);
            assert(res == expected, /*"Line:"~line.num2ascii.idup~" "~*/ res.idup);
        }

        //TODO: add test with leading zero
        //TODO: add tests for all numeric types (use templates)

        testIt(float(-123.45678), false, "-123.456779");
        testIt(float(-123.45678), true,  "-1.234567e+02");
        testIt(float(-123.45678), true,  "-1.234567e+02");
        testIt(int(-123), true,  "-123");
    }
}

//TODO: about maxLen: dig is short for "digits" and specifies the number of digits that signify the precision of the type.

private enum asciiNumStart = ubyte(48); // '0'

scope auto num2ascii(ubyte maxLen = 32 /* TODO: decrease or remove */, T)(T num, const bool expForm = false) pure nothrow @nogc
{
    static struct Ret
    {
        private char[maxLen] buf = 'b'; //void;
        const(char)[] slice;
        alias this = slice;

        auto getResult(ref BufMethods m)
        {
            slice = buf[0 .. m.currIdx];
            return this;
        }
    }

    Ret ret;
    auto m = BufMethods(ret.buf);

    enum isFloat = __traits(isFloating, T);

    if(num < 0)
    {
        num = -num;
        m.append('-');
    }

    static if(isFloat)
    {
        if(num != num)
        {
            m.append("nan");
            return ret.getResult(m);
        }
        else if(num > T.max)
        {
            m.append("inf");
            return ret.getResult(m);
        }
        else if(num < -T.max)
        {
            m.append("-inf");
            return ret.getResult(m);
        }

        byte exponent;

        if(expForm)
            exponent = calcExp(num, num);
    }

    // TODO: use smaller types if it's worth it
    ulong intPart = cast(ulong) num;
    double fracPart = num - cast(double) intPart;

    if(intPart == 0)
        m.append('0');
    else
    {
        // Using unused part of the return buffer to store numbers
        char[] freeBuf = m.getFreeBuf();

        const intDigitsLen = addDigits(freeBuf, intPart);
        m.appendSliceWidth(intDigitsLen);
    }

    enum fracPrecision = 7;

    if(isFloat)
    {
        {
            char[] freeBuf = m.getFreeBuf();
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

            m.appendSliceWidth(i);
        }

        static if(isFloat) if(exponent != 0)
        {
            if(exponent < 0)
            {
                exponent = cast(byte) -exponent;
                m.append("e-");
            }
            else
                m.append("e+");

            // Add two digits of exponent value
            assert(exponent <= 99);
            char[2] expBuf = [
                asciiNumStart + exponent / 10,
                asciiNumStart + exponent % 10,
            ];
            m.append(expBuf);
        }
    }

    return ret.getResult(m);
}

private struct BufMethods
{
    nothrow:
    @nogc:
    pure:

    char[] buf;
    size_t currIdx;

    this(char[] b)
    {
        buf = b;
    }

    /// Returns: unused part of the return buffer
    char[] getFreeBuf() => buf[currIdx .. $];

    void appendSliceWidth(size_t append_len)
    {
        currIdx += append_len;
        assert(currIdx <= buf.length);
    }

    void append(Arr)(const Arr str)
    {
        const s = currIdx;
        const e = currIdx + str.length;

        appendSliceWidth(str.length);
        buf[s .. e] = str;
    }

    void append(char c)
    {
        const idx = currIdx;

        appendSliceWidth(1);
        buf[idx] = c;
    }
}

pure:
nothrow:
@nogc:

/// Calculates the exponent with the appropriate shift of the decimal point
private byte calcExp(T)(in T num, out T shifted)
if(__traits(isFloating, T))
{
    enum thresUpper = 10.0f;
    enum thresLower = 1.0f / thresUpper;

    shifted = num;
    byte exponent;

    //TODO: early stop to ignore non-displayed part
    if(num >= thresUpper)
        while(shifted >= thresUpper)
        {
            shifted /= 10;
            exponent++;
        }
    else if (num < thresLower)
        while(shifted < thresLower)
        {
            shifted *= 10;
            exponent--;
        }

    return exponent;
}

/// Appends the digits of a positive integer to the buffer
///
/// Returns: number of digits
private size_t addDigits(char[] buf, ulong integer)
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


private void reverseArray(T)(ref T arr)
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
