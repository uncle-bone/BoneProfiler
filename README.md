# BoneProfiler

> **[Download](https://github.com/uncle-bone/BoneProfiler/releases/latest)**

**Find the addon behind your FPS drops.** BoneProfiler is a standalone in-game performance diagnostic tool built for **Ascension Conquest of Azeroth / Conquest Reborn**, running on the **World of Warcraft 3.3.5a** client.

It was created to investigate severe, delayed FPS drops after login, but is intended for troubleshooting **any addon**—Questie-X, DBM-CoA, LootCollector, DragonUI, ElvUI, and more.

## Features

- **FPS monitoring:** samples live FPS and records the worst observed frame duration within each sampling interval.
- **Addon CPU usage:** compares per-addon Lua CPU counters between samples and ranks the most expensive addons (requires WoW's script profiling).
- **Addon memory:** displays memory usage and ranks loaded addons by consumption.
- **Stutter history:** records low-FPS and long-frame samples, retaining up to 250 spike records in SavedVariables.
- **Context:** includes zone and combat status to help reproduce problems.
- **Copyable reports:** exports timestamped performance samples and addon rankings for troubleshooting.
- **In-game controls:** draggable diagnostic window, clear-session and clear-spikes buttons, and optional stutter alerts.
- **No dependencies:** lightweight standalone addon with no changes required to the addons being investigated.

## Download

**[Download](https://github.com/uncle-bone/BoneProfiler/releases/latest)**

Extract the included `BoneProfiler` folder into `Interface/AddOns/`.

v1.0.6 adds FPS-based background-throttling hints using the configured 62/30 FPS caps, timestamps for suspected transitions, and `/bp mark` for manually recording Alt+Tab tests. The hints use observed frame rate; they do not directly detect Windows focus state.

## Getting started

1. Enable BoneProfiler in the character-selection AddOns menu.
2. Enter the game and type `/bp` to open the draggable monitoring window.
3. For CPU attribution, run `/bp cpu on` and **fully restart the WoW client**. CPU profiling does not activate immediately.
4. Reproduce the lag or FPS drop and allow the game to recover.
5. Click **Copy report (Ctrl+C)**, copy the highlighted text, and paste it into your bug report or development chat.
6. After diagnosing, run `/bp cpu off` and restart to disable profiling overhead.

Other commands: `/boneprofiler` (toggle window), `/bp export` (open report), `/bp clear` (clear current session and saved spikes).

## Understanding the results

When native CPU data is unavailable, it is displayed as unavailable, not measured zero. Low-FPS episodes track onset, recovery and associated memory changes. High addon CPU deltas can indicate expensive Lua execution. High memory usage alone **does not prove** an addon is responsible for low FPS. Compare timing, repeated spikes, and which addons were active when the issue occurred.

**Important limitations:** WoW 3.3.5a cannot expose Windows processes, GPU bottlenecks, or every individual Lua function through its standard addon API. Script CPU profiling can add overhead and does not measure all rendering costs. This version samples once per second, so it does not preserve every individual frame. This is a **v1.0.2 test build**; in-game verification is still pending.

## Compatibility

- World of Warcraft **3.3.5a**
- Ascension **Conquest of Azeroth / Conquest Reborn**
- Designed to coexist with Blizzard UI, DragonUI, and ElvUI (compatibility not yet fully tested)

## Project

**Maintainer:** Uncle Bone  
**Repository:** https://github.com/uncle-bone/BoneProfiler  
**License:** MIT  
**Current version:** v1.0.2 (test build)

See [CHANGELOG.md](CHANGELOG.md) for version history.
