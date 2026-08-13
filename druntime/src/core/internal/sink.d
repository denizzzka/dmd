module core.internal.sink;

import core.internal.string: signedToTempString, unsignedToTempString;
import core.interpolation;
import core.stdc.stdio: fflush, fprintf, fwrite, stderr, stdout;
import core.stdc.stdlib: abort;

private enum bool isInstanceOf(alias S, T) = is(T == S!Args, Args...);

void sink(IES...)(IES ies) //nothrow @nogc @safe
if(is(IES[0] == InterpolationHeader))
{
    //FIXME: set appropriate size for each type
    char[100] buf;

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
            else static if(isInstanceOf!(InterpolatedExpression, typeof(e)))
            { /* will be processed as value passed directly, skip */ }
            else
                pragma(msg, "Unsupported IES struct: " ~ typeof(e).stringof);
        }
        else static if(is(typeof(e) == string))
        {
            writeString(e);
        }
        else static if(__traits(isUnsigned, typeof(e)))
        {
            unsignedToTempString(e, buf).writeString;
        }
        else static if(__traits(isIntegral, typeof(e)))
        {
            signedToTempString(e, buf).writeString;
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
    const ulong ulongVal = 321;
    sink(i"$(uintVal) $(ulongVal)\n");

    int intVal = -456;
    int longVal = -456;
    sink(i"$(intVal) $(longVal)\n");

    /*
     * TODO: support for:
     * - compile-time strings
     * - variable strings
     * - integers
     * - float
     * - stdout/stderr selection
     */
}
