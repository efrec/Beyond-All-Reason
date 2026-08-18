---
name: rml-stress-test
description: Iterate on the BAR RML stress test widget (luaui/RmlWidgets/rml_stress_test/). Use when asked to add new test scenarios, investigate a specific RmlUi perf question, extend the automated suite, or widen CCG coverage. The widget is the authoritative harness for quantifying RmlUi layout/render cost — pair with the bar-tracy-profiling skill for zone-level breakdowns.
user-invocable: true
---
# RML Stress Test — iteration guide
## What the widget is
`luaui/RmlWidgets/rml_stress_test/` — a sidebar-driven harness that mounts controlled element structures into a stage and measures the resulting FPS. Purpose: quantify the cost of any RmlUi construct in isolation so we can turn hunches into numbers.
**Files:**
- `rml_stress_test.lua` — scenario dispatch, mount functions, timed-mode state, suite runner
- `rml_stress_test.rml` — sidebar with button sections + stage
- `rml_stress_test.rcss` — minimal styling; stage content is left to whatever class the scenario applies
**Companion resources:**
- ``.claude/skills/rml-widgets/SKILL.md`` (Performance section) — the canonical RML layout/perf rules these tests validate and feed back into
- `.claude/skills/bar-tracy-profiling/SKILL.md` — Tracy workflow for zone-level cost
## Architecture essentials
### Scenario dispatch
Model function `scenario(kind, arg1, arg2, arg3)` calls the file-local `dispatchScenario()`. Supported `kind` values:
| kind | args | mount fn |
|---|---|---|
| `clear` | — | `clearStage` |
| `clearresults` | — | `clearAllButtonResults` |
| `flat` | count, variant | `mountFlat` |
| `grid` | rows, cols, variant | `mountGrid` |
| `deep` | depth, variant | `mountDeep` |
| `flexcol` | depth | `mountFlexColChain` |
| `reactive` | count, mode | `mountReactive` |
| `stoptick` | — | `stopReactive` |
| `vis` | `'show'`/`'none'` | `setStageVisible` |
Each mount function calls `clearStage()` first, then uses `document:CreateElement` / `AppendChild` to build the structure. No `data-for` — direct DOM gives deterministic element counts.
### CCG variant resolution
`CCG_CLASSES[variant]` → class string applied to each mounted element. Populated in `refreshCCGClasses()` at init from `ccg.getForModel()`. Fixed variants (`plain`, `pad`, `bg`, `shadow`, etc.) are manually constructed; CCG-derived ones (`card`, `panel`) pull actual current BAR CCG strings.
### Timed mode + 5-sample FPS capture
When `timedMode` is on, any measurable scenario triggers `startTest()`. `widget:Update(dt)` accumulates elapsed time, samples `Spring.GetFPS()` once per second for `testDuration` samples, then `finishTest()` records the avg and writes it to the button's result span (via data binding: `dm_handle.results[key]`).
`testDuration` is runtime-adjustable via the 2s/3s/5s/10s picker buttons. Samples-per-second is always 1.
### Tracy markers
Every scenario emits `tracy.Message("StressTest: <scenario label>")` on start and `... avg=N` on finish. Every mount wraps with `tracy.ZoneBeginN("StressTest.<Kind>.<variant>.<param>")`. These give Tracy timeline flags that let you correlate FPS drops with zone breakdowns.
### Data-binding for results
Results are stored in `buttonResults` Lua table and committed to `dm_handle.results` as a fresh copy. Buttons display via `{{results.<key>}}` interpolation. **This pattern was chosen after direct DOM `inner_rml` writes on button-child spans didn't persist across scenario changes.** Do not revert to direct DOM for button results — data binding is load-bearing here.
### Suite runner
`SUITE_SCENARIOS` is an array of `{kind, arg1, arg2, arg3}` tuples. `startSuite()` → `advanceSuite()` → (test runs) → `finishTest` records result → `advanceSuite` for next → eventually `finishSuite()` echoes to chat, renders to stage, and updates `suiteStatus`.
## How to add a new test variant (recipe)
Say we want to add a `shadow-md` flat test at 500 count.
1. **Add class string in `refreshCCGClasses()`:**
   ```lua
   CCG_CLASSES.shadowmd = PLAIN_CLASS .. " box-shadow-md"
   ```
