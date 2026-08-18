---
name: rmlui
description: Guidance for building and testing RML widgets in Beyond All Reason.
---

# Overview

RMLUI is a web-like UI framework for C++. It provides HTML1 and CSS2 with some conveniences of HTML5 and CSS3 and some custom extensions. Though experience from web frameworks is transferable to RML documents, users are expected to author documents specifically for RMLUI.

## Contents

- The model is king
- File structure
- Styling
- RML document template
- Data binding

## The model is king

IMPORTANT: Change the view via the data model, never via DOM.

Data binding (`{{}}`, `data-if`, `data-visible`, `data-for`, `data-attr-*`, `data-event-*`) is the only sanctioned way the UI updates. You mutate `dm_handle` fields, and RmlUi updates the elements.

### DOM manipulation

IMPORTANT: Do not write JS/jQuery-style DOM code (`GetElementById`, `QuerySelector(All)`, `:SetClass`, `:SetAttribute`, `:SetProperty`, `.inner_rml`, `AppendChild`/`RemoveChild`/`InsertBefore`) to drive UI state. A widget that reaches for these to show/hide/update must be rebuilt around the model.

DOM manipulation is permitted when genuinely unavoidable. That means exactly three cases:

1. **Documented RmlUi data-binding bugs.** The proven toggle pattern (direct class swap because `data-checked` inside `data-for` is broken). *Temporary:* drop the escape if the bug is fixed upstream.
2. **SVG injection.** Building or patching an inline SVG. *Structural:* RmlUi cannot data-bind SVG attributes. SVG-driven widgets (e.g. `svg_test`) must construct/patch markup via the DOM. This is expected and correct.
3. **Measured performance hot paths.** When data binding is proven slow.

IMPORTANT: Every such case must carry a justification marker at the call site with a simple, one-line, explicit reason:

```lua
-- rml-dom-escape: data-checked broken inside data-for (toggle pattern)
row:SetClass("enabled", state.enabled)
```

"It was easier" is not a reason.

For guidance on using the API for this task, read ./dom-manipulation.md.

### UI behaviour uses `data-event-*`

IMPORTANT: Do not invoke `widget:Method` callins from inline `onclick=` / `onkeyup=` / `onchange=` handlers. Inline `on*=` + widget methods are a parallel, untracked control path that fragments the widget and bypasses the data model.

Instead: Define the function in the table returned by `initModel()` and invoke it via `data-event-*`:

```rml
<button data-event-click="confirm()">OK</button>
<input data-event-keyup="onType(ev.key_identifier)" />
```

```lua
-- inside the table returned by initModel():
confirm = function() dm_handle.status = "ok" end,
onType  = function(ev, keyId)
    local el = ev and ev.current_element -- the element the handler is on
    performFilter((el and el:GetAttribute("value")) or "")
end,
```

The model function receives the `Event` as its implicit first argument, `ev`.

`data-event-*` has no `element` token; this is unique to the inline `onclick="widget:Fn(element)` syntax. For an element the handler is bound to, use `ev.current_element`. For the element that was the event's *origin*, use `ev.target_element`, but be careful: This may be a child element the user actually clicked; getting this wrong silently misfires on handler elements with children. Reading elements this way is how you dodge the `data-value` bugged timing for commits-after-event; see Critical Gotchas. Older widgets still use `widget:Fn`; this is legacy debt to migrate and never copy.

Keep the engine lifecycle methods `widget:Shutdown` / `widget:Initialize`. They are not UI-behaviour handlers, so they are *not* the anti-pattern.

## File structure

Start every new widget using bash (on Windows: Git Bash or WSL) with the generator script at `rml_starter/generate-widget.sh --name widget_name`. It scaffolds three starter files with canonical patterns embodying every rule in this document.

Each RMLUI widget has its own directory under `luaui/RmlWidgets/`:

```
luaui/RmlWidgets/widget_name/
    widget_name.lua     # Logic, data model, event handlers
    widget_name.rml     # Markup (HTML-like)
    widget_name.rcss    # Widget-specific styles (CSS-like)
```

