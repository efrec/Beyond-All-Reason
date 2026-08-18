---
name: bar-tracy-profiling
description: Profile the engine-side cost of BAR RML UI widgets using a Tracy-enabled spring.exe and the Tracy v0.11.1 GUI on Windows. Use when a widget is slow and the Lua widget profiler shows low Lua cost (so the work is happening in the engine layer — layout, paint, font measurement).
user-invocable: true
---

# BAR Tracy Profiling — Windows workflow

BAR's Lua widget profiler (`/luaui enablewidget Widget Profiler`) only times Lua call-ins. RML widgets push real work into the engine (layout, paint, data-model reactivity) and that cost is invisible from Lua. Tracy is the only way to see it per-zone.

`tracy.ZoneBeginN` calls in `luaui/Include/rml_utilities/utils.lua` and `theme_utils.lua` label our Lua→engine boundary as named zones so you can find them in the Tracy GUI. On a non-Tracy engine the calls cost nothing at all: the loader strips `tracy.*` out of the Lua source before compiling it, so the wrappers are always on. See [Why the wrappers are free](references/lua-zone-wrappers.md#why-the-wrappers-are-free) — it also explains why a Lua-only benchmark harness will report a cost that does not exist in-game.

## TL;DR

1. **Download a Tracy-enabled `spring.exe`** from <https://engine-builds.beyondallreason.dev/index.html> for the engine tag BAR currently uses.
2. **Drop it into** `BAR/data/engine/<tag>/` replacing the normal `spring.exe` (keep a backup).
3. **Launch BAR**, then launch **`tracy-profiler.exe`** (from Tracy v0.11.1 at <https://github.com/wolfpld/tracy/releases/tag/v0.11.1> — note: in v0.11.x the GUI is named `tracy-profiler.exe`, not `Tracy.exe` like older versions) and click **Connect**. Search the zone list for `RmlUi.*`.

If something fails, see [references/tracy-pitfalls.md](references/tracy-pitfalls.md).

## 1. Which engine build do I download?

- Go to <https://engine-builds.beyondallreason.dev/index.html> and find the tag matching BAR's current engine (check `infolog.txt` line containing `Spring ` to confirm).
- Tracy-enabled builds are marked in the filename or release description. If you can't tell from the filename, there is usually a `-tracy`, `-profile`, or similar suffix — **verify the specific pattern for the current tag and record it in [references/engine-build-map.md](references/engine-build-map.md)**.
- Verification after install: start BAR, open the chat console, and look for the boot log. If Tracy is compiled in, you will NOT see the line `Tracy: No support detected, replacing tracy.* with function stubs.` (emitted from `luaui/system.lua:18`). Absence of that line = Tracy build confirmed.
- If you see the stub-detected line, you have a non-Tracy build.

## 2. Launch BAR against the alternate engine binary

- **Path**: engines live under `BAR/data/engine/<tag>/spring.exe`. Rename the shipped file to `spring_vanilla.exe` before copying the Tracy build in, so you can revert easily.
- **Auto-update trap**: the BAR launcher may re-fetch the engine on startup and clobber your swapped binary. Disable engine auto-update in launcher settings for the duration of your profiling session, or launch `spring.exe` directly with the BAR start script.
- **Confirm the right engine loaded** via the boot log as in §1.

## 3. Attach tracy-profiler.exe

- Use **Tracy v0.11.1 exactly** — protocol compatibility breaks across versions. Download `Tracy-0.11.1.7z` (Windows) and extract; the GUI binary is `tracy-profiler.exe`. (Older Tracy releases called it `Tracy.exe` — the rename happened around v0.11.)
- The archive also contains `tracy-capture.exe` (headless CLI), `tracy-csvexport.exe`, `tracy-update.exe`, and import helpers — ignore those for normal use.
- Run BAR first, then run `tracy-profiler.exe`, click **Connect**. Port 8086 by default; override via `TRACY_PORT` env var if needed.
- **`TRACY_ON_DEMAND` build**: lets you attach late without filling memory during startup. If your build does not have it, you must have Tracy connected before/at launch. If you see OOM-style behavior after ~20 minutes unattended, that's the missing `TRACY_ON_DEMAND` flag biting.

## 4. Finding RmlUi zones

- In the Tracy flame chart, click a frame you want to dissect.
- **Engine-native RmlUi zones** (confirmed on engine tag 2026.06.04): `RmlGui Update` (layout pass, inside `Update`) and `RmlGui Draw` (paint pass, inside `Draw::Screen`). The nested `Update` zones inside `RmlGui Update` are RmlUi walking its element tree — one `Update` box per element per layout pass.
- Other engine subsystems where RmlUi cost can surface: `Draw::Screen`, `Draw::Screen::InputReceivers`, `Event` (input routing into RmlUi).
- Our Lua-labelled zones appear under the `Lua::Callins::Unsynced` parent during a widget's init or theme change. Use the Find (Ctrl+F) / zone filter and search for:
  - `RmlUi.GetContext`
  - `RmlUi.OpenDataModel`
  - `RmlUi.LoadDocument`
  - `RmlUi.FirstShow`
  - `RmlUi.ApplyTheme`
- `ZoneText` on each shows the widgetId / modelName / rmlPath / themeName — that's how you attribute a zone to a specific widget.
- **To reproduce on demand**: `/luaui reload` triggers all the init zones; switching themes in the options widget fires `RmlUi.ApplyTheme`.

## 4b. Sharing trace data for analysis

Graphical flame charts are hard to communicate. To hand a trace off for analysis (to another dev, to Claude, or for a PR), use one of:

1. **Statistics panel screenshot** — in `tracy-profiler.exe`, menu **View → Find Zone** (Ctrl+F), then the **Statistics** tab. This ranks every zone by self-time / total time / count / MTPC (mean time per call). Screenshot the top 20 rows. This is the fastest way to identify which zone eats the frame.
2. **Frame time histogram** — menu **View → Statistics** shows frame-time distribution; look for bimodal distributions (some frames fine, some blown out).
3. **CSV export** — save the trace (File → Save As → `session.tracy`), then:
   ```
   tracy-csvexport.exe session.tracy > session.csv
   ```
   The CSV contains every zone with timing. Small traces (< 30s) produce CSVs that are trivial to read programmatically.
4. **Zoomed-in single-frame screenshot** — pick one "bad" frame (right-click a frame bar → zoom), and screenshot the flame chart. Useful to show nesting structure.

## 5. Headless capture (BAR and Tracy on the same box)

When BAR + Tracy GUI fight for CPU, capture instead:

```
tracy-capture -o session.tracy -a 127.0.0.1
```

Then open `session.tracy` in `tracy-profiler.exe` on the same or another machine. `tracy-capture` ships in the same v0.11.1 release archive. Capture the smallest slice possible — open the suspect widget, do the interaction, stop the capture.

## 6. When Tracy vs when the Lua widget profiler

- **Lua widget profiler** (`/luaui enablewidget Widget Profiler`) — tells you Lua cost per call-in per widget. If this shows your widget at ~0% but frames are stuttering, the cost is in the engine and you want Tracy.
- **Tracy** — tells you engine zone-level cost, including RML layout/paint attributed to a specific operation via our zone labels.
- A future game-side engine-profiler overlay (planned, not yet built) will show aggregate subsystem deltas for passive regression monitoring.

## 7. Known-bad setups

- **`TRACY_PROFILE_MEMORY` builds** are measurably slower — use only when specifically chasing an allocation problem, never for routine frame-time analysis.
- **Version mismatch** between `tracy-profiler.exe` and the engine's linked Tracy client causes silent disconnects or corrupted traces. Match v0.11.1 on both sides.
- **Low-RAM machines without `TRACY_ON_DEMAND`** will OOM in ~15–30 min. Capture short sessions or use `tracy-capture` with a hard time limit.

## 8. Adding new zones

If you find a hot Lua→engine call site that is not yet wrapped:

1. Wrap it with the pattern used in `luaui/Include/rml_utilities/utils.lua`:
   ```lua
   tracy.ZoneBeginN("RmlUi.<Operation>")
   tracy.ZoneText(tostring(contextualKey))
   <the call>
   tracy.ZoneEnd()
   ```
2. Use the naming convention `RmlUi.<Operation>` for RmlUi boundary calls, `BAR.<Subsystem>.<Operation>` for anything else.
3. Record the new wrapper in [references/lua-zone-wrappers.md](references/lua-zone-wrappers.md) (same commit as the code change) so future sessions know it exists.
4. **Never** guard with `if tracy then ...` — the engine strips `tracy.*` from the Lua source on non-Tracy builds, so the calls are already free unconditionally ([why](references/lua-zone-wrappers.md#why-the-wrappers-are-free)).

## 9. Recording durable findings

When a diagnosis yields something reusable, capture the **distilled conclusion** where it belongs in the repo — not a blow-by-blow journal:

- a layout / perf rule → `luaui/RmlWidgets/CLAUDE.md` (Performance section); it is the canonical home for RML perf doctrine.
- a Tracy-workflow gotcha → `references/tracy-pitfalls.md` (dated entry).
- a new Lua→engine zone wrapper → `references/lua-zone-wrappers.md`.

The raw, exploratory investigation log is personal research and is intentionally **not** tracked in the repo — only the distilled, reusable rule or gotcha is, so the skill stays self-contained and portable.
