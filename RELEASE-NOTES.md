# BoneProfiler v1.0.6 — Stable

- FPS-based background-throttling hints use the configured 62 FPS foreground and 30 FPS background caps.
- Add timestamps for suspected foreground/background transitions.
- Add `/bp mark` for manually marking Alt+Tab test points.
- The hints rely on frame-rate observations and do not directly detect application focus.
- Preserve existing BoneProfiler SavedVariables.

Maintainer: Uncle Bone
