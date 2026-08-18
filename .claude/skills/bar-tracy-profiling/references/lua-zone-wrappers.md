# Lua-side `tracy.ZoneBeginN` wrappers — canonical inventory

Every wrapper is **free** on shipped binaries and produces real zones on Tracy builds. Never guard with `if tracy then ...`. The mechanism is source stripping in the engine loader, *not* the stubs in `luaui/system.lua:17-26` — see [Why the wrappers are free](#why-the-wrappers-are-free) before trusting any Lua-only benchmark of wrapped code.

When you add a new wrapper, update this file in the same commit so the wrapper set stays discoverable in one place.

## Why the wrappers are free

On an engine built without `TRACY_ENABLE`, the loader deletes `tracy.*` call sites from the **Lua source text** before it is compiled. The call does not exist at runtime, so the cost is zero — not "one cheap no-op call".

- `LuaUtils::TracyRemoveAlsoExtras` (`rts/Lua/LuaUtils.cpp:1972`) runs upstream `tracy::LuaRemove`, then, under `#ifndef TRACY_ENABLE`, wipes Recoil's own `tracy.LuaTracyPlot` / `tracy.LuaTracyPlotConfig` the same way. Wiping = overwriting the call with spaces in the buffer.
- It is applied on every path that loads Lua through the engine: `CLuaHandle::LoadCode` (`rts/Lua/LuaHandle.cpp:540`), `LuaParser.cpp:240` and `:651`, `LuaVFS.cpp:346` and `:424` — so `VFS.Include`d files are covered too.
- The stubs at `luaui/system.lua:17-26` are a fallback for anything the stripper does not reach. They are not the reason the calls are free, and on a normal in-game run they are never entered.

**Consequence for benchmarks.** A harness that runs this Lua outside the engine — busted, standalone PUC Lua, any rig that claims to test the Lua alone — has no stripper. It executes the `system.lua` stubs as real function calls and reports per-call overhead that does not exist in-game. Integration testing in a real engine shows no such cost. Never size a wrapper from a Lua-only benchmark; if you need a number, measure in-engine on a non-Tracy build.

## Naming convention

- `RmlUi.<Operation>` — Lua → RmlUi engine calls
- `BAR.<Subsystem>.<Operation>` — everything else (reserved; none added yet)

Zone names land in Tracy's flame chart and are searchable. Keep them stable across widgets; don't invent per-widget variants.

## Canonical wrapper inventory

### `luaui/Include/rml_utilities/utils.lua`

| Zone name | Wrapped call | `ZoneText` | Line (as of 2026-04-19) |
|---|---|---|---|
| `RmlUi.GetContext` | `RmlUi.GetContext("shared")` | `widgetId` | 49-52 |
| `RmlUi.OpenDataModel` | `rmlContext:OpenDataModel(...)` | `modelName` | 72-75 |
| `RmlUi.LoadDocument` | `rmlContext:LoadDocument(...)` | `rmlPath` | 81-84 |
| `RmlUi.FirstShow` | `document:ReloadStyleSheet(); document:Show()` (pair) | `rmlPath` | 91-95 |

### `luaui/Include/rml_utilities/theme_utils.lua`

| Zone name | Wrapped call | `ZoneText` | Line (as of 2026-04-19) |
|---|---|---|---|
| `RmlUi.ApplyTheme` | entire body of `applyTheme` after the early `if not RmlUi` return | `themeName` | ~75 onward |

## Wrap pattern

```lua
tracy.ZoneBeginN("RmlUi.<Operation>")
tracy.ZoneText(tostring(contextualKey))
<the call>
tracy.ZoneEnd()
```

- Put `ZoneEnd` before any `return` that sits inside the zone — no early-return across a zone.
- Pass only one `ZoneText` per zone; it accepts a single string.
- `tostring()` the context key so nil / tables don't crash the wrapper.

## Rules for adding new wrappers

1. **Only wrap Lua → engine boundary calls** — wrapping a pure-Lua function adds no signal to Tracy.
2. **One-shot lifecycle calls are free to wrap** (init, shutdown, theme change). Per-frame calls need more scrutiny.
3. **Don't wrap** `applyWidgetContainerClasses`, `shutdownRmlWidget`, per-frame data-model writes (yet) — lower priority, and per-frame volume clutters the trace.
4. **Record every new wrapper here** with line numbers, in the same commit as the code change, so the wrapper set is discoverable in one place.

## Deferred wrap candidates (v2+)

- `utils.dmSet(dm, key, value)` — a conventional wrapper around data-model writes. Requires inventing the helper and migrating widgets.
- `document:SetClass(class, bool)` inside `applyWidgetContainerClasses` — only if profiling confirms it's a hot path.
- `RmlUi.SetDebugContext` — already opt-in, low frequency; skip unless the debugger overlay is a measured cost.

## Scenario markers in `rml_stress_test`

`luaui/RmlWidgets/rml_stress_test/rml_stress_test.lua` emits tracy zones of the form `StressTest.<Kind>.<variant>.<param>` to mark which scenario is mounted. These are **scenario markers**, not boundary wrappers — a distinct category from the `RmlUi.*` set above.

Zones emitted:
- `StressTest.Clear`
- `StressTest.Flat.<plain|ccg>.<count>` — e.g. `StressTest.Flat.plain.500`
- `StressTest.Grid.<plain|ccg>.<rows>x<cols>` — e.g. `StressTest.Grid.ccg.20x20`
- `StressTest.Deep.<plain|ccg>.<depth>` — e.g. `StressTest.Deep.plain.30`
- `StressTest.FlexCol.<depth>` — nested flex-column anti-pattern
- `StressTest.StageVisible.<true|false>` — toggles `display: none` on the stage

Plus `tracy.Message("StressTest: ...")` entries that appear as discrete flags on the Tracy timeline — correlate "time after this flag" with "RmlGui Update / Draw cost at this element count."

Reading pattern: isolate a frame AFTER one of the messages, then read `RmlGui Update` and `RmlGui Draw` self-time. Compare across messages to quantify per-element cost and plain-vs-CCG overhead.
