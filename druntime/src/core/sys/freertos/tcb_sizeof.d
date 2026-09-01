///
module core.sys.freertos.tcb_sizeof;

import core.internal.abort: abort;
import core.sys.freertos;
import core.thread.types : isStackGrowingDown;

immutable size_t tcbSizeof;

/*
 * Because TCB is a complex compile-time C struct, we can't directly
 * know its size from D. But we can determine its size indirectly.
 */
shared static this()
{
    TaskHandle_t xHandle;
    TaskStatus_t xTaskDetails;

    static extern(C) void dummyTask(void*) {}

    if(xTaskCreate(&dummyTask, "TCB.sizeof", 0, null, 0, &xHandle) != pdPASS)
        abort("TCB.sizeof failed");

    vTaskGetInfo(xHandle, &xTaskDetails, pdFALSE, eTaskState.eInvalid);

    const tcbStart = cast(void*) xHandle;
    const stackStart = cast(void*) xTaskDetails.pxStackBase;

    assert(isStackGrowingDown && stackStart > tcbStart);

    // In fact, size calculated as "no more than" due to alignment
    tcbSizeof = stackStart - tcbStart;

    vTaskDelete(xHandle);
}
