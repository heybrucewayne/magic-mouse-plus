#include <assert.h>
#include <stdio.h>
#include "../MagicMousePlus/Bridge/TouchBridge.c"
static MMFrame observed;
static int received, registrations, removals, starts, stops;
static bool running;
static int mockFamily=112;
static CFArrayRef mockList(void) { const void *d=CFSTR("test-device"); return CFArrayCreate(NULL,&d,1,&kCFTypeArrayCallBacks); }
static int family(Device d,int *out) { *out=mockFamily; return 0; }
static bool builtIn(Device d) { return false; }
static int begin(Device d,int mode) { starts++;running=true;return 0; }
static int end(Device d) { stops++;running=false;return 0; }
static bool active(Device d) { return running; }
static void reg(Device d,Callback c) { registrations++; }
static void unreg(Device d,Callback c) { removals++; }
static void receive(MMFrame f) { received++;observed=f; }
int main(void) {
    library=(void*)1;createList=mockList;getFamily=family;isBuiltIn=builtIn;
    startDevice=begin;stopDevice=end;isRunning=active;registerFrame=reg;unregisterFrame=unreg;
    assert(MMBridgeRefresh(receive)==1 && starts==1 && registrations==1);
    assert(MMBridgeRefresh(receive)==1 && starts==1);
    frameCallback(selected,NULL,0,0.5,0);
    assert(received==1 && observed.count==0 && observed.valid);
    frameCallback(selected,NULL,0,0.6,0);assert(received==1);
    MMBridgeRequestBoundary();
    frameCallback(selected,NULL,0,0.7,0);assert(received==2);
    frameCallback(selected,NULL,0,0.8,0);assert(received==2);
    assert(starts==1 && registrations==1);
    received=0;
    Contact c={.path=9,.state=4,.normalized.position={0.25,0.6}};
    frameCallback(selected,&c,1,1,1);
    assert(received==1 && observed.valid && observed.count==1 && observed.identifier==9);
    c.state=5;frameCallback(selected,&c,1,1.1,2);assert(observed.count==0);
    int afterRelease=received;frameCallback(selected,NULL,0,1.15,3);assert(received==afterRelease);
    frameCallback(selected,NULL,1000,1.2,3);assert(!observed.valid);
    c.state=4;c.normalized.position.x=NAN;frameCallback(selected,&c,1,1.3,4);assert(!observed.valid);
    Device old=selected;MMBridgeStop();assert(stops==1 && removals==1 && !selected);
    int count=received;frameCallback(old,&c,1,1.4,5);assert(received==count);
    MMBridgeStop();assert(stops==1);
    // A stopped device must be registered again without leaking registrations.
    assert(MMBridgeRefresh(receive)==1);
    int before=starts;
    running=false;
    assert(MMBridgeRefresh(receive)==1 && starts==before+1);
    for (int i=0;i<1000;i++) { MMBridgeStop(); assert(MMBridgeRefresh(receive)==1); }
    MMBridgeStop(); assert(registrations==removals && starts==stops);
    int totalStarts=starts;
    mockFamily=99;assert(MMBridgeRefresh(receive)==0 && starts==totalStarts);
    puts("PASS: bridge ABI, filtering, frame validation, lifecycle and late-callback checks");
}
