import std;

//TODO: about maxLen: dig is short for "digits" and specifies the number of digits that signify the precision of the type.

scope auto num2ascii(ubyte maxLen = 32 /* TODO: decrease or remove */, T)(T num) //TODO: nothrow @nogc
{
    static struct Res
    {
        private char[maxLen] buf = 'b'; //void;
        const(char)[] slice;
        alias this = slice;

        private:

        // Returns: unused part of the return buffer
        char[] getFreeBuf() => buf[slice.length .. $];

        void appendSliceWidth(size_t append_len)
        {
            const nlen = slice.length + append_len;
            assert(nlen <= buf.length);

            slice = buf[0 .. slice.length + append_len];
        }

        void append(const char[] str)
        {
            const s = slice.length;
            const e = slice.length + str.length;

            appendSliceWidth(str.length);
            buf[s .. e] = str;
        }

        void append(char c)
        {
            const idx = slice.length;

            appendSliceWidth(1);
            buf[idx] = c;
        }
    }

    Res r;

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
            return r;
        }
        else if(num > T.max)
        {
            r.append("inf");
            return r;
        }
        else if(num < -T.max)
        {
            r.append("-inf");
            return r;
        }

        // Calculate the exponent with the appropriate shift of the decimal point
        int exponent;
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

    enum asciiNumStart = ubyte(48); // '0'

    // TODO: use smaller types if it's worth it
    ulong intPart = cast(ulong) num;
    double fracPart = num - cast(double) intPart;

    if(intPart == 0)
        r.append('0');
    else
    {
        // Using unused part of the return buffer to store numbers
        char[] freeBuf = r.getFreeBuf();

        ubyte i = 0;
        while(intPart > 0)
        {
            freeBuf[i] = asciiNumStart + intPart % 10;
            intPart /= 10;
            i++;
        }

        // Cut a part filled with digits
        char[] intDigits = freeBuf[0 .. i];

        intDigits.reverseArray();

        r.appendSliceWidth(intDigits.length);
    }

    enum fracPrecision = 6;

    if(isFloat)
    {
        r.append('.');

        char[] freeBuf = r.getFreeBuf();

        ubyte i = 0;
        while(i < fracPrecision)
        {
            fracPart *= 10;
            ubyte digit = cast(ubyte) fracPart;
            freeBuf[i] = cast(char)(asciiNumStart + digit);
            fracPart -= digit;

            i++;
        }

        r.appendSliceWidth(i);
    }

    return r;
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
        //TODO: add test with leading zero
        //TODO: add tests for all numeric types (use templates)

        //~ const r = float(-123.45678).num2ascii;
        const r = float(-0.0012).num2ascii;
        assert(r == "-123.456779", r.to!string);

        assert(float.nan.num2ascii == "nan");
        assert(float.infinity.num2ascii == "inf");
        assert((-float.infinity).num2ascii == "-inf");
    }
}
