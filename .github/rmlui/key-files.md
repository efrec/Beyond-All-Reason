# Key files

## Includes

| File | Purpose |
|------|---------|
| `Include/rml_utilities/utils.lua` | `initializeRmlWidget()`, `shutdownRmlWidget()`, `combineClasses()` |
| `Include/rml_utilities/common_class_groups.lua` | CCG definitions, all semantic component class bundles |
| `Include/rml_utilities/theme_utils.lua` | `GetCurrentTheme()`, `setAndApplyTheme()`, `getAvailable()`, `isValid()` |
| `Include/rml_utilities/EzSVG.lua` | SVG generation library |
| `rml_context_manager.lua` | Shared context, DPI ratio, theme switching, lobby overlay visibility |
| `rml_setup.lua` (in `luaui/`) | Bootstraps RmlUi: loads fonts (Exo 2, Poppins), wraps CreateContext for auto DPI, sets cursor aliases |

## Stylesheets

| File | Purpose |
|------|---------|
| `styles.rcss` | Base element defaults (body font, h1-h3, inputs, scrollbars) |
| `rml-utility-classes.rcss` | Tailwind-like utility classes |
| `palette-standard-global.rcss` | Global color palette (fixed colors, shadows, gradients, textures) |
| `components.rcss` | Shared reusable component styles (segmented toggle, range slider) |
| `themes/theme-*.rcss` | Per-theme color overrides, in `@media (theme: name)` |
| `svg/` | Shared SVG assets (pin, filter, bin, copy icons) |

## Reference widgets

- **`rml_starter/generate-widget.sh`** — run it to scaffold a new widget. Its output is the canonical pattern: block layout, utility classes by default with CCG only for heavy repeats, no debug UI, no per-frame polling.
- **rml_style_guide** — interactive library of every class group and utility class, and the fastest way to see what exists.
- **rml_starter** — tutorial widget covering the core data-binding patterns: tabs, collapse, reload, debug.
- **rml_tooltip_layer** — the shared tooltip overlay, always enabled. Do not build hover tooltips; call `WG['rml_tooltip'].Show(text, x, y[, title])` and `.Hide()` (see ./performance.md).
- **gui_options_rml** — the widget the block-layout rules were proven on, but `enabled = false` ("Options RML (V1 heavy)"), predating current doctrine and not part of the designer base. Read it as a historical case study, not as a widget to copy. New widgets get block layout for free from the generator.
