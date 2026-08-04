import std;

//TODO: about maxLen: dig is short for "digits" and specifies the number of digits that signify the precision of the type.

scope auto integer2ascii(ubyte maxLen = 32 /* TODO: decrease or remove */, T)(T num) //TODO: nothrow @nogc
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

    static if(__traits(isFloating, T))
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
    }

    if(num < 0)
    {
        num = -num;
        r.append('-');
    }

    enum asciiNumStart = '0';

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

        intDigits.reverseSmallArray();

        r.appendSliceWidth(intDigits.length);
    }

    enum fracPrecision = 6;

    if(true /* TODO: add "is float" check */)
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

// "Small" is because ubyte used for indeces
private void reverseSmallArray(T)(ref T arr) pure
{
    assert(arr.length <= ubyte.max);

    ubyte left = 0;
    ubyte right = cast(ubyte)(arr.length - 1);

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
        arr.reverseSmallArray;
        assert(arr == "7654321".dup);
    }

    //~ unittest
    {
        //TODO: add test with leading zero

        const r = float(-123.45678).integer2ascii;
        assert(r == "-123.456779", r.to!string);

        float nan_val;
        assert(nan_val.integer2ascii == "nan");
        assert(float.infinity.integer2ascii == "inf");
        assert((-float.infinity).integer2ascii == "-inf");
    }
}
