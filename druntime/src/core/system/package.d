///
module core.system;

//TODO: package
//package:

struct Mem
{
    import core.stdc.stdlib;

    alias allocateOne = malloc;
    alias allocateFew = (size_t num, size_t size) => allocateOne(num * size);
    static void* allocateOneBlank(size_t size) nothrow @nogc => allocateFewBlank(1, size);
    alias allocateFewBlank = calloc;
    alias reallocate = realloc;
    alias free = core.stdc.stdlib.free;

    alias allocateOnStack = alloca;
}

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

private void __printf(scope const char[] fmt, ...) nothrow @nogc
{
    import core.vararg;

    bool specState;
    size_t start;

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
            assert(i - start <= 3, fmt[start .. i]);

            void specifierFound(alias Func, T)()
            {
                specState = false;
                skipWord();
                Func(va_arg!T(_argptr));
            }

            switch(fmt[start .. i])
            {
                case "%":
                    specState = false;
                    wordIsDone(); // prints % symbol
                    break;

                case "s":
                    specifierFound!(Sys.print, const char[]);
                    break;

                default:
                    break;
            }
        }
    }

    assert(!specState, fmt[start .. $]);

    if(start < fmt.length-1)
        Sys.print(fmt[start .. $]);
}

unittest
{
    __printf(">>>> 111 %s 222 %s 333\n", "(test arg)", "(another one)");
    //~ __printf(">>>> aaa %s ab%%c%def%d5", "test arg");
}