For the content layout of each file, see ./file-structure.md.

## Styling

Styling uses RCSS, a variant of CSS for RMLUI. See ./rcss-differences.md for full reference on where they diverge.

### Utility classes by default, CCG for heavy repeats

IMPORTANT: Utility classes are the default tool for styling. Color, text, spacing, layout, and positional styles are utility classes. Browse them live via the `rml_style_guide` widget (F11 -> "style guide").

IMPORTANT: Common Class Groups (CCG) are a small, curated set of shorthands for utility class bundles that are *used often* and *aggregate many utilities*. Use these when one semantic name removes *real* repetition, and browse them before utility classes.

CCG is a DRY shorthand. It is not a parallel "component system" and not the opposite of layout. Enable with `useCommonClassGroups = true` to get `ccg.*` in the model.

For example, `ccg.button.success` earns its place: 8+ utilities on every button. A group of 2–3 utilities, or a large group used rarely, do not.

Do not nest subcomponents in CCG groups. They are flat; one semantic name -> one class string.

`ccg.button.success` is good. A group with a hidden multi-part structure is an anti-pattern that forces a layout contract on the user. New groups must be flat (`component.variant → string`), must be frequent, and must be heavy.

For repeated combos *within one widget*, add to the model's `my = { … }` bundle instead of global CCGs.

### Colors

Never hard-code colors (`rgba()`/hex) in widget RCSS. Use the color utility classes.

### Units

- **`dp`** — density-independent pixels, scales with DPI. Use for all sizing and spacing.
- **`vh`/`vw`** — viewport-relative. Use sparingly for screen-aware positioning.
- **`rem`** — relative to base font size. Available for text sizing (`text-sm-rem`).

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

Conventions:
- Body id: `widget_name-widget`
- Single wrapper div with `data-model="model_name"`
- `widget-shadow rounded-lg` on body for consistent drop shadow and rounding

## Data binding

| Syntax | Purpose | Example |
|--------|---------|---------|
| `{{var}}` | Text interpolation | `<span>{{playerName}}</span>` |
| `data-if="expr"` | Conditional display (removes from layout) | `<div data-if="expanded">...</div>` |
| `data-visible="expr"` | Conditional visibility (keeps layout space) | `<div data-visible="showStar">...</div>` |
| `data-for="item : array"` | Array iteration | `<div data-for="tab : tabs">{{tab.label}}</div>` |
| `data-attr-class="expr"` | Dynamic class binding | `data-attr-class="'btn w-full ' + (active ? 'bg-primary' : 'bg-darker')"` |
| `data-attrif-name="bool"` | Set attribute when true, remove when false | `<button data-attrif-disabled="!canSubmit">` |
| `data-class-name="bool"` | Toggle a single CSS class | `data-class-loading="isLoading"` |
| `data-style-prop="expr"` | Dynamic CSS property | `data-style-width="progress + '%'"` |
| `data-rml="expr"` | Set inner RML (can inject markup) | `<div data-rml="statusHtml"></div>` |
| `data-value="var"` | Two-way input binding (no expressions) | `<input data-value="playerName" />` |
| `data-checked="var"` | Two-way checkbox/radio binding | `<input type="checkbox" data-checked="enabled" />` |
| `data-event-click="fn()"` | Call model function on event | `data-event-click="handleAction(item.id)"` |
| `data-event-mousedown="fn()"` | Any DOM event (`mousedown`, `change`, `mouseover`, ...) | `data-event-mousedown="setTab(tab.id)"` |
| ~~`onclick="widget:Method()"`~~ | **Anti-pattern — do not use.** Put the function in the model, invoke via `data-event-*` (see "The model is king"). Found only in legacy widgets. | — |

Conditional class example (utility classes):
```rml
<button data-attr-class="'tab-btn px-3 py-1 rounded ' + (active ? 'bg-primary text-light' : 'bg-darker text-medium')">
    {{tab.label}}
</button>
```

### Expression syntax

