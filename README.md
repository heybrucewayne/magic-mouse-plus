# Magic Mouse +

A small native macOS app that turns Magic Mouse surface taps into left and right clicks.

- Runs quietly in the background
- No network, analytics, telemetry, or third-party dependencies
- Physical clicks, scrolling, and dragging continue to work normally
- Optional launch at login

## Requirements

- macOS 13 or later
- Apple Magic Mouse

## Setup

1. Open `MagicMousePlus.xcodeproj` in Xcode and run the app.
2. Select **ALLOW ACCESS**.
3. Enable **Magic Mouse +** in **System Settings → Privacy & Security → Accessibility**.
4. If requested, also enable Input Monitoring and reopen the app.
5. Turn on the tap options you want.

Keep one copy of the app in `/Applications`. This avoids duplicate permission entries after rebuilding.

## Build and test

```sh
./scripts/check.sh
```

The script runs the gesture and bridge tests, then builds a locally signed Release app for Apple Silicon and Intel Macs.

## Important

Magic Mouse + uses Apple’s private `MultitouchSupport` framework. It is locally signed, not notarized, and not distributed through the App Store. macOS permissions are required before the app can create clicks.
