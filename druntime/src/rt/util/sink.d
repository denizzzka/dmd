module rt.sink;

import core.interpolation;

enum name = "John Doe";
auto items = i"Hello, $(name), how are you?";

unittest
{
    /+
    assert(
        items == tuple(
            InterpolationHeader(),                       // denotes the start of an IES
            InterpolatedLiteral!("Hello, ")(),           // literal string data
            InterpolatedExpression!("name")(),           // expression literal data
            name,                                        // expression passed directly
            InterpolatedLiteral!(", how are you?")(),    // literal string data
            InterpolationFooter()
        )
    );
    +/

    import std.stdio;
    foreach(e; items[1 .. $-1])
        e.write;

    writeln;

    /*
     * TODO: support for:
     * - compile-time strings
     * - variable strings
     * - integers
     * - float
     * - stdout/stderr selection
     */
}
