# Click tuning

Reference review (2026-09-09):

- [BetterTouchTool maintainer discussion](https://community.folivora.ai/t/latency-with-double-tap-to-drag-drop/46504/6) separates the delay before a single click from the double-tap interval in its double-tap-to-drag behavior. This utility has no tap-drag mode, so it keeps immediate single-click dispatch after the existing 25 ms physical-click settling check; it does not wait to see whether a double tap follows.
- [magic-mouse-touch](https://github.com/Raphe-dev/magic-mouse-touch) documents double-click event counts without a wait-and-see delay and duration/movement/contact filtering.
- [Mouse Toucher](https://github.com/meatpaste/mousetoucher/blob/main/README.md) documents a 250 ms tap duration and tunable movement/side boundaries. These are reference approaches, not hardware validation for this app. No third-party code or new dependency was copied into the project.

Changes:

- Debounce uses a minimum 20 ms gap between an accepted release and the next touchdown, replacing the 65 ms release-to-release exclusion. Two intentional short taps can now form a fast double-click; a bouncing contact with only a 5–10 ms gap is rejected.
- Duration range is 20–250 ms (previously 25–220 ms). Maximum normalized movement is 4.5% (previously 3.5%). Edge/seam, multi-contact, identity, malformed-frame and long-rest rejection remain in place.
- Physical buttons use a 40 ms cooldown. Scrolling, dragging and event-monitor interruptions retain 120 ms. A subsequent button event never shortens an existing scrolling cooldown.
- A main-actor-owned Core Graphics event source is reused. Its local-event suppression interval is explicitly zero and physical mouse/keyboard/system events are permitted. This configures our own event source; it does not disable gesture rejection or modify macOS permissions.
- Existing Quartz pointer coordinates, macOS double-click interval, paired down/up events, backlog limits and connection recovery are preserved.

Validation: 128 recognizer checks, bridge lifecycle/session checks, offline click-coordinate/source checks, concurrent inbox stress checks, and universal Release build passed. Physical feel, false-positive frequency and end-to-end click latency on the user's mouse still need real use; the parameter changes are not measured latency claims.
