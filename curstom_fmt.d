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
        assert(float(0).num2ascii == "0");
        assert(float(1).num2ascii == "1");
        assert(float.nan.num2ascii == "nan");
        assert(float.infinity.num2ascii == "inf");
        assert((-float.infinity).num2ascii == "-inf");

        static void testIt(T)(T val, const bool expForm, const char[] expected, size_t line = __LINE__)
        {
            const res = num2ascii(val, expForm);

            {
                import core.stdc.stdio: snprintf;

                const fmt = expForm ? "%e" : "%f";

                char[256] buf = 'a';
                const len = snprintf(buf.ptr, buf.length, &fmt[0], val);
                const stdc_str = buf[0 .. len];

                //TODO: remove line num
                assert(res.slice == stdc_str, `"`~res.slice~`" but stdc returns: "`~stdc_str~`"`);
            }

            //TODO: remove line num
            assert(res == expected, `"`~res~`" but expected: "`~expected~`"`);
        }

        //TODO: add test with leading zero
        //TODO: add tests for all numeric types

        testIt(float(-123.45678), false, "-123.456779");
        testIt(float(-123.45678), true,  "-1.234568e+02");
        testIt(float(1.0e3), true,  "1.000000e+03");
        testIt(double(-1.0e-308), true,  "-1e-308");
    }
}

//TODO: about maxLen: dig is short for "digits" and specifies the number of digits that signify the precision of the type.

private enum asciiNumStart = ubyte(48); // '0'

auto num2ascii(ubyte maxLen = 32 /* TODO: decrease or remove */, T)(T num, const bool expForm = false) //pure nothrow @nogc
if(__traits(isFloating, T))
{
    static struct Ret
    {
        private char[maxLen] buf = 'b'; //void;
        const(char)[] slice;
        alias this = slice;

        @disable this(ref Ret);
    }

    Ret ret;
    auto m = BufMethods(ret.buf);

    void setResult()
    {
        ret.slice = ret.buf[0 .. m.currIdx];
    }

    if(num < 0)
    {
        num = -num;
        m.append('-');
    }

    version(all) //TODO: remove
    {
        if(num != num)
        {
            m.append("nan");
            setResult();
            return ret;
        }
        else if(num > T.max)
        {
            m.append("inf");
            setResult();
            return ret;
        }
        else if(num < -T.max)
        {
            m.append("-inf");
            setResult();
            return ret;
        }

        short exponent;

        if(expForm)
            exponent = calcExp(num, num);
    }

    // TODO: use smaller types if it's worth it
    ulong intPart = cast(ulong) num;
    double fracPart = num - intPart;

    if(intPart == 0)
        m.append('0');
    else
    {
        // Using unused part of the return buffer to store numbers
        char[] freeBuf = m.getFreeBuf();

        const intDigitsLen = addDigits(freeBuf, intPart);
        m.appendSliceWidth(intDigitsLen);
    }

    enum fracPrecision = 6;

    version(all) //TODO: remove
    {
        {
            char[] freeBuf = m.getFreeBuf();
            assert(freeBuf.length > 0);

            enum ulong indent = 10 ^^ (fracPrecision + 1 /* additional digit for rounding */);

            // Scale to integer
            //TODO: use appropriate integer type
            auto fracAsInteger = cast(ulong)(fracPart.abs * indent);

            writeln("======");
            writeln("fracAsInteger before rounding=", fracAsInteger);

            // Rounding
            {
                if(fracAsInteger % 10 > 5)
                    fracAsInteger += 10;

                writeln("fracAsInteger rounded but wo carrying=", fracAsInteger);

                if(fracAsInteger < indent)
                    fracAsInteger /= 10;
                else
                {
                    // Carrying to integral part:
                    writeln("carry branch");
                    intPart += 1;
                    writeln("fracAsInteger befor carrying=", fracAsInteger);
                    fracAsInteger -= indent;
                    fracAsInteger /= 100;
                }
            }

            writeln("fracAsInteger=", fracAsInteger);
            writeln("expForm=", expForm);
            writeln("fracPart=", fracPart);
            writeln("exponent=", exponent);
            writeln("indent=", indent);
            writeln("fracPart * indent=", fracPart * indent);

            auto i = 1 /* dot place */ + addDigits(freeBuf[1 .. $], fracAsInteger);

            if(expForm)
            {
                freeBuf[0] = '.';

                // complete value with zeros to comply with glibc output
                // TODO: optional?
                const len = 1 + fracPrecision;
                freeBuf[i .. len] = '0';
                i = len;
            }
            else
            {
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
            }

            m.appendSliceWidth(i);
        }

        if(expForm)
        {
            if(exponent < 0)
            {
                exponent = cast(short) -exponent;
                m.append("e-");
            }
            else
                m.append("e+");

            if(T.max_10_exp >= 100 && exponent >= 100)
            {
                const len = addDigits(m.getFreeBuf, exponent);
                assert(len == 3);
                m.appendSliceWidth(3);
            }
            else
            {
                char[2] expBuf = [
                    cast(ubyte)(asciiNumStart + exponent / 10),
                    cast(ubyte)(asciiNumStart + exponent % 10),
                ];
                m.append(expBuf);
            }
        }
    }

    setResult();
    return ret;
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
private short calcExp(T)(in T num, out T shifted)
if(__traits(isFloating, T))
{
    enum thresUpper = 10.0f;
    enum thresLower = 1.0f / thresUpper;

    shifted = num;
    short exponent;

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
//TODO: use core.internal.string.signedToTempString instead
private size_t addDigits(char[] buf, ulong integer)
{
    ubyte i = 0;
    do
    {
        assert(i < buf.length);

        buf[i] = asciiNumStart + integer % 10;
        integer /= 10;
        i++;
    }
    while(integer > 0);

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