Data binding expressions (in `data-if`, `data-for`, `data-attr-*`, `data-event-*`, etc.) use a small expression language, **not Lua**:

- **String literals use single quotes**: `'hello'`, not `"hello"`. Double quotes are the RML attribute delimiter.
- **String concatenation is `+`**: `'Player ' + name`. Works if either operand is a string.
- **Transform pipes** for formatting: `radius | round`, `name | to_upper`, `value | format(2)`. Chain them: `i * 3.14 | round | format(2)`.
- **Operators** (in precedence order): `!`, `* /`, `+ -`, `== != < <= > >=`, `&& ||`, `|` (pipe), `? :` (ternary).
- **Built-in transforms**: `to_upper`, `to_lower`, `round`, `format(precision, removeTrailingZeros?)`.

### Data binding gotchas

- **`data-if` needs `display` defined.** The element's stylesheet must set `display` to something other than `none`, or the element stays hidden regardless of the expression.
- **`data-value` and `data-checked` don't support expressions.** For complex logic, use `data-attr-value` + `data-event-change`.
- **Only top-level vars can be dirtied.** After mutating `items[3].name` you dirty `"items"`, not `"items[3].name"`.
- **Mutate the driving array, never the DOM inside a `data-for`.** Updating the underlying Lua table and dirtying the top-level variable is the supported workflow — the engine reuses loop elements and rebinds them. Manually calling `AppendChild`/`RemoveChild`/`inner_rml` on elements inside a data-binding region is undefined behavior and can crash.
- **No post-init `data-*` attributes.** Adding data bindings to an element after the document loads has no effect.
- **Don't shadow globals with iterator names.** `data-for="tab : tabs"` is fine; `data-for="widget : widgets"` shadows the global `widget`.
- **`{{` and `}}` are reserved anywhere in RML** — they're always parsed as data bindings, even inside comments or script blocks.

## Common Class Groups (CCG)

CCG is a curated DRY shorthand for the few utility bundles that are used often *and* aggregate many utilities. It is not a component framework and not a default — utilities are the default; CCG just spares rereading a heavy, frequently-repeated bundle.

With `useCommonClassGroups = true`, all CCG definitions are available in RML as `ccg.component.variant` — predefined bundles of utility classes. **Every group is flat** (`component.variant → string`); there are deliberately no nested sub-component groups. The inventory below is intentionally small; new entries must clear the "frequent AND heavy" bar or they don't belong here.

Source: `luaui/Include/rml_utilities/common_class_groups.lua`

### Component inventory

Intentionally small — every entry is here because it's frequently used *and* a heavy aggregation. Speculative/unused variants were pruned; **do not re-add a variant without a real consumer**.

**text** — success, warning, tooltip, body, info, caption, description, emphasis, danger

**themeText** — pill, value, caption, highlight, heading, subheading

**badge** — primary, success, warning, info, construction

**heading** — h1, h2, h3, h4, h5, h6

**button** — general, primary, success, danger, ghost

**themeButton** — primary, ghost

**panel** — general, danger, info. Built dynamically from user style-mode options (depth/radius/border/texture); the *result* is still a flat string. Use it for full panel backgrounds; use utilities for simple containers.

**toggle** — panel, success, danger, offSuccess, offDanger (segmented toggle component; styles in `components.rcss`)

**card** — general, primary, surface

### Usage in RML

```rml
<!-- Component via CCG -->
<div data-attr-class="ccg.panel.general + ' p-3'">...</div>
<button data-attr-class="ccg.button.success + ' px-3 py-1'">Confirm</button>

<!-- Conditional -->
<span data-attr-class="(ok ? ccg.text.success : ccg.text.danger)">{{status}}</span>
```

### Widget-specific class groups

For repeated class combinations within a widget, define them in the model under `my`:

```lua
my = {
    codeBlock = "p-3 bg-darker rounded border border-dark-alpha text-sm",
    svgIcon = "h-2-5 w-2-5 mx-1",
},
```

Then use in RML: `data-attr-class="my.codeBlock + ' mt-4'"`

