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
        static void testIt(T)(T val, string phobos_std, string phobos_exp)
        {
            const asPhobosStd = floatingToTempString(val, Format.Std);
            const asPhobosExp = floatingToTempString(val, Format.Exp);

            //TODO: remove
            writeln("=================================");
            writeln("Phobos return: ", val);
            writefln("Phobos exp form: %e", val);

            assert(asPhobosStd == phobos_std, `"`~asPhobosStd~`" but expected "`~phobos_std~`" (as prints writeln())`);
            assert(asPhobosExp == phobos_exp, `"`~asPhobosExp~`" but expected "`~phobos_exp~`" (as prints writefln())`);

            static string getLibcText(T val, bool expForm)
            {
                import core.stdc.stdio: snprintf;

                const fmt = expForm ? "%e" : "%f";

                char[256] buf = 'a';
                const len = snprintf(buf.ptr, buf.length, &fmt[0], val);
                return buf[0 .. len].idup;
            }

            const stdcTextStd = getLibcText(val, false);
            const stdcTextExp = getLibcText(val, true);

            const asLibcStd = floatingToTempString(val, Format.StdLibc);
            const asLibcExp = floatingToTempString(val, Format.ExpLibc);

            assert(asLibcStd == stdcTextStd, `"`~asLibcStd~`" but stdc snprintf() returns: "`~stdcTextStd~`"`);
            assert(asLibcExp == stdcTextExp, `"`~asLibcExp~`" but stdc snprintf() returns: "`~stdcTextExp~`"`);
        }

        // Test on all posible types
        static void onAll(T, ARGS...)(T val, ARGS args)
        {
            static if(T.dig <= float.dig)
                testIt(cast(float) val, args);
            else static if(T.dig <= double.dig)
                testIt(cast(double) val, args);
            else static if(T.dig <= real.dig)
                testIt(cast(real) val, args);
        }

        //TODO: add test with leading zero
        //TODO: add tests for all numeric types

        onAll(1.0f, "1", "1.0e+00");
        onAll(0.0f, "0", "0.0e+00");
        onAll(float.nan, "nan", "nan");
        onAll(float.infinity, "inf", "inf");
        onAll(-float.infinity, "-inf", "-inf");
        onAll(-123.45678f, "-123.456779" /* FIXME: should be -123.456 */, "-1.234568e+02");
        onAll(1e3, "1000", "1.0e+03" /* FIXME: should be 1e+03 */);
        //~ onAll(1e-3, "0.001", "1.0e-03" /* FIXME: should be 1e-03 */);

        //~ onAll(float(1.0e3), true,  "1.000000e+03");
        //~ onAll(double(-1.0e-308), true,  "-1.000000e-308");
    }
}

//TODO: about maxLen: dig is short for "digits" and specifies the number of digits that signify the precision of the type.

private enum asciiNumStart = ubyte(48); // '0'

enum Format : ubyte
{
    Std,
    Exp,
    StdLibc,
    ExpLibc,
}

auto floatingToTempString(ubyte maxLen = 32 /* TODO: decrease or remove */, T)(T num, const Format format) //pure nothrow @nogc
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

        const expForm = (format == Format.Exp || format == Format.ExpLibc);
        short exponent;

        assert(num >= 0);
        if(expForm && num > 0)
            exponent = calcExp(num, num);
    }

    // TODO: use smaller types if it's worth it
    ulong intPart = cast(ulong) num;
    double fracPart = num - intPart;

    //TODO: use appropriate integer types:
    enum fracPrecision = 6;
    enum ulong indent = 10 ^^ (fracPrecision + 1 /* additional digit for rounding */);

    // Scale to integer
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
    writeln("format=", format);
    writeln("fracPart=", fracPart);
    writeln("exponent=", exponent);
    writeln("indent=", indent);
    writeln("fracPart * indent=", fracPart * indent);

    // Making output:
    if(intPart == 0)
        m.append('0');
    else
    {
        // Using unused part of the return buffer to store numbers
        char[] freeBuf = m.getFreeBuf();

        const intDigitsLen = addDigits(freeBuf, intPart);
        m.appendSliceWidth(intDigitsLen);
    }

    char[] freeBuf = m.getFreeBuf();
    assert(freeBuf.length > 0);

    auto i = 1 /* dot place */ + addDigits(freeBuf[1 .. $], fracAsInteger);

    const libcCompat = (format == Format.StdLibc || format == Format.ExpLibc);

    if(format == Format.Exp || libcCompat)
    {
        freeBuf[0] = '.';

        if(libcCompat)
        {
            // complete value with zeros to comply with glibc output
            const len = 1 + fracPrecision;
            freeBuf[i .. len] = '0';
            i = len;
        }
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
in(num > 0)
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
