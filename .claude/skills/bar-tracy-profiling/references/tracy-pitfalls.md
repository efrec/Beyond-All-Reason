# Tracy setup — common pitfalls

Troubleshooting for the BAR Tracy workflow. When you hit a new failure mode and resolve it, add a dated entry at the bottom (via a normal commit/PR) so the next person doesn't rediscover it.

## Known pitfalls

### Engine auto-update clobbers the swapped binary
**Symptom:** launch BAR, `tracy` is back to no-op stubs despite having installed a Tracy build.
**Cause:** launcher auto-updated the engine, overwriting `spring.exe` with the vanilla build.
**Fix:** disable engine auto-update in launcher settings, or pin the engine version, or launch `spring.exe` directly from a script.

### Tracy version mismatch
**Symptom:** `tracy-profiler.exe` shows a disconnected client, or the trace flickers / looks corrupted.
**Cause:** profiler GUI version != Tracy client version linked into `spring.exe`.
**Fix:** use v0.11.1 on both sides. If the engine was built against a different Tracy version, match it exactly.

### OOM on long sessions without `TRACY_ON_DEMAND`
**Symptom:** BAR gets laggy or crashes after ~15–30 minutes with Tracy connected.
**Cause:** engine was built without `TRACY_ON_DEMAND`, so all zones are buffered from start regardless of whether Tracy is attached.
**Fix:** use a `TRACY_ON_DEMAND` build (check the build's release notes), or keep capture sessions short, or use `tracy-capture` with a small time window.

### `TRACY_PROFILE_MEMORY` build makes everything slow
**Symptom:** frame times are much worse than expected even at idle; the allocation profile tab dominates.
**Cause:** build has `TRACY_PROFILE_MEMORY=1`, which instruments every alloc.
**Fix:** use a plain `TRACY_ENABLE` build unless you specifically want allocation profiling.

### Can't tell if a build has Tracy
**Symptom:** launched the "tracy" build but nothing appears in the profiler.
**Quick check:** search BAR's chat / infolog for the line `Tracy: No support detected, replacing tracy.* with function stubs.` from `luaui/system.lua:18`. **Present** = non-Tracy build. **Absent** = Tracy build.

### BAR + profiler GUI on the same machine is unusable
**Symptom:** both processes fight for CPU, frames are unusable, the trace is noisy.
**Fix:** use `tracy-capture -o session.tracy -a 127.0.0.1` to record and analyse offline, or connect `tracy-profiler.exe` from a second machine on the same LAN.

### Tracy GUI binary renamed in v0.11.x (confirmed 2026-04-19)
**Symptom:** extracted `Tracy-0.11.1.7z` and found no `Tracy.exe` — instead got `tracy-capture.exe`, `tracy-csvexport.exe`, `tracy-import-chrome.exe`, `tracy-import-fuchsia.exe`, `tracy-profiler.exe`, `tracy-update.exe`.
**Cause:** Tracy renamed the binaries in v0.11. The GUI viewer (formerly `Tracy.exe`) is now **`tracy-profiler.exe`**.
**Fix:** run `tracy-profiler.exe` — that's the GUI. The others are utilities (`tracy-capture` for headless capture; import/export/update helpers).

## Unresolved gotchas

_Add dated entries here as they come up._
