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
    // This is nogc code, but calls miniFormat() which uses GC
    // TODO: miniFormat() uses libc - remove rely on it and revert @nogc

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
        const end = i + 1;

        void printPrevWord()
        {
            Sys.print(fmt[start .. i]);
            start = i; // also starts new word
        }

        if(!specState)
        {
            if(c == '%')
            {
                printPrevWord();
                specState = true;
            }
        }
        else // specifier word processing
        {
            assert(i > 0);

            const word = fmt[start+1 .. end]; // skips % escape symbol
            assert(word.length <= 3, fmt[start .. end]); // is too long for a specifier

            void startNewWord() { start = end; }

            void specRecognized(const char[] specName) nothrow
            {
                assert(currSpec < args.length, "Specifiers number is bigger than arguments provided");

                ref h = handlers[currSpec];
                h.func(specName, h.val);
                currSpec++;

                specState = false;
                startNewWord();
            }

            switch(word)
            {
                case "%":
                    specState = false;
                    Sys.print(word);
                    startNewWord();
                    break;

                case "s":
                case "g":
                case "x":
                case "d":
                case "u":
                case "lld":
                case "llu":
                    specRecognized(word);
                    break;

                default:
                    break;
            }
        }
    }

    // unexpected end of format string
    assert(specState == false, fmt[start .. $]);

    if(start < fmt.length-1)
        Sys.print(fmt[start .. $]);

    assert(currSpec == args.length, "Processed specifiers number isn't equal to arguments number");
}

unittest
{
    static void lf() => Sys.print("\n");

    __printf(">>>> 111 %s 222 %s 333\n", "(test arg)", "(another one)");

    __printf("Print percent symbol: %%"); lf;
    __printf("%g", 123.45); lf;
    //~ __printf("%x", 123.45); lf;
    //~ __printf("%d", 123.45); lf;
    __printf("%u", 123); lf;
    //~ __printf("%lld", 123.45); lf;
    //~ __printf("%llu", 123.45); lf;

    //~ __printf(">>>> aaa %s ab%%c%def%d5", "test arg");
}