The `my` bundle pattern uses **plain utility classes** — it is *not* CCG and *is* the recommended way to share class combos in new widgets. (The generator scaffolds an empty `my = {}` for this.)

## Styling Conventions

### Widget positioning (in RCSS)

Block layout by default (see the Performance section). The widget box has a definite size, so the container does not need flex to fill it.

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
    position: relative;   /* anchor for absolutely-positioned children */
    height: 100%;
    padding: 12dp;
}
```

### Color classes

> **Gotcha**: When writing inline `rgba()` in RCSS, **alpha is 0–255**, not 0–1 like CSS. `rgba(255, 0, 0, 128)` is half-opacity red.

**Theme-aware** (change per faction theme): `text-primary`, `bg-primary`, `border-primary`, `text-secondary`, `bg-accent`, etc.

**Fixed** (global palette, theme-independent): `text-light`, `text-medium`, `bg-darker`, `bg-darkest`, `border-dark`, `text-success`, `text-warning`, `text-danger`, `text-info`, `bg-success-alpha`, etc.

**Hover states**: `hover-brighten`, `hover-darken`, `hover-fade`, `hover-scale`

**Effects**: `box-shadow-sm`/`md`/`lg`, `text-outline-darker-lg`, `radial-focus-start`, `hazards-135`, `bg-gradient`

### Utility classes

`rml-utility-classes.rcss` provides Tailwind-like utilities: `flex`, `flex-col`, `items-center`, `justify-between`, `gap-2`, `p-3`, `mt-2`, `rounded`, `border`, `text-sm`, `font-bold`, `w-full`, `h-full`, `hidden`, `cursor-pointer`, `transition`, etc.

> **Gotcha — `border-0` reserves a border (it doesn't remove one).** `.border-0` is `border: 1dp transparent` — it *reserves* a 1dp border so a coloured border can later appear with zero layout shift. It's bundled into every `ccg.button.*`. So dropping a button class onto a content-box element sized to fill a tight slot (`width/height: 100%`) adds 2dp and pushes the layout. Fix: `box-sizing: border-box` (the reserved border then draws inside), or apply the button's colour/text utilities **without** `border-0` (e.g. a `my.*` bundle). Diagnosed on the order-menu toggle buttons.

### Transitions & Timing Functions

Syntax: `transition: <property> <duration> [<timing-function>]`

Available timing functions, each with `-in`, `-out`, `-in-out` variants:
`back`, `bounce`, `circular`, `cubic`, `elastic`, `exponential`, `linear`, `quadratic`, `quartic`, `quintic`, `sine`

Use `linear-in-out` when you want constant speed.

```rcss
.element {
    transition: transform 0.15s quadratic-out;
    transition: opacity 0.2s linear-in-out;
    transition: all 0.3s cubic-in-out;
}
```

> **Gotcha**: Transitions only fire on **class or pseudo-class changes**, not on arbitrary property changes. Updating a property via `data-style-*` or direct element style mutation will NOT trigger the transition. Animate by toggling a class (e.g. `data-class-active="isActive"`) and define the transition on that class.

**Caution**: Aggressive easing curves (`exponential-out`, `elastic-*`, `bounce-*`) can cause visible sub-pixel jitter on small transforms like `translateX(5dp)`. Prefer `quadratic-out` or `cubic-out` for subtle UI shifts.

### Keyframe Animations (`@keyframes`) — entrance/looping motion

Use `@keyframes` + the `animation` property (not `transition`) when motion must fire on **element creation** — e.g. items appearing in a `data-for` loop, a tab's content (re)populating, search results rendering. Transitions can't do this: they only fire on a class/pseudo change (see the gotcha above), and a freshly-created element has no "before" state to transition from. Animations play immediately on mount, which is exactly what entrance motion needs.

```rcss
.row { animation: 0.45s quadratic-out 1 slide-in; }   /* <duration> <tween> <iterations> <name> */
@keyframes slide-in {
    0%   { transform: translateX(-540dp); }
    100% { transform: translateX(0dp); }
}
```

Hard-won BAR specifics (these cost a long debugging session — trust them):

- **Animate `translateX` as a LENGTH (`dp`), never a percentage.** RmlUi interpolates length transforms but does **not** reliably interpolate a `translateX(%)` — a `translateX(-100%) → translateX(0)` keyframe pair simply does not move (any `opacity` in the same keyframes still animates, so it looks like a fade, masking the problem). Pick a `dp` value that clears the element's travel (e.g. `-540dp` for a 540dp-wide drawer). Confirmed in-repo: `gui_quick_start`'s `deduction-drift` keeps its `translateX(-50%)` *constant* and only animates a `dp`/length axis.
- **Transformed elements escape `overflow: hidden`.** A panel parked/sweeping off-screen via `translateX` will paint outside its scroll container (e.g. over the tab rail) unless you add **`clip: always`** (alongside `overflow: hidden`) to the clipping ancestor — the documented RmlUi way to force-clip transformed children. This is what lets a slide-in be a pure transform with no opacity-fade crutch.
- **No `animation-fill-mode`.** RmlUi has neither `forwards` nor `backwards`, and this dictates how you stage things:
  - *After* a one-shot animation completes, the element **reverts to its resting (RCSS) style**. So the resting style must equal the final keyframe (e.g. no `transform` override on the rule == `translateX(0)` == the `100%` frame), or the element visibly snaps back when the animation ends.
  - *During* an `animation-delay` window, the element shows its **resting style** (not the `0%` frame) — so a delayed start visibly flashes the resting state before animating.
- **Stagger a cascade via in-keyframe holds, NOT `animation-delay`.** Because of the delay-flash above, don't use `animation-delay` for a staggered list. Instead give each position its own keyframe set that *holds* the hidden state for an increasing slot, then runs the same slide — all starting at frame 0. Select per position with `:nth-child` (supported). Cap it (e.g. 6) and let later items fall back to the no-hold base keyframe so long lists don't over-delay:
  ```rcss
  @keyframes in    { 0%       { transform: translateX(-540dp); } 44%, 100% { transform: translateX(0dp); } }
  @keyframes in-2  { 0%, 10%  { transform: translateX(-540dp); } 54%, 100% { transform: translateX(0dp); } }
  .scroll-area > div:nth-child(2) .row { animation: 0.45s quadratic-out 1 in-2; }
  ```
- **`animation` is a shorthand only.** RmlUi parses `animation: <duration> <delay>? <tween>? <iterations>? <name>` — there is no bare `animation-delay`/`animation-name` longhand. Keyframe percentages are duration-relative, so changing only the duration rescales holds + slide together.

Reference example: the staggered, flash-free slide-in on `gui_options_rml`'s `.panel-with-abs-heading` (option-group entrance).

## Theme System

4 themes: **base** (yellow), **armada** (cyan), **cortex** (red), **legion** (green).

Theme-specific styles use `@media (theme: name) { ... }` in RCSS. All 4 theme files must be imported in every RML document.

To switch themes programmatically:
```lua
local themeUtils = VFS.Include("luaui/Include/rml_utilities/theme_utils.lua")
themeUtils.setAndApplyTheme("armada")
-- or via global callback:
WG.rml_theme_changed("armada")
```

Current theme is stored in Spring config: `Spring.GetConfigString("rml_theme", "base")`

## Key Files

| File | Purpose |
|------|---------|
| `Include/rml_utilities/utils.lua` | `initializeRmlWidget()`, `shutdownRmlWidget()`, `combineClasses()` |
| `Include/rml_utilities/common_class_groups.lua` | CCG definitions — all semantic component class bundles |
| `Include/rml_utilities/theme_utils.lua` | `GetCurrentTheme()`, `setAndApplyTheme()`, `getAvailable()`, `isValid()` |
| `Include/rml_utilities/EzSVG.lua` | SVG generation library |
| `rml_context_manager.lua` | Manages shared context, DPI ratio, theme switching, lobby overlay visibility |
| `rml_setup.lua` (in `luaui/`) | Bootstraps RmlUi: loads fonts (Exo 2, Poppins), wraps CreateContext for auto DPI, sets cursor aliases |
| `components.rcss` | Shared reusable component styles (segmented toggle, range slider) |
| `styles.rcss` | Base element defaults (body font, h1-h3, inputs, scrollbars) |
| `rml-utility-classes.rcss` | Tailwind-like utility classes |
| `palette-standard-global.rcss` | Global color palette (fixed colors, shadows, gradients, textures) |
| `themes/theme-*.rcss` | Per-theme color overrides (`@media (theme: name)`) |
| `svg/` | Shared SVG assets (pin, filter, bin, copy icons) |
| `rml_tooltip_layer/` | Shared global tooltip overlay widget (always enabled). API: `WG['rml_tooltip'].Show(text, x, y[, title])` / `.Hide()` |

## Reference Widgets

**Start here**:
- **`rml_starter/generate-widget.sh`** — run it to scaffold a new widget. Its output *is* the canonical pattern (block layout, utility classes by default + CCG only for heavy repeats, no debug UI, no per-frame polling).
- **rml_style_guide** — interactive library of every CCG component and utility class; the fastest way to see what's available.
- **rml_starter** — tutorial widget demonstrating core data-binding patterns: tabs, collapse, reload, debug.

**Production examples**:
- **rml_tooltip_layer** — shared tooltip overlay, always enabled. Don't build your own hover tooltips — call `WG['rml_tooltip'].Show(text, x, y[, title])` / `.Hide()` (see the shared-elements performance rule).

> The block-layout performance patterns below were *proven on* the old `gui_options_rml` widget. That widget is `enabled = false` ("Options RML (V1 heavy)"), predates current doctrine, and is **not part of the designer base** — treat it as a historical case study, not a widget to open and copy. New widgets get block layout for free from the generator.

## Performance in a Game Context

RmlUi layout runs on the engine's render thread. Every element added to the DOM costs layout time per frame, and hover/show/hide interactions trigger relayout. In a game running at 60+ FPS this matters — unlike web apps, jank here means gameplay feels sluggish.

### Prefer shared elements over per-item elements

**Bad** — N tooltip elements inside a `data-for` loop, each with CSS hover show/hide:
```rml
<div data-for="item : items" class="row">
    <span>{{item.name}}</span>
    <!-- This creates N invisible tooltip elements in the DOM -->
    <div class="tooltip">{{item.desc}}</div>
