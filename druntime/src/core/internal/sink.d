module core.internal.sink;

import core.interpolation;

void sink(IES...)(in IES ies) //nothrow @nogc @safe
{
    static foreach(e; ies)
    {
        import std.stdio;
        e.write;
    }
}

unittest
{
    enum hello = "Hello, world!";

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
