module core.internal.sink;

import core.interpolation;
import core.stdc.stdio: fflush, fprintf, fwrite, stderr, stdout;
import core.stdc.stdlib: abort;

private enum bool isInstanceOf(alias S, T) = is(T == S!Args, Args...);

void sink(IES...)(IES ies) //nothrow @nogc @safe
if(is(IES[0] == InterpolationHeader))
{
    static foreach(e; ies)
    {
        static if(is(typeof(e) == struct))
        {
            static if(is(typeof(e) == InterpolationHeader) || is(typeof(e) == InterpolationFooter))
            { /* skip */ }
            else static if(isInstanceOf!(InterpolatedLiteral, typeof(e)))
            {
                writeString(e.toString);
            }
            else
                pragma(msg, "Unsupported: " ~ typeof(e).stringof);
        }
        else static if(is(typeof(e) == string))
        {
            writeString(e);
        }
        else
            static assert(false, "Unsupported IES expression type: " ~ typeof(e).stringof);
    }

    fflush(stdout);
}

private void writeString(in char[] s)
{
    auto r = fwrite(s.ptr, char.sizeof, s.length, stdout);
    if(r < s.length)
        abort();
}

unittest
{
    enum hello = "Hello, world!";

    sink(i"sink() says: \"$(hello)\"\n");

    uint uintVal = 123;
    int intVal = -456;
    float floatVal = 123.456;
    //~ sink(i"$(uintVal) $(intVal) $(floatVal)\n");

    /*
     * TODO: support for:
     * - compile-time strings
     * - variable strings
     * - integers
     * - float
     * - stdout/stderr selection
     */
}