</div>
```

**Good** — one shared element outside the loop, updated via a model value:
```rml
<div data-for="item : items" class="row" data-event-mouseover="setHovered(item.desc)">
    <span>{{item.name}}</span>
</div>
<!-- Single element, updated by changing one model string -->
<div data-if="hoveredDesc != ''">{{hoveredDesc}}</div>
```

This applies to any pattern where information varies per-item but only one is visible at a time (tooltips, detail panels, previews). Updating a model string is far cheaper than maintaining N hidden elements with CSS hover rules.

**For tooltips, don't even build the shared element — one already exists.** The always-enabled `rml_tooltip_layer` widget provides a single global overlay. From any widget, on hover call `WG['rml_tooltip'].Show(text, springX, springY)` and on mouse-out call `WG['rml_tooltip'].Hide()` (pass an optional 4th `title` argument for a titled tooltip). This is the canonical, perf-correct way to do tooltips in BAR RML — see `rml_style_guide` for the hover→`Show` / mouseout→`Hide` pattern. Never place per-row tooltip elements inside a `data-for`.

### Prefer `display: block` — avoid flex wherever possible

Block layout is **single-pass**: children flow top-to-bottom, each sized independently, the parent never measures children to know their positions. Flex layout — especially `flex-direction: column` with content-sized children — is **multi-pass**, and nested flex-column compounds exponentially (a 4-level deep content-sized flex hierarchy can trigger 16+ layout passes per frame). In a game UI at 60+ FPS this is directly felt as input lag and frame drops.

**Default to `display: block` for everything.** Only reach for flex when it's genuinely load-bearing. This is the single biggest layout-perf lever in the RML widgets — the options widget went from ~300ms layout time to near-instant by swapping nested flex-column for block with `margin-bottom` and hard-coded row heights. Do not apply web-dev patterns here — what's fine in a browser is expensive in this engine.

**Never use flex-column for simple vertical stacking:**
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
    margin-bottom: 3dp;  /* replaces gap */
}
```

