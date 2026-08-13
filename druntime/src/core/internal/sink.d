module core.internal.sink;

import core.interpolation;

void sink(IES...)(IES ies) //nothrow @nogc @safe
if(is(IES[0] == InterpolationHeader) || is(IES[0] == string) && IES.length == 1)
{
    import core.stdc.stdio: fflush, fprintf, fwrite, stderr, stdout;
    import core.stdc.stdlib: abort;

    static foreach(e; ies)
    {
        static if(is(typeof(e) == struct))
        {
            pragma(msg, "Unsupported expression : " ~ typeof(e).stringof);
        }
        else static if(is(typeof(e) == string) || __traits(isSame, typeof(e), InterpolatedLiteral))
        {
            auto r = fwrite(e.ptr, char.sizeof, e.length, stdout);
            if(r < e.length)
                abort();
        }
        else
            static assert(false, "Unsupported IES expression type: " ~ typeof(e).stringof);
    }

    fflush(stdout);
}

unittest
{
    enum hello = "Hello, world!";

    sink(`atr`);
    sink(i`sink() says: "$(hello)"`);

    /*
     * TODO: support for:
     * - compile-time strings
     * - variable strings
     * - integers
     * - float
     * - stdout/stderr selection
     */
}
