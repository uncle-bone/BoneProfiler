BoneProfiler v1.0.2 — Uncle Bone
WoW 3.3.5a / Conquest Reborn

INSTALL: Extract BoneProfiler folder directly into World of Warcraft/Interface/AddOns/.
Open /bp (or /boneprofiler). GUI has live stats, export (Ctrl+C), clear buttons, alerts toggle.
For per-addon CPU diagnostics: type /bp cpu on, then fully RESTART the WoW client.
CPU profiling has overhead; type /bp cpu off and restart after diagnosing.
Use /bp export or the Copy report button, press Ctrl+C, paste report into ChatGPT.

LIMITATIONS: WoW 3.3.5a addons cannot see Windows processes, OS threads, or exact per-Lua-function stacks without instrumentation. GetAddOnCPUUsage reports cumulative Lua CPU time, not GPU time or complete rendering overhead. Frame time is sampled via OnUpdate; FPS uses GetFramerate. CPU profiling may itself lower FPS. Low-FPS episodes are captured at one-second intervals; unavailable native CPU results are NOT zero. Spikes are captured at one-second intervals, not each individual frame. Profiling data is only available when the client supports scriptProfile. This tool does not modify other addons.
