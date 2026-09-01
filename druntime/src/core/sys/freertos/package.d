///
module core.sys.freertos;

@nogc:
nothrow:
extern(C):

//TODO: importC from FreeRTOSConfig.h file:
//~ configTICK_RATE_HZ
//~ configMINIMAL_STACK_SIZE

// FIXME:
//~ alias c_long = int;
//~ alias c_ulong = uint;
import core.stdc.config: c_long, c_ulong;

alias BaseType_t = c_long;
alias UBaseType_t = c_ulong;
alias StackType_t = uint;
alias TickType_t = uint;

enum pdTRUE = c_long(1);
enum pdFALSE = c_long(0);
enum portMAX_DELAY = TickType_t(0xffffffff);
enum portNVIC_PENDSVSET_BIT = 1UL << 28UL;

struct EventGroupDef_t;
alias EventGroupHandle_t = EventGroupDef_t*;
struct QueueDefinition;
alias QueueHandle_t = QueueDefinition*;
alias SemaphoreHandle_t = QueueDefinition*;
struct xSTATIC_TCB; //TODO: size unknown but needed
alias StaticTask_t = xSTATIC_TCB;
alias TaskFunction_t = void function(void*);
struct tskTaskControlBlock;

EventGroupDef_t* xEventGroupCreate();
void vEventGroupDelete(EventGroupDef_t*);
uint xEventGroupSetBits(EventGroupDef_t*, const(uint));
uint xEventGroupClearBits(EventGroupDef_t*, const(uint));
uint xEventGroupWaitBits(EventGroupDef_t*, const(uint), const(c_long), const(c_long), uint);

QueueDefinition* xQueueCreateCountingSemaphore(const(c_ulong), const(c_ulong));
c_long xQueueGenericSend(QueueDefinition*, const(const(void)*), uint, const(c_long));
c_long xQueueSemaphoreTake(QueueDefinition*, uint);
void vQueueDelete(QueueDefinition*);

alias xSemaphoreCreateCounting = xQueueCreateCountingSemaphore;
alias xSemaphoreTake = xQueueSemaphoreTake;
auto _xSemaphoreGive(SemaphoreHandle_t xSemaphore) => xQueueGenericSend(cast(QueueHandle_t) xSemaphore, null , TickType_t(0) , BaseType_t(0));
void _vSemaphoreDelete(SemaphoreHandle_t xSemaphore) { vQueueDelete(cast(QueueHandle_t) xSemaphore); }

tskTaskControlBlock* xTaskCreateStatic(void function(void*), const(const(char)*), const(uint), void*, c_ulong, uint*, xSTATIC_TCB*);
tskTaskControlBlock* xTaskGetCurrentTaskHandle();
void vTaskDelay(const(uint));
void vTaskDelete(tskTaskControlBlock*);
uint xTaskGetTickCount();
void vTaskResume(tskTaskControlBlock*);
void vTaskSuspend();

void vApplicationGetIdleTaskMemory(xSTATIC_TCB**, uint**, uint*);
