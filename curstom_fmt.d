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
            //~ const asPhobosExp = floatingToTempString(val, Format.Exp);

            //TODO: remove
            writeln("=================================");
            writeln("Phobos return: ", val);
            writefln("Phobos exp form: %e", val);

            assert(asPhobosStd == phobos_std, `"`~asPhobosStd~`" but expected "`~phobos_std~`" (as prints writeln())`);
            //~ assert(asPhobosExp == phobos_exp, `"`~asPhobosExp~`" but expected "`~phobos_exp~`" (as prints writefln())`);

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

        //~ onAll(1.0f, "1", "1.0e+00");
        //~ onAll(0.0f, "0", "0.0e+00");
        //~ onAll(float.nan, "nan", "nan");
        //~ onAll(float.infinity, "inf", "inf");
        //~ onAll(-float.infinity, "-inf", "-inf");
        //~ onAll(-123.45678f, "-123.456779" /* FIXME: should be -123.456 */, "-1.234568e+02");
        //~ onAll(1e3f, "1000", "1.0e+03" /* FIXME: should be 1e+03 */);
        //~ onAll(0.001f, "0.001", "1.0e-03" /* FIXME: should be 1e-03 */);
        //~ onAll(1000.0f, "1000", "1.0e+03" /* FIXME: should be 1e+03 */);
        //~ onAll(0.001f, "0.001", "1.0e-03");
        onAll(0.0001f, "0.0001", "1.0e-04");
        //~ onAll(double(-1.0e-8), "errrr 111", "errrr xxxxx");
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

auto floatingToTempString(T)(T num, const Format format) //pure nothrow @nogc
if(__traits(isFloating, T))
{
    enum maxExp = T.max_10_exp > -T.min_10_exp
        ? T.max_10_exp
        : -T.min_10_exp;

    //TODO: decrease buffer size for expForm like -1.000000e-308
    enum maxLen = maxExp + ".e+123".length;

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

        if(num < 0)
        {
            num = -num;
            m.append('-');
        }
    }

    const expForm = (format == Format.Exp || format == Format.ExpLibc);

    //TODO: move it closer to usage place?
    short exponent;

    if(expForm)
        exponent = calcExp(num, num);
    else
    {
        T unused;
        exponent = calcExp(num, unused);
    }

    // TODO: use smaller types if it's worth it
    ulong intPart = cast(ulong) num;
    double fracPart = num - intPart;
    assert(fracPart >= 0);

    writeln("+++========================");
    writeln("fracPart before rounding=", fracPart);

    /// Precision after dot
    const short fracPrecision = 6;

    // Rounding
    assert(fracPart < 1);
    bool carry;
    const fracAsInteger = round(fracPart, fracPrecision, carry);

    // Apply possible carry to an integer part
    if(carry)
    {
        writeln("Carry!");
        intPart += carry;
        fracPart -= carry;
        exponent--;
    }

    writeln("format=", format);
    writeln("fracAsInteger=", fracAsInteger);
    writeln("exponent=", exponent);

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

    // Output fractional part:
    char[] freeBuf = m.getFreeBuf();
    assert(freeBuf.length > 0);

    size_t i = 1; /* skip dot place */

    // Zeroes after dot before fractional part for values less than 1
    if(!expForm && exponent < 0)
    {
        const len = -exponent - 1;
        foreach(ref c; freeBuf[i .. i+len])
            c = '0';

        i += len;
    }

    i += addDigits(freeBuf[i .. $], fracAsInteger);
    writeln("i=", i);

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

    writeln("i =", i);

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

private auto round(T)(in T fracPart, in short precisionAfterDot, bool carry)
if(__traits(isFloating, T))
in(fracPart >= 0)
{
    const uint mult = 10 ^^ (precisionAfterDot + 1);
    writeln("mult ", mult);

    // Scale to integer
    //TODO: use appropriate size of integer type?
    auto asInteger = cast(ulong)(fracPart * mult);
    writeln("asInteger ", asInteger);

    // Rounding
    if(asInteger % 10 > 5)
        asInteger += 10;

    asInteger /= 10;

    writeln("asInteger rounded=", asInteger);

    // FIXME: carry detection goes wrong
    if(asInteger >= mult)
    {
        carry = true;
        asInteger -= mult;
    }

    return asInteger;
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

//~ pure:
//~ nothrow:
//~ @nogc:

/// Calculates the exponent with the appropriate shift of the decimal point
private short calcExp(T)(in T num, out T shifted)
if(__traits(isFloating, T))
in(num > 0)
{
    enum thresUpper = 10.0f;
    enum thresLower = 1.0f;

    shifted = num;
    short exponent;

    //TODO: early stop to ignore non-displayed part
    if(shifted >= thresUpper)
        while(shifted >= thresUpper)
        {
            shifted /= 10;
            exponent++;
        }
    else if (shifted < thresLower)
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
