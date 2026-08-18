---
name: rmlui
description: Guidance for building and testing RML widgets in Beyond All Reason.
---

# RMLUI widgets

RMLUI is a web-like UI framework for C++. It provides HTML1 and CSS2 with some conveniences of HTML5 and CSS3 and some custom extensions. Though experience from web frameworks is transferable to RML documents, users are expected to author documents specifically for RMLUI.

This file holds the rules. The reference files hold the templates, tables, and worked examples. Together they are the complete guidance; no fuller version exists elsewhere. RmlUi behaviour is verified against RmlUi 6.2, the engine's pinned `rts/lib/RmlUi` at `2230d1a6e8`.

## Scope

The rules are the designer base's. `Repo:` marks what this repo has, `Base:` marks paths that resolve only in the base.

Path check: `.github/rmlui/verify.sh`.

Repo:

- `luaui/RmlWidgets/*/` — widgets predating this doctrine
- `luaui/RmlWidgets/terraform_shared/{styles,rml-utility-classes,palette-standard-global}.rcss`
- `luaui/rml_setup.lua`, `luaui/RmlWidgets/rml_context_manager.lua`

Base:

- `luaui/Include/rml_utilities/{utils,common_class_groups,theme_utils,EzSVG,svg_shapes,svg_decorators}.lua`
- `luaui/RmlWidgets/{styles,rml-utility-classes,palette-standard-global,components}.rcss`
- `luaui/RmlWidgets/themes/theme-{base,armada,cortex,legion}.rcss`
- `luaui/RmlWidgets/{rml_starter,rml_style_guide,rml_tooltip_layer,gui_options_rml,svg_test}/`

## Reference files

- ./file-structure.md — the Lua, RML, and RCSS contents of a widget
- ./data-binding.md — binding attributes, event handlers, expressions, gotchas
- ./dom-manipulation.md — the escape hatch API, and validating existing widgets
- ./styling.md — utility classes, class groups, colors, themes
- ./rcss-differences.md — where RCSS diverges from CSS
- ./animation.md — transitions and keyframes
- ./performance.md — layout cost and the rules that follow from it
- ./decoration.md — angled decoration techniques
- ./key-files.md — includes, stylesheets, shared widgets, reference widgets

## The model is king

IMPORTANT: Change the view through the data model, never through the DOM.

Data binding (`{{}}`, `data-if`, `data-visible`, `data-for`, `data-attr-*`, `data-event-*`) is the only sanctioned way the UI updates. You mutate `dm_handle` fields, and RmlUi updates the elements.

### DOM manipulation

IMPORTANT: Do not write JS/jQuery-style DOM code (`GetElementById`, `QuerySelector(All)`, `:SetClass`, `:SetAttribute`, `:SetProperty`, `.inner_rml`, `AppendChild`/`RemoveChild`/`InsertBefore`) to drive UI state. A widget that reaches for these to show, hide, or update must be rebuilt around the data model.

Three cases, and no others, are unavoidable:

- **Data-binding bugs** — the toggle pattern swaps a class directly because `data-checked` is broken inside `data-for`. Drop the escape once the bug is fixed upstream.
- **SVG injection** — RmlUi cannot bind SVG attributes, so SVG-driven widgets construct and patch that markup through the DOM. This is expected and correct.
- **Measured hot paths** — data binding proven slow by measurement.

Mark every such call site with a one-line technical reason.

```lua
-- rml-dom-escape: data-checked broken inside data-for (toggle pattern)
row:SetClass("enabled", state.enabled)
```

"It was easier" is not a reason.

Read ./dom-manipulation.md for the API and for validating existing widgets.

### Event handlers

IMPORTANT: Do not invoke `widget:Method` callins from inline `onclick=`, `onkeyup=`, or `onchange=` attributes. Inline handlers are a parallel, untracked control path that fragments the widget and bypasses the data model.

Define the handler in the table returned by `initModel()` and bind it with `data-event-*`:

```rml
<button data-event-click="confirm()">OK</button>
```

```lua
confirm = function() dm_handle.status = "ok" end,
```

Older widgets still call `widget:Fn` from markup. That is legacy debt to migrate, and never to copy. The engine lifecycle methods `widget:Initialize` and `widget:Shutdown` are not UI behaviour, so they are not this anti-pattern.

Read ./data-binding.md for the event argument, element access, and the rest of the binding attributes.

## File structure

