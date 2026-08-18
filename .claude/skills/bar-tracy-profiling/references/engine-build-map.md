# Engine build map — which tags ship Tracy

Which RecoilEngine tags ship a Tracy-enabled `spring.exe`, and where to get them. Update the table via a normal commit when you verify a build.

## Verification recipe for any build

1. Replace `spring.exe` under `BAR/data/engine/<tag>/` with the candidate build (back up the original first).
2. Launch BAR.
3. Open chat / infolog.
4. Look for the line `Tracy: No support detected, replacing tracy.* with function stubs.` (from `luaui/system.lua:18`).
   - **Present** → non-Tracy build.
   - **Absent** → Tracy build. ✅
5. Optionally: open `tracy-profiler.exe` and confirm connection.

## Known Tracy build flags (from recoilengine.org/development/profiling-with-tracy)

- `TRACY_ENABLE` — activates Tracy instrumentation
- `TRACY_ON_DEMAND` — enables late attach; use this for long sessions to avoid OOM
- `TRACY_PROFILE_MEMORY` — adds allocation tracking; expensive, opt-in only
- `RECOIL_DETAILED_TRACY_ZONING` — extra detail zones for engine debugging; verbose trace

The ideal build has `TRACY_ENABLE=1` + `TRACY_ON_DEMAND=1` with the other two off.

## Known builds

_Populate as builds are downloaded and verified. Keep the table tight._

| Engine tag | Release date | Tracy-enabled artefact name | `TRACY_ON_DEMAND`? | Verified | Notes |
|---|---|---|---|---|---|
| _TBD_ | _TBD_ | _TBD_ | _TBD_ | _TBD_ | _TBD_ |

## Target tags

- **Current BAR engine** — whichever tag `infolog.txt` reports on launch today. Priority 1.
- **2026.06.06** (<https://github.com/beyond-all-reason/RecoilEngine/releases/tag/2026.06.06>) — check whether it adds a dedicated RmlUi profiler record by comparing `Spring.GetProfilerRecordNames()` output to the engine subsystem record map.

## Sources

- Recoil docs on building with Tracy: <https://recoilengine.org/development/profiling-with-tracy/>
- Engine builds index: <https://engine-builds.beyondallreason.dev/index.html>
- Tracy GUI v0.11.1 (Windows): <https://github.com/wolfpld/tracy/releases/tag/v0.11.1>
