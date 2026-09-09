# Background input recovery

The engine holds a `userInitiatedAllowingIdleSystemSleep` activity only while capture is enabled, connected and not suspended. It releases the activity on stop, permission loss, sleep, disconnect and shutdown. This keeps active background input work eligible to run without preventing normal system/display idle sleep. No busy loop or latency-critical activity was added.

Every bridge registration has a generation number. Frames carry that number from the callback mutex boundary. A replacement/restarted device resets the recognizer, pointer origin, pending clicks and device timestamp history even when refresh immediately succeeds. Queued frames from the previous registration cannot enter the new session.

Foreground application changes trigger a coalesced health refresh after 250 ms for every application. Healthy connections remain intact. The existing periodic refresh still covers disabled monitors and disconnected devices.

Verification: gesture checks include a restarted timestamp origin; bridge checks verify stable generation reuse, new generations on restart/device replacement, rejection of callbacks from the old device, and 1,000 balanced start/stop cycles. Existing coordinate and bounded-backlog checks remain enabled. These are automated checks, not a claim of indefinite physical-device reliability.

Temporary diagnostics can be enabled by launching with `--diagnostics`. The app writes one overwritten JSON snapshot under its temporary directory, `magic-mouse-plus-diagnostics.json`, only in that mode. It contains counters and permission/capture booleans, no application names, text, screenshots or pointer coordinates. A normal relaunch disables these diagnostics.