IMPORTANT: Start every new widget with the generator. Run `rml_starter/generate-widget.sh --name widget_name` in bash (Git Bash or WSL on Windows). It scaffolds three files carrying the canonical patterns of this document.

Each widget owns a directory under `luaui/RmlWidgets/`:

```
luaui/RmlWidgets/widget_name/
    widget_name.lua     # Logic, data model, event handlers
    widget_name.rml     # Markup (HTML-like)
    widget_name.rcss    # Widget-specific styles (CSS-like)
```

Read ./file-structure.md for the contents of each file: the Lua initialization pattern, the RML document template and its mandatory stylesheet order, the RCSS positioning block, and the reload and debug rules.

## Data binding

Bindings are attributes on RML elements. `{{var}}` interpolates text; `data-if` and `data-visible` show and hide; `data-for` iterates; `data-attr-*`, `data-class-*`, and `data-style-*` write attributes, classes, and properties; `data-value` and `data-checked` bind inputs both ways; `data-event-*` calls model functions. Attribute values are a small expression language, not Lua: single-quoted strings, `+` for concatenation, ternaries, and transform pipes such as `radius | round`.

Only top-level model variables can be dirtied. After mutating `items[3].name` you dirty `"items"`.

IMPORTANT: Mutate the array driving a `data-for`, never the elements it produced. Calling `AppendChild`, `RemoveChild`, or `inner_rml` inside a data-binding region is undefined behaviour and can crash.

Read ./data-binding.md for the attribute table, the expression operators and transforms, and the gotchas.

## Styling

Styling uses RCSS, a variant of CSS for RMLUI.

IMPORTANT: Utility classes are the default tool for styling. Color, text, spacing, layout, and positional styles are utility classes. Browse them live in the `rml_style_guide` widget (F11 -> "style guide").

Never hard-code a color (`rgba()` or hex) in widget RCSS. Use the color utility classes.

Common class groups (CCG) are a curated shorthand for the few utility bundles that are both frequent and heavy: `ccg.button.success` earns its place by carrying 8+ utilities onto every button. Enable them with `useCommonClassGroups = true` and read them in markup as `ccg.component.variant`. A bundle of two or three utilities, or a heavy bundle used rarely, earns nothing.

Every class group is flat, one semantic name to one class string. CCG is a DRY shorthand, not a parallel component system; a group with hidden multi-part structure forces a layout contract on the user.

For combinations repeated within one widget, extend the model's `my` bundle with plain utility classes instead of adding a group.

Units:

- **`dp`** — density-independent pixels, scaling with DPI. Use for all sizing and spacing.
- **`vh`, `vw`** — viewport-relative. Use sparingly, for screen-aware positioning.
- **`rem`** — relative to base font size, available for text sizing (`text-sm-rem`).

Four themes ship: base (yellow), armada (cyan), cortex (red), and legion (green). Theme-specific rules live in `@media (theme: name)` blocks.

Read ./styling.md for the class group inventory, the color and utility class families, and the theme API. Read ./rcss-differences.md for where RCSS differs from CSS. Read ./decoration.md for angled decoration: tapers, chamfers, and notches.

## Animation

IMPORTANT: A transition fires only on a class or pseudo-class change. A property changed through `data-style-*` or through element style mutation does not transition; animate by toggling a class.

Use `@keyframes` and the `animation` property when motion must fire on element creation — rows appearing in a `data-for`, a tab repopulating, search results rendering — because a fresh element has no prior state to transition from.

Read ./animation.md for timing functions, the animation shorthand, and the keyframe rules proven in this repo.

## Performance

RmlUi layout runs on the engine's render thread. Every element costs layout time per frame, and hover, show, and hide interactions trigger relayout. At 60+ FPS that cost is felt as input lag, so web-dev layout habits are too expensive here.

IMPORTANT: Use `display: block` by default. Flex layout is multi-pass and nested flex-column compounds; it is justified only for a child filling remaining space (`flex: 1`) and for horizontal column splits.

Give every repeated element (list rows, cards, toggle rows) an explicit `height` in RCSS, so the engine skips content measurement.

Prefer one shared element updated through the model over N per-item elements. For tooltips the shared element already exists: call `WG['rml_tooltip'].Show(text, x, y[, title])` and `WG['rml_tooltip'].Hide()`.

Read ./performance.md for these rules in full, with the flex exceptions and before/after examples.

## Key files

Read ./key-files.md for the includes, shared stylesheets, shared widgets, and the reference widgets worth copying from.
