module core.internal.sink;

import core.internal.string: signedToTempString, unsignedToTempString;
import core.interpolation;
import core.stdc.stdio: fflush, fprintf, fwrite, stderr, stdout;
import core.stdc.stdlib: abort;

private enum bool isInstanceOf(alias S, T) = is(T == S!Args, Args...);

private void sink(IES...)(IES ies) nothrow @nogc @safe
{
    sinkImpl(stdout, ies);
}

void sinkErr(IES...)(IES ies) nothrow @nogc @safe
{
    sinkImpl(stderr, ies);
}

private void sinkImpl(Pipe, IES...)(Pipe pipe, IES ies) nothrow @nogc @safe
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
                writeString(pipe, e.toString);
            }
            else static if(isInstanceOf!(InterpolatedExpression, typeof(e)))
            { /* will be processed as value passed directly, skip */ }
            else
                pragma(msg, "Unsupported IES struct: " ~ typeof(e).stringof);
        }
        else static if(is(typeof(e) == string))
        {
            writeString(pipe, e);
        }
        else static if(__traits(isUnsigned, typeof(e)))
        {
            writeString(pipe, unsignedToTempString(e, buf));
        }
        else static if(__traits(isIntegral, typeof(e)))
        {
            writeString(pipe, signedToTempString(e, buf));
        }
        else static if(__traits(isFloating, typeof(e)))
        {
            () @trusted
            {
                import core.stdc.stdio: snprintf;
                const len = snprintf(buf.ptr, buf.length, "%f", e);
                writeString(pipe, buf[0 .. len]);
            }();
        }
        else
            static assert(false, "Unsupported IES expression type: " ~ typeof(e).stringof);
    }

    fflush(pipe);
}

private void writeString(P)(P pipe, in char[] s) nothrow @nogc @trusted
{
    auto r = fwrite(s.ptr, char.sizeof, s.length, pipe);
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

    float floatVal = 123.456;
    double doubleVal = -123.456;
    sink(i"$(floatVal) $(doubleVal)\n");
}