**The only cases where flex is justified:**
1. A container that needs a child to fill remaining space via `flex: 1` (e.g., a scroll area that must consume the leftover height inside a fixed-height widget).
2. Horizontal column splits using `flex-direction: row` with `flex: <number>` children. The children themselves must be `display: block` — never nest flex-column inside flex-column.

**When you do use flex, these rules still apply:**
- Use `flex: <number>` (e.g., `flex: 1`) on flex items — this sets `flex-basis: 0`, skipping the content measurement pass entirely. See [upstream docs](https://mikke89.github.io/RmlUiDoc/pages/rcss/flexboxes.html#performance).
- Give the cross-axis a definite size (definite height in row layout, definite width in column layout).
- Never nest flex-column inside flex-column. Never rely on deeply nested flex containers each sizing from their children's content.

**Hard-code heights on repeated rows.** Any element that appears many times (list rows, option cards, toggle rows) MUST have an explicit `height` in RCSS. This eliminates content measurement entirely — the layout engine knows the size without inspecting children. The options widget uses:
```rcss
.slider-card { height: 22dp; }
.toggle-card { height: 20dp; }
.select-card { height: 22dp; }
```

**Scroll containers are block, not flex column.** Use `overflow: hidden scroll` with block-flow children. A flex-column scroll container forces the engine to measure total content height for flex distribution before it can even start scrolling.

This section is the canonical, complete statement of the RML layout-performance rules — there is no separate "fuller" version to consult.

### General rules
- Minimize total DOM element count, especially inside `data-for` loops
- Prefer updating a model value over toggling visibility on many elements
- Avoid CSS hover rules that trigger layout changes (opacity is cheaper than display toggling, but a single shared element is cheapest)
- Use `data-if` to remove elements from DOM entirely rather than hiding with opacity/display when the element is rarely needed
- Default to `display: block`; only use flex for the two cases above (fill-remaining-space and horizontal column splits)
- Hard-code heights on any element that appears repeatedly (list rows, cards) — skip content measurement

## Decoration Patterns

Three distinct techniques in this codebase for adding angled/structural
visual decoration (tapers, chamfers, diagonal edges, notches):

1. **SVG shape, container-scaled** — `svg_shapes.lua` library + cached
   `svg_decorators.lua` helpers. Parameterizable at runtime (`depth`,
   `side`, `fill`, `outline`), but the viewBox stretches non-uniformly
   under `preserveAspectRatio="none"`, so diagonal angles distort with
   container aspect ratio.
2. **Rotated `<div>` + parent `clip: always`** — pure CSS pattern,
   canonical example at `rml_style_guide.rcss:49-105`. An oversized
   rotated child is positioned mostly outside the parent; the parent's
   `clip: always` cuts the visible portion to a straight diagonal at
   exactly the rotation angle. Angle stays stable across any container
   size. Supports theme-color fill via utility classes and `@keyframes`
   animation.
3. **Hybrid SVG + overhang clip** — SVG shape sized to its intended
   visible dimensions, positioned with small negative offsets so the
   parent clips the viewBox boundary cleanly. Sub-pixel edge cleanup
   trick, niche. In-repo example: `svg_test.lua` → `buildAngleDecoratorSVG`.

**Trade-off in one line**: pick Approach 2 when the angle must stay
stable across variable container sizes; pick Approach 1 when you need
runtime parameterization; pick Approach 3 only if you're already on
Approach 1 and hitting sub-pixel edge artifacts.

**This section is the authoritative reference for decoration approaches.**
The three techniques above — with the one-line trade-off and the in-repo
example file:lines (`rml_style_guide.rcss:49-105`, `svg_test.lua`) — are the
complete guidance. For deeper rationale, read those example widgets' source.
