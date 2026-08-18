# BAR RML doctrine (full)

Ported from `luaui/RmlWidgets/CLAUDE.md` on the `bar-ui-2.0` branch
(`mupersega/Beyond-All-Reason`, compared against upstream `master` at
https://github.com/beyond-all-reason/Beyond-All-Reason/compare/master...mupersega:Beyond-All-Reason:bar-ui-2.0),
the maintained source of truth for BAR's RML doctrine. `bar-ui-2.0` is a
UI-overhaul branch: it adds a widget generator, a live style guide, a shared
tooltip widget, a 4-theme system, and a CCG utility-class library that do
not exist in this repo yet. Every rule below is current and correct on that
branch; not every rule is *usable* here today.

## Scope

`Repo:` marks a path that exists in this checkout right now. `Base:` marks
a path that only exists on `bar-ui-2.0` — present there, absent here until
that infrastructure lands. A `Base:` rule is still correct doctrine (write
new code to match it), it just has nothing to run against yet.

Run `bash .claude/skills/rml-widgets/scripts/verify.sh` after editing this
file. It exits nonzero on a `Repo:` path that doesn't exist, and prints any
`Base:` path that now resolves here — that's the signal the infra landed
and the claims attached to it are due for re-verification.

## The model is king

Change the view by mutating the data model, never the DOM. Data binding
(`{{}}`, `data-if`, `data-visible`, `data-for`, `data-attr-*`,
`data-event-*`) is the only sanctioned way the UI updates: mutate
`dm_handle` fields, RmlUi updates the elements.

**Do not** write JS/jQuery-style DOM code (`GetElementById`,
`QuerySelector(All)`, `:SetClass`, `:SetAttribute`, `:SetProperty`,
`.inner_rml`, `AppendChild`/`RemoveChild`/`InsertBefore`) to drive ordinary
UI state. A widget that reaches for these to show/hide/update things is
built wrong; rebuild it around the model.

### The escape hatch (rare, and it must justify itself)

Exactly three cases, and no others:

1. **A documented RmlUi data-binding bug** — e.g. the toggle pattern
   (direct class swap because `data-checked` is broken inside `data-for`).
   *Temporary*: drop the escape once the bug is fixed upstream.
2. **SVG injection** — RmlUi cannot data-bind SVG attributes, so
   SVG-driven widgets construct/patch markup via the DOM. Base:
   `luaui/RmlWidgets/svg_test/` is the source example. *Permanent and
   structural* — not tech debt, never a migration target.
3. **A measured perf hot path** where data binding is proven too slow.

Every such call carries a marker on the line or directly above it:

```lua
-- rml-dom-escape: data-checked broken inside data-for (toggle pattern)
row:SetClass("enabled", state.enabled)
```

"It was easier" is not a reason.

### No `widget:` methods for UI behaviour — use model + `data-event-*`

Do not wire behaviour through `widget:SomeFunction()` invoked from inline
`onclick=`/`onkeyup=`/`onchange=`. That is a parallel, untracked control
path that fragments the widget and bypasses the model.

```rml
<button data-event-click="confirm()">OK</button>
<input data-event-keyup="onType(ev.key_identifier)" />
```
```lua
confirm = function() dm_handle.status = "ok" end,
onType  = function(ev, keyId)
    local el = ev and ev.current_element
    performFilter((el and el:GetAttribute("value")) or "")
end,
```

The model function receives the `Event` as its implicit first argument.
`data-event-*` has no `element` token (that was unique to the old inline
`onclick="widget:Fn(element)"` syntax). Use `ev.current_element` for the
element the handler is bound to; use `ev.target_element` only when you
specifically want the event's origin, which may be a child. Reading the
element this way is also how you dodge the `data-value`-commits-after-the-
event timing (RmlUi #668 — see Data Binding Gotchas below).

`widget:Initialize` / `widget:Shutdown` stay `widget:` methods — they are
engine lifecycle API, not UI-behaviour handlers, so they are *not* this
anti-pattern. Legacy widgets — Repo: `luaui/RmlWidgets/{gui_ceg_browser,
gui_decal_placer, gui_diffuse_library, gui_feature_placer, gui_map_labels,
gui_terraform_brush, gui_territorial_domination, gui_weather_brush}/` —
still call `widget:Fn` from markup. That's legacy debt to migrate, never a
pattern to copy.

## Widget file structure

Each widget lives in its own directory under `luaui/RmlWidgets/`:

```
luaui/RmlWidgets/widget_name/
    widget_name.lua     # Logic, data model, event handlers
    widget_name.rml     # Markup (HTML-like)
    widget_name.rcss    # Widget-specific styles (CSS-like)
```

Base: `luaui/RmlWidgets/rml_starter/generate-widget.sh --name widget_name`
scaffolds all three files with the canonical patterns below and is meant
to be the starting point for every new widget. It doesn't exist in this
checkout yet — until it lands, hand-build the three files against this
doctrine, and treat the scaffold's eventual output as the pattern to
converge on. Requires bash (Git Bash/WSL on Windows); no `.ps1` port by
design, one canonical script.

## Styling: utility classes by default, CCG for heavy repeats

Utility classes are the default tool for everything — colour, text,
spacing, layout, positioning. Base: browse them live via `luaui/RmlWidgets/
rml_style_guide/` (F11 → "style guide") once it lands; until then, Repo:
`luaui/RmlWidgets/terraform_shared/rml-utility-classes.rcss` is the actual
class source in this checkout.

CCG (Common Class Groups) is a small, curated set of shorthands for
utility bundles that are both frequent and heavy — `ccg.button.success`
(8+ utilities on every button) earns its place; a 2–3-utility bundle, or
one used rarely, does not. CCG groups are flat, `component.variant` to one
class string — no nested sub-components (`ccg.sheet.<v>.container/.title/
.content/.footer` was the anti-pattern; `sheet` and `container.text` were
removed for exactly this reason, so don't reintroduce that shape). Base:
enable with `useCommonClassGroups = true`, sourced from `luaui/Include/
rml_utilities/common_class_groups.lua` — none of this exists in this repo
yet, and there is no local substitute; new widgets here use plain utility
classes only, or a widget-local `my = {}` bundle (see below).

Never hard-code colors (`rgba()`/hex) in widget RCSS — use the color
utility classes.

## Lua initialization pattern

```lua
if not RmlUi then
    return
end

local widget = widget ---@type Widget
local utils = VFS.Include("luaui/Include/rml_utilities/utils.lua")

local WIDGET_ID = "widget_name"
local MODEL_NAME = "widget_name_model"
local RML_PATH = "luaui/RmlWidgets/widget_name/widget_name.rml"

local document
local dm_handle

-- Factory function — creates a fresh model table each init
local function initModel()
    return {
        someValue = "initial",

        my = {
            customStyle = "p-3 bg-darker rounded",
        },

        handleAction = function(event, arg)
            dm_handle.someValue = "updated"
        end,
    }
end

function widget:GetInfo()
    return {
        name = "Widget Name",
        desc = "Description",
        author = "Author",
        date = "2025",
        license = "GNU GPL, v2 or later",
        layer = -1000,
        enabled = false,
    }
end

function widget:Initialize()
    local result = utils.initializeRmlWidget(self, {
        widgetId = WIDGET_ID,
        modelName = MODEL_NAME,
        rmlPath = RML_PATH,
        initModel = initModel(),
        useCommonClassGroups = true,
    })
    if not result then return false end
    document = result.document
    dm_handle = result.dm_handle
    return true
end

function widget:Shutdown()
    utils.shutdownRmlWidget(self, {
        widgetId = WIDGET_ID,
        modelName = MODEL_NAME,
    }, document, dm_handle)
    document = nil
    dm_handle = nil
end

function widget:Update()
    -- Most widgets don't need this. Add it only for genuine per-frame
    -- work, and never poll game state here: express UI state through
    -- the model + data binding.
    if not dm_handle then return end
end
```

IMPORTANT — Base: this whole pattern hinges on `utils.initializeRmlWidget`/
`shutdownRmlWidget`, sourced from `luaui/Include/rml_utilities/utils.lua`,
which does not exist in this repo. None of the legacy widgets here use it.
This is the canonical target shape for when that file lands, not a
drop-in template today — a new widget in this checkout cannot call
`utils.initializeRmlWidget` as written above.

Key rules, all consequences of reload creating a fresh model:
- `initModel()` is a factory returning a new table each init.
- Model functions reference `dm_handle` directly to read/write properties.
- All model properties must be defined at init time — new keys added later
  are not bound.
- `document` and `dm_handle` are file-local upvalues.

### Reload/debug buttons: `rml_starter` only

New and generated widgets carry **no reload/debug buttons**. Base:
`luaui/RmlWidgets/rml_starter/` is meant to be the sole widget with
always-visible `reload`/`debug` buttons, as a dev convenience on the
reference widget — it isn't in this repo yet. Do not add reload/debug
buttons, `rmlDebugControls`, or debug-enabled gating to a new widget here
either; that's the rule regardless of whether the reference widget exists.

To reload/debug during development in this repo: `/luaui reload` (reloads
all widgets); the RmlUi debugger overlay lives at Options > Dev > Debug >
"RmlUi Debugger" (calls `RmlUi.SetDebugContext`).

If a model fn genuinely needs to trigger a reload, the safe pattern is a
`reloadRequested` flag the fn sets, acted on in `widget:Update` — deferred
so the model isn't torn down inside its own data-event dispatch
(use-after-free).

## RML document template

```rml
<rml>
<head>
    <title>Widget Name</title>

    <!-- Mandatory stylesheet order -->
    <link rel="stylesheet" href="../styles.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../rml-utility-classes.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../palette-standard-global.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../components.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../themes/theme-base.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../themes/theme-armada.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../themes/theme-cortex.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../themes/theme-legion.rcss" type="text/rcss" />

    <!-- Widget-specific styles last -->
    <link rel="stylesheet" href="widget_name.rcss" type="text/rcss" />
</head>
<body id="widget_name-widget" class="widget-shadow rounded-lg">
    <div id="widget-container" data-model="widget_name_model">
        <!-- All content inside the data-model wrapper -->
    </div>
</body>
</rml>
```

Base: the sheet paths above (`../styles.rcss`, `../rml-utility-classes.rcss`,
`../palette-standard-global.rcss`, `../components.rcss`,
`../themes/theme-*.rcss`) resolve to `luaui/RmlWidgets/{styles,
rml-utility-classes,palette-standard-global,components}.rcss` and
`luaui/RmlWidgets/themes/`, none of which exist here. Repo: the equivalents
in this checkout are `luaui/RmlWidgets/terraform_shared/{styles,
rml-utility-classes,palette-standard-global}.rcss` — no `components.rcss`,
no theme stylesheets, no CCG. Link the `terraform_shared` sheets instead;
drop the `components.rcss` and theme links entirely until they exist.

Conventions (apply regardless of which sheet set is linked):
- Body id: `widget_name-widget`.
- Single wrapper div with `data-model="model_name"`.
- `widget-shadow rounded-lg` on body for consistent drop shadow/rounding.

## Data binding

Full attribute table, expression syntax, transform functions, and the
generic engine gotchas (post-init attributes, top-level-only dirtying,
`{{`/`}}` always reserved, etc.) are upstream RmlUi mechanics — see
**[rmlui-data-bindings.md](rmlui-data-bindings.md)**, not restated here.

The one gotcha specific to this codebase, not the engine: **don't shadow
globals with iterator names.** `data-for="tab : tabs"` is fine;
`data-for="widget : widgets"` shadows the BAR widget-handler global
`widget` inside that scope.

The legacy anti-pattern `onclick="widget:Method()"` (found only in
pre-doctrine widgets here) is covered under "No `widget:` methods for UI
behaviour" above, not the engine's binding syntax.

### Gotchas specific to `data-for`-driven settings/config UI

A central Lua config table as source of truth, one `data-for` loop
rendering every option, generic handlers routed by element id — the shape
is fine; these are the engine traps it walks into:

1. **Coarse-step slider drag-fighting.** `change` on a range input fires
   on every mouse move during a drag, not just on step crossings. With
   `step >= 0.5` most events report the same snapped value; re-pushing it
   re-enforces `data-attr-value` and fights the drag. Guard: only
   re-push when the new value actually differs from the stored one.
2. **Hidden elements still evaluate `data-attr-*`.** `data-if` hides an
   element but RmlUi still evaluates its `data-attr-min/max/step/value`.
   A mixed slider/toggle/action loop must give every record all fields
   (type-appropriate dummy values) or you get "Could not get value from
   data variable" warnings.
3. **`shallowCopy` to dirty a `data-for` array.** Assigning the same
   table reference back to `dm_handle` may not trip dirty detection
   ("same object"). Push a new top-level array (`shallowCopy`); inner
   entries stay shared references, so in-place `entry.value = v` remains
   visible through the copy.
4. **Functions live in local Lua, never in `dm_handle`.**
   `onChange`/`onClick` can't be data-bound; keep them in the local
   config table and call them from the handler after the id lookup.
5. **Descriptions come from `Spring.I18N('ui.settings.option.<key>')`.**
   Repo: key patterns `<id>_descr`/`<id>_desc` in
   `language/en/interface.json`; Repo: the legacy
   `luaui/Widgets/gui_options.lua` records carry the exact
   `Spring.I18N()` call to copy.

Base: the widget these were diagnosed on, `luaui/RmlWidgets/
gui_options_rml/`, doesn't exist in this repo — these five are engine/
pattern truths that outlive it, not gui_options_rml-specific.

## Common Class Groups (CCG)

Base: Source `luaui/Include/rml_utilities/common_class_groups.lua` — does
not exist here. The inventory below is the current, correct one on
`bar-ui-2.0` (already pruned of the `sheet`/`container.text` anti-pattern
groups) — keep it for when CCG lands, don't treat it as speculative.

**text** — success, warning, tooltip, body, info, caption, description,
emphasis, danger

**themeText** — pill, value, caption, highlight, heading, subheading

**badge** — primary, success, warning, info, construction

**heading** — h1, h2, h3, h4, h5, h6

**button** — general, primary, success, danger, ghost

**themeButton** — primary, ghost

**panel** — general, danger, info. Built dynamically from user
style-mode options (depth/radius/border/texture); result is a flat string.

**toggle** — panel, success, danger, offSuccess, offDanger (segmented
toggle component; styles in the Base `components.rcss`)

**card** — general, primary, surface

```rml
<div data-attr-class="ccg.panel.general + ' p-3'">...</div>
<button data-attr-class="ccg.button.success + ' px-3 py-1'">Confirm</button>
<span data-attr-class="(ok ? ccg.text.success : ccg.text.danger)">{{status}}</span>
```

### Widget-specific class groups (`my`) — Repo:, use this instead of CCG today

For repeated combos within one widget, use the model's `my` table. This
is plain utility classes, not CCG, and works in this repo right now:

```lua
my = {
    codeBlock = "p-3 bg-darker rounded border border-dark-alpha text-sm",
    svgIcon = "h-2-5 w-2-5 mx-1",
},
```
```rml
<div data-attr-class="my.codeBlock + ' mt-4'">...</div>
```

## Styling conventions

Unit reference: **[rmlui-rcss-reference.md](rmlui-rcss-reference.md) →
Units**. Convention here: `dp` for all sizing/spacing, `rem` for text
sizing, `vh`/`vw` sparingly for screen-aware positioning.

### Widget positioning (RCSS)

Block layout by default (see Performance). The widget box has a definite
size, so the container doesn't need flex to fill it.

```rcss
#widget_name-widget {
    position: absolute;
    top: 100dp;
    left: 50dp;
    width: 300dp;
    height: 400dp;
    display: block;
}

#widget-container {
    display: block;
    position: relative;
    height: 100%;
    padding: 12dp;
}
```

### Color classes

> Gotcha: inline `rgba()` alpha is 0–255, not 0–1 like CSS.
> `rgba(255, 0, 0, 128)` is half-opacity red.

Theme-aware (Base: `luaui/RmlWidgets/themes/`, doesn't exist here):
`text-primary`, `bg-primary`, `border-primary`, `text-secondary`,
`bg-accent`, etc.

Fixed, Repo: `luaui/RmlWidgets/terraform_shared/palette-standard-global.rcss`:
`text-light`, `text-medium`, `bg-darker`, `bg-darkest`, `border-dark`,
`text-success`, `text-warning`, `text-danger`, `text-info`,
`bg-success-alpha`, etc.

Hover states: `hover-brighten`, `hover-darken`, `hover-fade`,
`hover-scale`. Effects: `box-shadow-sm`/`md`/`lg`,
`text-outline-darker-lg`, `radial-focus-start`, `hazards-135`,
`bg-gradient`.

> Gotcha — `border-0` reserves a border, it doesn't remove one. It's
> `border: 1dp transparent`, reserving 1dp so a coloured border can appear
> later with zero layout shift. It's bundled into every Base
> `ccg.button.*`. Dropping a button class onto a content-box element
> sized to fill a tight slot (`width`/`height: 100%`) adds 2dp and pushes
> the layout. Fix: `box-sizing: border-box`, or apply the button's
> colour/text utilities without `border-0` (a `my.*` bundle). Diagnosed
> on Base `luaui/RmlWidgets/gui_ordermenu_rml/`'s toggle buttons — not
> inspectable here, but the underlying RCSS behaviour is engine-level and
> applies regardless of which widget triggers it.

### Utility classes

Repo: `luaui/RmlWidgets/terraform_shared/rml-utility-classes.rcss`
provides Tailwind-like utilities: `flex`, `flex-col`, `items-center`,
`justify-between`, `gap-2`, `p-3`, `mt-2`, `rounded`, `border`, `text-sm`,
`font-bold`, `w-full`, `h-full`, `hidden`, `cursor-pointer`, `transition`,
etc.

### Transitions & timing functions

Syntax and timing-function names: **[rmlui-rcss-reference.md](rmlui-rcss-reference.md)
→ Animations and Transitions**. One BAR-measured addition not in that
generic reference: aggressive easing (`exponential-out`, `elastic-*`,
`bounce-*`) causes visible sub-pixel jitter on small transforms — prefer
`quadratic-out`/`cubic-out` for subtle UI shifts.

### Keyframe animations — entrance/looping motion

Base `@keyframes`/`animation` syntax: same reference, same section. Use
them (not `transition`) when motion must fire on element creation — a
freshly-created element has no "before" state to transition from, e.g.:

```rcss
.row { animation: 0.45s quadratic-out 1 slide-in; }
@keyframes slide-in {
    0%   { transform: translateX(-540dp); }
    100% { transform: translateX(0dp); }
}
```

None of what follows is in the generic reference — these are hard-won
BAR specifics, engine-level, apply regardless of Repo/Base:

- **Animate `translateX` as a length (`dp`), never a percentage.**
  Upstream RmlUi docs list `translate` as taking `<length-percentage>`,
  but a `translateX(-100%)` to `translateX(0)` keyframe pair does not
  move in practice — any `opacity` in the same keyframes still animates,
  so it looks like a fade and masks the problem. Pick a `dp` value that
  clears the element's travel (e.g. `-540dp` for a 540dp-wide drawer).
  Repo: confirmed in `luaui/RmlWidgets/gui_quick_start/` — its
  `deduction-drift` holds `translateX(-50%)` in the resting rule and
  animates `top`, `opacity`, and `font-size` instead, never the
  transform.
- **Transformed elements escape `overflow: hidden`.** Add `clip: always`
  (alongside `overflow: hidden`) on the clipping ancestor, or a
  transform-animated element paints outside its scroll container.
- **No `animation-fill-mode`** (no `forwards`/`backwards`). After a
  one-shot animation completes, the element reverts to its resting RCSS
  style — so the resting style must equal the final keyframe, or it
  visibly snaps back. During an `animation-delay` window the element
  shows its resting style, not the `0%` frame — a delayed start visibly
  flashes the resting state first.
- **Stagger via in-keyframe holds, not `animation-delay`** (because of
  the delay-flash above). Give each position its own keyframe set that
  holds the hidden state for an increasing slot, then runs the same
  slide, all starting at frame 0. Select per position with `:nth-child`:
  ```rcss
  @keyframes in    { 0%       { transform: translateX(-540dp); } 44%, 100% { transform: translateX(0dp); } }
  @keyframes in-2  { 0%, 10%  { transform: translateX(-540dp); } 54%, 100% { transform: translateX(0dp); } }
  .scroll-area > div:nth-child(2) .row { animation: 0.45s quadratic-out 1 in-2; }
  ```
- **`animation` is a shorthand only** — `<duration> <delay>? <tween>?
  [<iterations>|infinite]? alternate? paused? <name>`, no bare
  `animation-delay`/`animation-name` longhand. Keyframe percentages are
  duration-relative, so changing only the duration rescales holds and
  slide together.

Base: the staggered, flash-free reference implementation is
`gui_options_rml`'s `.panel-with-abs-heading` — not inspectable in this
repo.

### RCSS differs from CSS

Full list: **[rmlui-rcss-reference.md](rmlui-rcss-reference.md) → Key
Differences from CSS**, including the pseudo-elements correction
(`::placeholder` is *not* supported, contrary to what `CLAUDE.md` on
`bar-ui-2.0` claims — source-verified against the pinned RmlUi build,
see that file for the citation).

## Theme system

Base: 4 themes — base (yellow), armada (cyan), cortex (red), legion
(green). None of this exists in this repo yet.

Theme-specific styles use `@media (theme: name) { ... }` in RCSS; all 4
theme files must be imported per document.

```lua
local themeUtils = VFS.Include("luaui/Include/rml_utilities/theme_utils.lua")
themeUtils.setAndApplyTheme("armada")
-- or via global callback:
WG.rml_theme_changed("armada")
```

Current theme stored in Spring config:
`Spring.GetConfigString("rml_theme", "base")`.

## Key files

### Repo — exists in this checkout

| File | Purpose |
|------|---------|
| `luaui/rml_setup.lua` | Bootstraps RmlUi: loads fonts (Exo 2, Poppins), wraps `CreateContext` for DPI, sets cursor aliases |
| `luaui/RmlWidgets/rml_context_manager.lua` | Creates the `shared` context, recomputes DPI ratio on resize — simpler than the Base version, which adds theme switching and lobby overlay visibility |
| `luaui/RmlWidgets/terraform_shared/styles.rcss` | Base element defaults, `.widget-shadow` |
| `luaui/RmlWidgets/terraform_shared/rml-utility-classes.rcss` | Utility classes |
| `luaui/RmlWidgets/terraform_shared/palette-standard-global.rcss` | Fixed palette, shadows, gradients, textures |
| `luaui/RmlWidgets/rml_stress_test/` | The perf-testing harness — see the `rml-stress-test` skill |
| `luaui/RmlWidgets/{gui_ceg_browser,gui_decal_placer,gui_diffuse_library,gui_feature_placer,gui_map_labels,gui_quick_start,gui_terraform_brush,gui_territorial_domination,gui_weather_brush}/` | Legacy widgets, predate this doctrine (inline `widget:` handlers, unmarked DOM calls) — read for engine behaviour, not convention |

### Base — designer base only, absent here today

| File | Purpose |
|------|---------|
| `luaui/Include/rml_utilities/utils.lua` | `initializeRmlWidget()`, `shutdownRmlWidget()`, `combineClasses()` |
| `luaui/Include/rml_utilities/common_class_groups.lua` | CCG definitions |
| `luaui/Include/rml_utilities/theme_utils.lua` | `GetCurrentTheme()`, `setAndApplyTheme()`, `getAvailable()`, `isValid()` |
| `luaui/Include/rml_utilities/EzSVG.lua` | SVG generation library |
| `luaui/Include/rml_utilities/{svg_shapes,svg_decorators}.lua` | Decoration shapes (see Decoration Patterns) |
| `luaui/RmlWidgets/{styles,rml-utility-classes,palette-standard-global,components}.rcss` | Shared sheets at the widget-root level; `components.rcss` holds the segmented toggle and range slider |
| `luaui/RmlWidgets/themes/theme-{base,armada,cortex,legion}.rcss` | Per-theme overrides |
| `luaui/RmlWidgets/svg/` | Shared SVG assets (pin, filter, bin, copy) |
| `luaui/RmlWidgets/rml_starter/` | Generator + tutorial widget — canonical pattern source |
| `luaui/RmlWidgets/rml_style_guide/` | Live catalog of every utility class and CCG group |
| `luaui/RmlWidgets/rml_tooltip_layer/` | Shared tooltip overlay — `WG['rml_tooltip'].Show(text, x, y[, title])` / `.Hide()` |
| `luaui/RmlWidgets/svg_test/` | SVG-injection example (the sanctioned DOM-escape case) |
| `luaui/RmlWidgets/gui_options_rml/` | Historical case study for the block-vs-flex performance rules below; `enabled = false` even on `bar-ui-2.0` |
| `luaui/RmlWidgets/gui_ordermenu_rml/` | Source of the `border-0` gotcha above |

## Performance in a game context

RmlUi layout runs on the engine's render thread. Every element added to
the DOM costs layout time per frame; hover/show/hide interactions trigger
relayout. At 60+ FPS this is felt as input lag and frame drops — web-dev
patterns fine in a browser are expensive here. Engine-level; applies
regardless of Repo/Base.

### Prefer shared elements over per-item elements

Bad — N tooltip elements inside a `data-for` loop, each with CSS
hover show/hide:
```rml
<div data-for="item : items" class="row">
    <span>{{item.name}}</span>
    <div class="tooltip">{{item.desc}}</div>
</div>
```

Good — one shared element outside the loop, updated via a model value:
```rml
<div data-for="item : items" class="row" data-event-mouseover="setHovered(item.desc)">
    <span>{{item.name}}</span>
</div>
<div data-if="hoveredDesc != ''">{{hoveredDesc}}</div>
```

Applies to any pattern where information varies per-item but only one is
visible at a time (tooltips, detail panels, previews).

Base: for tooltips specifically, don't even build the shared element —
`luaui/RmlWidgets/rml_tooltip_layer/` already provides one, always
enabled: `WG['rml_tooltip'].Show(text, springX, springY[, title])` /
`.Hide()`. Not usable in this repo yet — until it lands, a widget here
that needs tooltips has to build its own shared element following the
pattern above.

### Prefer `display: block` — avoid flex wherever possible

Block layout is single-pass: children flow top-to-bottom, each sized
independently. Flex — especially `flex-direction: column` with
content-sized children — is multi-pass, and nested flex-column compounds
(a 4-level content-sized flex hierarchy can trigger 16+ layout passes per
frame).

Default to `display: block` for everything; reach for flex only when
load-bearing. This is the single biggest layout-perf lever. Base: the
options widget went from ~300ms layout time to near-instant swapping
nested flex-column for block with `margin-bottom` and hard-coded row
heights — case study lives in `gui_options_rml`, not inspectable here,
but the technique transfers directly.

```rcss
/* BAD — flex column, multi-pass layout */
.panel {
    display: flex;
    flex-direction: column;
    gap: 3dp;
}

/* GOOD — block layout, single-pass */
.panel {
    display: block;
}
.panel > div {
    margin-bottom: 3dp;
}
```

Flex is justified in exactly two cases:
1. A container needing a child to fill remaining space via `flex: 1`
   (e.g. a scroll area consuming leftover height in a fixed-height
   widget).
2. Horizontal column splits, `flex-direction: row` with `flex: <number>`
   children — those children are themselves `display: block`.

When flex is justified: use `flex: <number>` on flex items (sets
`flex-basis: 0`, skips content measurement — see [upstream
docs](https://mikke89.github.io/RmlUiDoc/pages/rcss/flexboxes.html#performance));
give the cross-axis a definite size; never nest flex-column inside
flex-column.

Hard-code heights on repeated rows — any element appearing many times
(list rows, option cards, toggle rows) gets an explicit `height` in RCSS,
eliminating content measurement:
```rcss
.slider-card { height: 22dp; }
.toggle-card { height: 20dp; }
.select-card { height: 22dp; }
```

Scroll containers are block, not flex column — use
`overflow: hidden scroll` with block-flow children.

### General rules

- Minimize total DOM element count, especially inside `data-for` loops.
- Prefer updating a model value over toggling visibility on many
  elements.
- Avoid CSS hover rules that trigger layout changes.
- Use `data-if` to remove rarely-needed elements from the DOM entirely.
- Default to `display: block`; flex only for the two cases above.
- Hard-code heights on any repeated element.

## Direct DOM manipulation (escape hatch API)

Not a normal tool — the escape hatch defined above, only the three
sanctioned cases, only with a `-- rml-dom-escape: <reason>` marker.

```lua
-- rml-dom-escape: <one-line technical reason matching a sanctioned case>
local element = document:GetElementById("my-element")
element:SetClass("active", true)
```

Before writing any of this: can a model field plus data binding express
this? It almost always can, and then that's what you must do. Ask again
before copying a DOM call from an existing widget — it may not carry a
marker either.

### Validation

Repo: `bash .github/rml-widgets/scripts/lint-widgets.sh` flags an
unmarked DOM call on changed lines; `--all` sizes the existing baseline
across every widget file (expect roughly a thousand findings — mostly
`svg_test`-style SVG injection, the sanctioned case). That baseline is a
known quantity, not a migration target — the marker is what separates a
sanctioned escape from a defect. New and changed code follows the rule
above regardless of what the baseline looks like.

## Decoration patterns

Three techniques for angled/structural visual decoration (tapers,
chamfers, diagonal edges, notches):

1. **SVG shape, container-scaled** — Base: `svg_shapes.lua` +
   `svg_decorators.lua`. Parameterizable at runtime (`depth`, `side`,
   `fill`, `outline`), but the viewBox stretches non-uniformly under
   `preserveAspectRatio="none"`, so diagonal angles distort with
   container aspect ratio.
2. **Rotated `<div>` + parent `clip: always`** — pure CSS, no
   dependencies. An oversized rotated child is positioned mostly outside
   the parent; the parent's `clip: always` cuts the visible portion to a
   straight diagonal at exactly the rotation angle, stable across
   container size. Base: canonical example at `rml_style_guide.rcss:49-105`.
3. **Hybrid SVG + overhang clip** — SVG shape sized to its intended
   visible dimensions, positioned with small negative offsets so the
   parent clips the viewBox boundary cleanly. Base: example
   `svg_test.lua` → `buildAngleDecoratorSVG`.

Trade-off: pick 2 when the angle must stay stable across variable
container sizes (and it's the only one usable without the Base examples);
pick 1 when you need runtime parameterization; pick 3 only if already on
1 and hitting sub-pixel edge artifacts.

Both SVG approaches (1 and 3) build markup through the DOM — that's the
sanctioned SVG-injection escape case, so both need the `-- rml-dom-escape:
SVG injection` marker (see Direct DOM Manipulation above).
