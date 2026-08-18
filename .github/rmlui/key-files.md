# Key files

## Repo

| Path | Purpose |
|------|---------|
| `luaui/rml_setup.lua` | Bootstrap: loads fonts (Poppins, `fonts/exo2`), wraps `CreateContext` for `dp_ratio`, sets cursor aliases |
| `luaui/RmlWidgets/rml_context_manager.lua` | Creates the `shared` context, recomputes `dp_ratio` on `ViewResize`; the base version adds theme switching and lobby overlay visibility |
| `luaui/RmlWidgets/terraform_shared/styles.rcss` | Base element defaults, `.widget-shadow` |
| `luaui/RmlWidgets/terraform_shared/rml-utility-classes.rcss` | Utility classes |
| `luaui/RmlWidgets/terraform_shared/palette-standard-global.rcss` | Fixed palette, shadows, gradients, textures |
| `luaui/RmlWidgets/gui_*/` | `ceg_browser`, `decal_placer`, `diffuse_library`, `feature_placer`, `map_labels`, `quick_start`, `terraform_brush`, `territorial_domination`, `weather_brush` |

These widgets predate this doctrine: inline `on*="widget:"` handlers, `data-model` on `<body>`, unmarked DOM calls. Read them for engine behaviour, not for convention.

## Base

| Path | Purpose |
|------|---------|
| `luaui/Include/rml_utilities/utils.lua` | `initializeRmlWidget()`, `shutdownRmlWidget()`, `combineClasses()` |
| `luaui/Include/rml_utilities/common_class_groups.lua` | CCG definitions |
| `luaui/Include/rml_utilities/theme_utils.lua` | `GetCurrentTheme()`, `setAndApplyTheme()`, `getAvailable()`, `isValid()` |
| `luaui/Include/rml_utilities/EzSVG.lua` | SVG generation |
| `luaui/Include/rml_utilities/{svg_shapes,svg_decorators}.lua` | Decoration shapes (see ./decoration.md) |
| `luaui/RmlWidgets/{styles,rml-utility-classes,palette-standard-global,components}.rcss` | Shared sheets; `components.rcss` holds the segmented toggle and range slider |
| `luaui/RmlWidgets/themes/theme-{base,armada,cortex,legion}.rcss` | Per-theme overrides, in `@media (theme: name)` |
| `luaui/RmlWidgets/svg/` | Shared SVG assets (pin, filter, bin, copy) |

Widgets:

- `rml_starter/generate-widget.sh` — scaffolds a widget; its output is the canonical pattern.
- `rml_starter/` — tutorial widget: tabs, collapse, reload, debug.
- `rml_style_guide/` — every class group and utility class, live.
- `rml_tooltip_layer/` — the shared tooltip overlay, always enabled (see ./performance.md).
- `gui_options_rml/` — `enabled = false`, predates current doctrine. The block-layout rules were measured on it; do not copy it.
