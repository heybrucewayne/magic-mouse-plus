#include "TouchBridge.h"
#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <math.h>
#include <pthread.h>
#include <stddef.h>

typedef const void *Device;
typedef struct { float x,y; } MMPoint;
typedef struct { MMPoint position, velocity; } MMVector;
// Reverse-engineered MultitouchSupport ABI. No framework code is bundled.
typedef struct {
    int32_t frame; double timestamp; int32_t path, state, finger, hand;
    MMVector normalized; float area; int32_t reserved; float angle, major, minor;
    MMVector absolute; int32_t reserved2, reserved3; float density;
} Contact;
_Static_assert(sizeof(Contact)==96 && offsetof(Contact,normalized)==32, "Unexpected contact ABI");
typedef void (*Callback)(Device, Contact *, int, double, int);
static CFArrayRef (*createList)(void);
static int (*getFamily)(Device,int *);
static bool (*isBuiltIn)(Device);
static int (*startDevice)(Device,int);
static int (*stopDevice)(Device);
static bool (*isRunning)(Device);
static void (*registerFrame)(Device,Callback);
static void (*unregisterFrame)(Device,Callback);
static void *library;
static Device selected;
static MMFrameHandler sink;
static bool hadActiveContact;
static bool needsInitialFrame;
static uint64_t sessionGeneration;
static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;

static void frameCallback(Device device, Contact *contacts, int count, double time, int frame) {
    (void)frame;
    pthread_mutex_lock(&lock);
    if (device != selected || !sink) { pthread_mutex_unlock(&lock); return; }
    MMFrameHandler callback = sink;
    MMFrame output = {.session=sessionGeneration, .time=time, .valid=isfinite(time) && count>=0 && count<=16};
    if (output.valid && count && !contacts) output.valid=false;
    if (output.valid) for (int i=0;i<count;i++) {
        Contact c=contacts[i];
        if (c.state<0 || c.state>7) { output.valid=false; break; }
        if (c.state==3 || c.state==4) {
            output.count++;
            output.identifier=c.path;
            output.x=c.normalized.position.x; output.y=c.normalized.position.y;
            if (!isfinite(output.x) || !isfinite(output.y) || output.x<0 || output.x>1 || output.y<0 || output.y>1) output.valid=false;
        }
    }
    bool active = output.valid && output.count > 0;
    // MultitouchSupport can emit an empty frame continuously while the
    // mouse is idle. Deliver only contact frames and the one release frame
    // needed to close a gesture; this keeps the login-item process quiet.
    bool shouldDeliver = needsInitialFrame || active || hadActiveContact || (!output.valid && count != 0);
    needsInitialFrame = false;
    hadActiveContact = active;
    pthread_mutex_unlock(&lock);
    if (!shouldDeliver) return;
    // Never call into Swift while holding the device lifecycle mutex. A
    // permission/device transition can stop the bridge while a callback is
    // being delivered; the copied handler remains safe because it only
    // enqueues the frame and the Swift session boundary rejects stale data.
    callback(output);
}
bool MMBridgeLoad(void) {
    if (library) return createList && getFamily && isBuiltIn && startDevice && stopDevice && registerFrame && unregisterFrame && isRunning;
    library=dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport",RTLD_LOCAL|RTLD_LAZY);
    if (!library) return false;
#define LOAD(v,n) *(void **)(&v)=dlsym(library,n)
    LOAD(createList,"MTDeviceCreateList"); LOAD(getFamily,"MTDeviceGetFamilyID");
    LOAD(isBuiltIn,"MTDeviceIsBuiltIn"); LOAD(startDevice,"MTDeviceStart");
    LOAD(stopDevice,"MTDeviceStop"); LOAD(isRunning,"MTDeviceIsRunning");
    LOAD(registerFrame,"MTRegisterContactFrameCallback"); LOAD(unregisterFrame,"MTUnregisterContactFrameCallback");
#undef LOAD
    return MMBridgeLoad();
}
uint64_t MMBridgeSession(void) {
    pthread_mutex_lock(&lock);
    uint64_t result = sessionGeneration;
    pthread_mutex_unlock(&lock);
    return result;
}
void MMBridgeRequestBoundary(void) {
    pthread_mutex_lock(&lock);
    if (selected) needsInitialFrame=true;
    pthread_mutex_unlock(&lock);
}
void MMBridgeStop(void) {
    pthread_mutex_lock(&lock);
    Device old=selected; selected=NULL; sink=NULL; hadActiveContact=false; needsInitialFrame=false;
    pthread_mutex_unlock(&lock);
    // Never hold the callback lock while asking the framework to stop.
    if (old) { unregisterFrame(old,frameCallback); stopDevice(old); CFRelease(old); }
}
int MMBridgeRefresh(MMFrameHandler handler) {
    if (!MMBridgeLoad()) return -1;
    CFArrayRef devices=createList();
    Device candidate=NULL;
    if (devices) for(CFIndex i=0;i<CFArrayGetCount(devices);i++) {
        Device d=CFArrayGetValueAtIndex(devices,i); int family=0;
        // 112 is the Magic Mouse family. Unknown families fail closed, never
        // assume an external multitouch device is a mouse (Magic Trackpad).
        if (!isBuiltIn(d) && getFamily(d,&family)==0 && family==112) { candidate=d; break; }
    }
    if (candidate && candidate==selected && isRunning(selected)) { CFRelease(devices); return 1; }
    if (candidate) CFRetain(candidate);
    MMBridgeStop();
    int result=0;
    if (candidate) {
        pthread_mutex_lock(&lock); selected=candidate; sessionGeneration++; sink=handler; needsInitialFrame=true; pthread_mutex_unlock(&lock);
        registerFrame(candidate,frameCallback);
        startDevice(candidate,0);
        if (isRunning(candidate)) result=1;
        else { MMBridgeStop(); result=-2; }
    }
    if (devices) CFRelease(devices);
    return result;
}
