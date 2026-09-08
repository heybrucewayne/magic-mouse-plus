#ifndef MM_TOUCH_BRIDGE_H
#define MM_TOUCH_BRIDGE_H
#include <stdbool.h>
#include <stdint.h>
typedef struct { int count; int identifier; float x,y; double time; bool valid; } MMFrame;
typedef void (*MMFrameHandler)(MMFrame frame);
// All lifecycle calls are main-thread only; handler runs on the framework thread.
bool MMBridgeLoad(void);
int MMBridgeRefresh(MMFrameHandler handler);
void MMBridgeStop(void);

#endif
