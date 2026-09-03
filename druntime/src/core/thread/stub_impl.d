/// Single-threaded Thread stub
module core.thread.stub_impl;

import core.thread.osthread: toThread;
import core.thread.threadbase;
import core.time: Duration;
import core.thread.types: ll_ThreadData, ThreadDescr;

enum isSingleThreaded = true;

private alias ThreadID = size_t;
private immutable assertMsg = "threading not implemented";

package void* swapContextImpl(void* newContext) nothrow @nogc
{
    assert(false, assertMsg);
}

version (CoreDdoc) {} else
class Thread : ThreadBase
{
    this( void function() fn, size_t sz = 0 ) @safe pure nothrow @nogc {}
    this( void delegate() dg, size_t sz = 0 ) @safe pure nothrow @nogc {}
    package this( size_t sz = 0 ) @safe pure nothrow @nogc {}

    ~this() nothrow @nogc {}

    static Thread getThis() @safe nothrow @nogc
    {
        return ThreadBase.getThis().toThread;
    }

    override final void[] savedRegisters() nothrow @nogc
    {
        assert(false, assertMsg);
    }

    final Thread start() nothrow
    {
        assert(false, assertMsg);
    }

    override final Throwable join( bool rethrow = true )
    {
        assert(false, assertMsg);
    }

    @property static int PRIORITY_MIN() @nogc nothrow pure @trusted
    {
        assert(false, assertMsg);
    }

    @property static const(int) PRIORITY_MAX() @nogc nothrow pure @trusted
    {
        assert(false, assertMsg);
    }

    @property static int PRIORITY_DEFAULT() @nogc nothrow pure @trusted
    {
        assert(false, assertMsg);
    }

    final @property int priority()
    {
        assert(false, assertMsg);
    }

    final @property void priority( int val )
    {
        assert(false, assertMsg);
    }

    override final @property bool isRunning() nothrow @nogc => true;

    static void sleep( Duration val ) @nogc nothrow @trusted {}

    static void yield() @nogc nothrow
    {
        assert(false, assertMsg);
    }

    package static ThreadDescr getCurrentThreadDescr() nothrow @nogc
    {
        return ThreadDescr(tid: 0);
    }

    package static void afterDeploy() nothrow @nogc {}
}

// Returns true on success
package bool suspendThreadImpl(Thread t) @nogc nothrow
{
    assert(false, assertMsg);
}

// Returns true on success
package bool resumeThreadImpl(Thread t) @nogc nothrow
{
    assert(false, assertMsg);
}

package void afterStopTheWorld(bool suspendedSelf, size_t cnt) @nogc nothrow
{
    assert(false, assertMsg);
}

package void loadStackAndRegInfo(Thread t, const bool sameThread) nothrow @nogc
{
    assert(false, assertMsg);
}

package void purgeStackAndRegInfo(Thread t, const bool sameThread) nothrow @nogc
{
    assert(false, assertMsg);
}

version (CoreDdoc) {} else
private extern (C) void* thread_entryPoint( void* arg ) nothrow
{
    assert(false, assertMsg);
}

version (CoreDdoc) {} else
public auto getpid() => 0;

package auto gettid() => 0;

package void* getStackBottomImpl() nothrow @nogc
{
    assert(false, assertMsg);
}

package struct LLThreadProperties
{
    void delegate() nothrow dg;

    // Returns: false if error occurred
    bool initialize(void delegate() nothrow dg, ref LLThreadContext context) nothrow @nogc
    {
        this.dg = dg;
        return true;
    }
}

package struct LLThreadContext
{
    ThreadID tid;
    uint stacksize;

    this(uint stacksize, void delegate() nothrow cbDllUnload) nothrow @nogc
    {
        this.stacksize = stacksize;
    }
}

// Returns: false if error occurred
package bool launchLLThread(LLThreadProperties* tprop, ref LLThreadContext context, ref ll_ThreadData curr_llt) nothrow @nogc
{
    assert(false, assertMsg);
}

version (CoreDdoc) {} else
void joinLowLevelThread(ThreadID tid) nothrow @nogc
{
    assert(false, assertMsg);
}
