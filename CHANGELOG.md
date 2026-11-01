# BoneProfiler Changelog

## v1.0.2 TEST — CPU unavailable handling and episode tracking
- Distinguish absent native CPU data from measured zero CPU usage.
- Detect consecutive low-FPS episodes and retain start, recovery, minimum FPS, and memory delta.
- Include episodes in copyable diagnostic reports.
- Preserve existing SavedVariables and WoW 3.3.5a interface.
- Actual `scriptProfile` support on the modified client remains unverified.


## v1.0.0 — Initial diagnostic test build

- Live FPS and peak-frame-duration sampling.
- Per-addon Lua CPU and memory rankings (CPU requires scriptProfile and client restart).
- Persistent spike history, combat/zone context, copyable reports, and draggable settings window.
- Standalone WoW 3.3.5a support without dependencies.

**Status:** In-game verification pending.
