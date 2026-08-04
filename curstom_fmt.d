import std;

scope auto integer2ascii(ubyte maxLen = 7, T)(T num) //TODO: nothrow @nogc
{
    static struct Res
    {
        private char[maxLen] buf = 'b'; //void;
        const(char)[] slice;
        alias this = slice;

        void appendSliceWidth(size_t append_len)
        {
            const nlen = slice.length + append_len;
            assert(nlen <= buf.length);

            slice = buf[0 .. slice.length + append_len];
        }

        void appendStr(const char[] str)
        {
            const nlen = slice.length + str.length;
            assert(nlen <= buf.length);

            buf[slice.length .. nlen] = str;
            appendSliceWidth(str.length);
        }

        void append(char c)
        {
            assert(slice.length + 1 <= buf.length);

            buf[slice.length] = c;
            appendSliceWidth(1);
        }
    }

    Res r;

    if(num < 0)
    {
        num = -num;
        r.append('-');
    }

    // TODO: use smaller types if it's worth it
    ulong intPart = cast(ulong) num;
    double fracPart = num - cast(double) intPart;

    if(intPart == 0)
        r.append('0');
    else
    {
        // Using unused part of the return buffer to store numbers
        char[] freeBuf = r.buf[r.slice.length .. $];

        ubyte i = 0;
        while(intPart > 0)
        {
            freeBuf[i] = intPart % 10 + '0' /* ASCII start code */;
            intPart /= 10;
            i++;
        }

        // Cut a part filled with numbers
        char[] intNumbers = freeBuf[0 .. i];

        intNumbers.reverseSmallArray();

        r.appendSliceWidth(intNumbers.length);
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
        assert(r == "-12345", r.to!string);
    }

    assert(false); //TODO: remove
}
