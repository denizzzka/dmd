///
module core.system;

struct Sys
{
    static import core.stdc.stdlib;
    import core.stdc.stdio;

    alias abort = core.stdc.stdlib.abort;

    static void print(scope const char[] str) nothrow @nogc
    {
        // This is a silly approach, but it's a simple way to print non-null-terminated strings
        // TODO: implement using write() or so
        foreach(c; str)
        {
            auto r = fputc(c, stdout);
            if(r == EOF)
                Sys.abort();
        }
    }

    /// C-formatted print
    static void printf(T...)(scope const char[] fmt, T vals) nothrow @nogc
    {
        static assert(T.length > 0);

        int r = core.stdc.stdio.printf(fmt.ptr, vals);
        if(r < fmt.length)
            Sys.abort();
    }
}

private void __printf(TL...)(scope const char[] fmt, TL args) nothrow
{
    bool specState;
    size_t start;
    size_t currSpec;

    struct Handler
    {
        void function(scope const char[] specName, void* val) nothrow func;
        void* val;
    }

    Handler[args.length] handlers;

    static void printS(scope const char[] specName, void* val)
    {
        assert(specName == "s", specName); // Unsupported specifier
        Sys.print(*(cast(string*) val));
    };

    static void miniFmtCall(T)(scope const char[] specName, void* valPtr)
    {
        import core.internal.dassert: miniFormat;

        auto p = cast(T*) valPtr;
        Sys.print(miniFormat(*p));
    };

    // Convert args list to functions calls
    static foreach(i, T; TL)
    {
        static if(is(T == string))
            handlers[i] = Handler(&printS, &args[i]);
        else
            handlers[i] = Handler(&miniFmtCall!T, &args[i]);
    }

    assert(handlers.length == args.length);

    foreach(i, c; fmt)
    {
        void skipWord() { start = i; }

        void wordIsDone()
        {
            Sys.print(fmt[start .. i]);
            skipWord();
        }

        if(!specState)
        {
            if(c == '%')
            {
                specState = true;
                wordIsDone();
                start++; // skips % symbol
            }
        }
        else // specifier processing
        {
            assert(i > 0);
            assert(start > 0);
            assert(i - start <= 3, fmt[start .. i]); // unknown specifier

            void specifierFound(const char[] specName) nothrow
            {
                assert(currSpec < args.length, "Specifiers number is bigger than arguments provided");

                specState = false;
                skipWord();
                ref h = handlers[currSpec];
                h.func(specName, h.val);
                currSpec++;
            }

            switch(fmt[start .. i])
            {
                case "%":
                    specState = false;
                    wordIsDone(); // prints % symbol
                    break;

                case "s":
                    specifierFound("s");
                    break;

                case "d":
                    specifierFound("d");
                    break;

                default:
                    break;
            }
        }
    }

    // unexpected end of a specifier
    assert(!specState, fmt[start .. $]);

    if(start < fmt.length-1)
        Sys.print(fmt[start .. $]);

    assert(currSpec == args.length, "Processed specifiers number isn't equal to arguments number");
}

unittest
{
    __printf(">>>> 111 %s 222 %s 333\n", "(test arg)", "(another one)");
    __printf(">>>> %d ====", 123.45);
    //~ __printf(">>>> aaa %s ab%%c%def%d5", "test arg");
}