2. **Add result key to `ALL_RESULT_KEYS`:**
   ```lua
   "flat_500_shadowmd",
   ```
   `resultKeyFor("flat", 500, "shadowmd")` returns `"flat_500_shadowmd"` already — no Lua change needed beyond the key list.
3. **Add button + result span in the RML** (inside an appropriate section):
   ```rml
   <button class="stress-btn" data-event-click="scenario('flat', 500, 'shadowmd')">shadow-md<span class="btn-result">{{results.flat_500_shadowmd}}</span></button>
   ```
4. **Optionally add to `SUITE_SCENARIOS`:**
   ```lua
   { "flat", 500, "shadowmd" },
   ```
5. Reload the widget.
### Recipe: add a new scenario `kind`
1. Write a `mount<Kind>(...)` local function that calls `clearStage()`, wraps body with `tracy.ZoneBeginN` + `ZoneText`, creates elements, then `setInfo(count, modeLabel, "off")`.
2. Add a branch in `dispatchScenario()` that calls it.
3. Extend `MEASURABLE_KINDS` if timed sampling should apply.
4. Extend `resultKeyFor()` / `labelFor()` if scenarios of this kind should get inline results.
5. Add RML buttons + result spans.
### Recipe: widen CCG variant coverage
`ccg.getForModel()` returns a table with `card`, `panel`, `button`, `themeButton`, `badge`, `pill`, `circle` sub-tables keyed by variant name. Iterate in `refreshCCGClasses` and register each as `<family>_<variant>` in `CCG_CLASSES`. Generate corresponding keys in `ALL_RESULT_KEYS`. Use `data-for` in RML if the button count gets unwieldy — but prefer hardcoded buttons while the count is manageable (inline result spans require static IDs).
## Current findings snapshot (as of 2026-04-19)
Headline empirical results so far. The durable *rules* derived from these are codified in ``.claude/skills/rml-widgets/SKILL.md`` → Performance section (the canonical home); this snapshot is the at-a-glance summary:
- **Most expensive single utility class:** `box-shadow-sm` (-30% FPS on 500 elements vs plain).
- **Padding paradox:** removing `p-2` from a shadowed card *hurts* perf. Shadow cost correlates with element box size — tall elements render shadow cheaper than short ones.
- **Deep block-layout nesting is free:** depth 100 plain ≈ baseline.
- **Flex-col cliff:** 5/10/15 depths plateau around 234 FPS, depth 20 drops to 81 FPS, depth 25+ crashes BAR. Hard ceiling: ≤ 15 levels.
- **Reactive per-frame updates scale linearly with count.**
## Investigation roadmap
Ordered by value. Tick off as we land them.
- [ ] **CCG variant coverage** — individual test per variant of each CCG family (card, panel, button, themeButton, badge, pill, circle). Priority because this is what the widget is for.
- [ ] **Shadow intensity isolation** — `box-shadow-md` / `box-shadow-lg` at 500 count, compared to `box-shadow-sm`. Confirm shadow size drives cost.
- [ ] **Flex-col fine-grained** — depths 16/17/18/19 to pin the exact cliff.
- [ ] **Higher counts** — flat 5000, flat 10000 plain to extend scaling data.
- [ ] **Decorator isolation** — `radial-focus-start-feint`, `hazards-135` standalone. Likely explains part of panel's extra cost over card.
- [ ] **Content variation** — flat 500 with empty divs vs short text vs long text.
- [ ] **Hover / transition cost** — elements with `hover-brighten` or transitions, idle baseline.
- [ ] **Widget:test harness** — per-widget test protocol so the stress harness can spawn N copies of arbitrary widgets and drive each. See design note below.
## Widget:test harness (design sketch — not built)
Vision: any RML widget can opt into being stress-testable by defining:
```lua
function widget:test(spec)
    -- spec: { mode = "idle" | "tick" | "stress", iterations = N, onFrame = fn?, onComplete = fn? }
    -- Returns descriptor: { instanceCount, categoryLabel, notes }
end
```
Stress test widget becomes the driver:
1. Dropdown listing widgets that expose `widget:test`
2. User picks widget + mode + instance count
3. Stress test spawns N documents of the chosen widget's RML (via `context:LoadDocument()`)
4. Calls each instance's `widget:test(spec)` to kick off its stress mode
5. Runs timed FPS sampling across the whole session
6. Tears down via `onComplete`
This isolates two axes currently entangled: **cost-per-widget-instance** and **cost-per-element-within-widget**. Today we can only test the latter.
Implementation hurdles to consider when building:
- RmlUi context is shared (`"shared"` in BAR) — multiple documents share it fine
- Each spawned document needs a unique data-model name to avoid collision
- Widgets that register global `WG['widget_name']` tables may conflict when spawned multiple times — may need test mode to skip WG registration
- Cleanup has to be bulletproof or the stress test risks leaking documents
## Widget tests — `WG.rml_testContextOverride` convention
Widget tests enable a real BAR widget (e.g. `widget_controller`) and measure its FPS, then auto-disable it. To keep the target widget's documents out of the main `"shared"` RmlUi context, the stress test owns a second context called `"stressTest"`.
**Routing mechanism** — `luaui/Include/rml_utilities/utils.lua` in `initializeRmlWidget`:
```lua
local contextName = (WG and WG.rml_testContextOverride) or "shared"
widget.rmlContext = RmlUi.GetContext(contextName)
```
**Who sets the global:** only `rml_stress_test`, and only for the narrow window around a `widgetHandler:ToggleWidget(name)` call:
```lua
WG.rml_testContextOverride = "stressTest"
widgetHandler:ToggleWidget(targetName)  -- target's Initialize runs during this call
WG.rml_testContextOverride = nil        -- critical: clear immediately
```
**Who reads the global:** only `initializeRmlWidget`. Every other utility path (shutdown, data-model access, document methods) operates on `widget.rmlContext` directly, which is already bound to the right context by the time it's needed.
**Lifecycle:**
- Context is created lazily on the first widget test (`ensureStressTestContext`).
- `themeUtils.applyTheme(current)` runs immediately after to propagate the active theme (fresh contexts don't inherit theme state).
- After each widget test, `disableWidgetsEnabledByTest` toggles the target off AND calls `context:UnloadAllDocuments()` as belt-and-suspenders cleanup.
- On stress test `Shutdown`, same cleanup runs.
**Known limitations:**
- No visual containment. Each context renders full-screen; target widgets appear at their own RCSS-configured positions, potentially overlapping the stress test. The "see them in context" goal is only partially addressed — solve with a follow-up that makes the stress test smaller/movable.
- No context destruction API — `stressTest` persists for the session once created. `UnloadAllDocuments` is the reset.
- The override window is synchronous and narrow, but if another widget's init ran concurrently inside `ToggleWidget`, it would also route to `stressTest`. In practice this doesn't happen.
## Operating tips
- **Full-screen is OK.** The widget can be sized to cover most of the screen without guilt — it's a dev tool, not production UI. Adjust dimensions in `rml_stress_test.rcss` as needed.
- **Never reintroduce direct DOM writes for button results** — use the `dm_handle.results` data binding path. Direct DOM writes inside `<button>` children don't persist through layout invalidation.
- **Keep the widget's own sidebar cheap.** It's block layout, small flex rows, low element count. If the widget itself is expensive we're measuring noise.
- **When adding variants, mirror the Tracy zone naming:** `StressTest.<Kind>.<variant>.<param>`. Consistent names make the Tracy flame chart searchable.
- **When a finding becomes a durable rule, codify it in ``.claude/skills/rml-widgets/SKILL.md``** (Performance section) — the canonical home — and keep the snapshot above current. Raw exploratory measurements are personal research, deliberately not tracked in the repo, so the skill stays self-contained.
## Stop signs
- **Don't add scenarios that crash BAR to the auto suite.** Manual buttons with danger styling + `(crash)` label are fine; the suite must only queue tests that complete.
- **Don't mutate DOM inside a `data-for` region.** RmlUi data binding owns those elements. The stress test's stage is NOT inside data-for, so direct DOM there is fine.
- **Don't set `data-*` attributes after document load.** RmlUi ignores them. For dynamic buttons (e.g., generated via `data-for`), wire behaviour with `data-event-click="fn()"` calling a model function — the `data-for` template is parsed at document load, so the binding applies to every row the loop later produces. Do **not** reach for inline `onclick="widget:Method()"`; that is the legacy `widget:`-method anti-pattern (see ``.claude/skills/rml-widgets/SKILL.md`` → "No `widget:` methods for UI behaviour"). Get the bound element from `ev.current_element` inside the model fn.
