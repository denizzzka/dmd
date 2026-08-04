import std.stdio;

//TODO: use external buf

scope auto integer2ascii(ubyte maxLen = 7, /*FIXME*/ T = int)(T val) //nothrow @nogc
{
    static struct Res
    {
        private char[maxLen] buf = 'b'; //void;
        const(char)[] slice;
        alias this = slice;
    }

    Res r;

    void append(const char[] str)
    {
    with(r)
    {
        const nlen = slice.length + str.length;
        assert(nlen <= buf.length);

        buf[slice.length .. nlen] = str;
        slice = buf[0 .. nlen];
    }}

    if(val < 0)
        append("-");

    return r;
}

void main()
{
    const r = long(-12345).integer2ascii;
    writeln(r);
    assert(r == "-", r);

    assert(false); //TODO: remove
}
