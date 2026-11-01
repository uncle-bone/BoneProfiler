# BoneProfiler

Standalone performance diagnostics for **Ascension Conquest of Azeroth / Conquest Reborn** (WoW 3.3.5a).

## Download and install

- [Download current source ZIP](https://github.com/uncle-bone/BoneProfiler/archive/refs/heads/main.zip). Extract only the `BoneProfiler/` addon directory to `Interface/AddOns/`.
- Open the diagnostic window with `/bp` or `/boneprofiler`.
- For per-addon CPU timings run `/bp cpu on`, then **fully restart the WoW client**. CPU profiling itself adds overhead; disable with `/bp cpu off` and restart afterwards.
- After reproducing a slowdown, use **Copy report (Ctrl+C)** and paste the results into the Questie-X development conversation.

## Features

FPS and worst frame per sampling interval; per-addon cumulative Lua CPU delta (when enabled) and memory rankings; saved stutter/spike history; zone and combat context; copyable report; GUI controls for alerting and clearing history.

## Limitations

WoW addon APIs cannot inspect Windows tasks, GPU performance, or exact per-Lua-function call stacks. Low FPS does not always imply high script CPU. This is an initial **v1.0.0 test build** and has not been verified in-game.

**Maintainer:** Uncle Bone
