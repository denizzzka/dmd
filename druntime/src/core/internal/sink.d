module core.internal.sink;

import core.internal.string: signedToTempString, unsignedToTempString;
import core.interpolation;
import core.stdc.stdio: fflush, fprintf, fwrite, stderr, stdout;
import core.stdc.stdlib: abort;

private enum bool isInstanceOf(alias S, T) = is(T == S!Args, Args...);

void sink(IES...)(IES ies) nothrow @nogc @safe
{
    sinkImpl(true, ies);
}

void sinkErr(IES...)(IES ies) nothrow @nogc @safe
{
    sinkImpl(false, ies);
}

private void sinkImpl(Pipe)(Pipe pipe, in char str) nothrow @nogc @safe
{
    writeString(pipe, str);
}

private void sinkImpl(IES...)(bool toStdout, IES ies) nothrow @nogc @safe
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
                writeString(toStdout, e.toString);
            }
            else static if(isInstanceOf!(InterpolatedExpression, typeof(e)))
            { /* will be processed as value passed directly, skip */ }
            else
                pragma(msg, "Unsupported IES struct: " ~ typeof(e).stringof);
        }
        else static if(is(typeof(e) == string))
        {
            writeString(toStdout, e);
        }
        else static if(__traits(isUnsigned, typeof(e)))
        {
            writeString(toStdout, unsignedToTempString(e, buf));
        }
        else static if(__traits(isIntegral, typeof(e)))
        {
            writeString(toStdout, signedToTempString(e, buf));
        }
        else static if(__traits(isFloating, typeof(e)))
        {
            () @trusted
            {
                import core.stdc.stdio: snprintf;
                const len = snprintf(buf.ptr, buf.length, "%f", e);
                writeString(toStdout, buf[0 .. len]);
            }();
        }
        else
            static assert(false, "Unsupported IES expression type: " ~ typeof(e).stringof);
    }

    fflush(toStdout ? stdout : stderr);
}

private void writeString(bool toStdout, in char[] s) nothrow @nogc @trusted
{
    auto r = fwrite(s.ptr, char.sizeof, s.length, toStdout ? stdout : stderr);
    if(r != s.length)
    {
        if(toStdout)
            writeString(false, "Failed to write stdout");

        abort();
    }
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
