# Magic Mouse +

A native macOS 13+ SwiftUI utility. Left surface tap sends a left click; right surface tap sends a right click at the current pointer. No networking, analytics, telemetry, package dependencies, menu-bar status item, or persistent Dock icon.

## Build and run

Open `MagicMousePlus.xcodeproj`, choose `MagicMousePlus` → My Mac, then Run. For automated verification use `./scripts/check.sh`. The script compiles the recognizer checks, the C bridge checks, and a locally signed universal Release app under `$TMPDIR/magic-mouse-plus-build` (or `/tmp` when TMPDIR is unset). Ordinary Xcode builds use Xcode's normal DerivedData location. Avoid placing DerivedData on a cloud-synced Desktop: Finder metadata can break code signing.

Launch the built app and select **ALLOW ACCESS**, then enable **Magic Mouse +** in System Settings → Privacy & Security → Accessibility. macOS permissions are user-controlled; the engine never posts clicks without trust. If the passive physical-click monitor cannot start, the panel offers Input Monitoring settings as a separate step. The app rechecks every three seconds; after changing Input Monitoring macOS may require reopening it.

**HIDE** and the window's close button keep the process running. Open the same app again through Finder or Spotlight to bring the panel back. **QUIT** stops capture and exits. **START AT LOGIN** uses Apple's `SMAppService.mainApp` and is off by default; enable it after moving the app to a stable location, preferably Applications. Launches marked by macOS as login-item launches remain hidden. Registration failures and approval requirements appear in the local log.

## Engine and safety

- Runtime-loaded MultitouchSupport with checked symbols and a C ABI boundary. Only external family 112 (Magic Mouse) is selected; built-in and external trackpads and unknown families are excluded. One Magic Mouse is active at a time.
- Tap recognizer accepts one contact lasting 25–220 ms with at most 3.5% normalized movement. Edges and a narrow center seam are rejected. Multiple contacts, replacement contact IDs, malformed frames, long rests, and stale/out-of-order data are rejected.
- A passive event tap observes physical mouse buttons, dragging, and scrolling; it never swallows or alters physical events. Six-point pointer movement cancels a candidate. A 25 ms release settling period allows physical clicks to cancel synthetic clicks.
- Synthetic down/up pairs preserve keyboard modifiers, mark their origin to avoid feedback, and set double/triple-click counts. No held synthetic button or tap-and-drag behavior.
- Settings changes, sleep, session lock, disconnect and permission loss cancel pending gestures. On startup or reconfiguration, any held contact must clear before taps are accepted. This can conservatively discard the first tap if the device has not yet emitted an empty frame.
- Bounded, memory-only lifecycle log; no touch coordinates, typed input, or click history are retained. Preferences are local UserDefaults.
- Main-thread engine state, copied callback values, mutex-protected C device lifecycle, idle-frame coalescing, and adaptive refresh: 15 seconds while active, 4 seconds while reconnecting, 20 seconds while waiting for permissions, and 60 seconds when disabled. No continuous animation or background rendering loop. Reduced Motion disables short control transitions.

MultitouchSupport is a private, undocumented API and can change across macOS versions. Unknown devices fail closed. This is a locally signed utility, not a notarized or App Store distribution. Device generation coverage and physical tap feel require hardware verification.

## Layout

- `Core/TapRecognizer.swift`: deterministic, independently tested gesture state machine.
- `Bridge/TouchBridge.c`: dynamic framework loading, device filtering, callback normalization and teardown.
- `Core/TapEngine.swift`: permissions, physical event suppression, click posting, sleep/session lifecycle.
- `AppModel.swift`: preferences, status, bounded log, login registration.
- `UI/MagicMousePanel.swift`: reviewed Luna Max view proposal integrated with real engine state.
- `MagicMousePlusApp.swift`: accessory app and retained native window lifecycle.

Paths above are relative to `MagicMousePlus/`. `scripts/create-project.py` reproducibly generates the dependency-free Xcode project.

## Verification on 2026-09-08

- 15 recognizer checks passed: left/right, long rest, noise, motion, multi-contact, seam/edge, identity change, timestamp ordering, NaN, double tap, debounce, cancellation/recovery.
- C bridge checks passed: 96-byte ABI, device filtering, frame validity, registration reuse, idempotent stop and late callbacks.
- Xcode 26.6 Release universal arm64 + x86_64 build and local code-sign verification passed.
- Live read-only framework enumeration found built-in family 110 and external Magic Mouse family 112.
- App launched and its real control panel was visually inspected in the permission-needed state.
- Not yet verified: physical left/right taps and double clicks after granting Accessibility; scroll/physical-click interference on hardware; repeated Bluetooth reconnect/sleep cycles; actual login/reboot; sustained CPU and memory measurements; Intel runtime. UI automation encountered a ScreenCaptureKit error after initial visual inspection, so a complete automated control interaction pass is not claimed.

Before relying on daily use, test single/double taps on both sides, physical clicks, scrolling, resting fingers, multiple fingers, dragging, disabled individual sides, master disable, Hide/reopen, Quit, permission revocation, Bluetooth reconnection and login. Avoid testing clicks over destructive controls.

## API references

- [Apple: SMAppService main app](https://developer.apple.com/documentation/servicemanagement/smappservice/mainapp)
- [Apple: login-item registration](https://developer.apple.com/documentation/servicemanagement/smappservice/register())
- [Reverse-engineered contact ABI](https://github.com/lauschue/Remotastic/blob/main/MultitouchSupport.h)
- [Historical Magic Mouse family identification](https://github.com/calftrail/Touch/blob/master/TouchSynthesis/TouchSynthesis.m)

The reference image is a visual direction, not application logic. The UI contains an original vector mouse drawing and system fonts; no image, network asset, or third-party runtime is bundled.
