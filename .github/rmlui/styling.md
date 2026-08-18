# Styling

IMPORTANT: Utility classes are the default and class groups are the exception. Read the section `Styling` in SKILL.md before this.

## Utility classes

Repo: `luaui/RmlWidgets/terraform_shared/rml-utility-classes.rcss`. It provides Tailwind-like utilities: `flex`, `flex-col`, `items-center`, `justify-between`, `gap-2`, `p-3`, `mt-2`, `rounded`, `border`, `text-sm`, `font-bold`, `w-full`, `h-full`, `hidden`, `cursor-pointer`, `transition`, and so on. The `rml_style_guide` widget lists them all live.

- **`border-0` reserves a border, it does not remove one.** `.border-0` is `border: 1dp transparent`, reserving 1dp so a coloured border can appear later with no layout shift. It is bundled into every `ccg.button.*`, so dropping a button class onto a content-box element sized to fill a tight slot (`width` or `height: 100%`) adds 2dp and pushes the layout. Fix it with `box-sizing: border-box`, which draws the reserved border inside, or apply the button's colour and text utilities without `border-0` (a `my` bundle). Diagnosed on the order-menu toggle buttons.

## Common class groups

Base: `luaui/Include/rml_utilities/common_class_groups.lua`. With `useCommonClassGroups = true`, every definition is available in RML as `ccg.component.variant`, a predefined bundle of utility classes.

The inventory is deliberately small. Every entry is here because it is frequent and a heavy aggregation; speculative variants were pruned.

- **text** — success, warning, tooltip, body, info, caption, description, emphasis, danger
- **themeText** — pill, value, caption, highlight, heading, subheading
- **badge** — primary, success, warning, info, construction
- **heading** — h1, h2, h3, h4, h5, h6
- **button** — general, primary, success, danger, ghost
- **themeButton** — primary, ghost
- **panel** — general, danger, info. Built dynamically from the user's style-mode options (depth, radius, border, texture), and the result is still one flat string. Use it for full panel backgrounds and utilities for simple containers.
- **toggle** — panel, success, danger, offSuccess, offDanger. The segmented toggle component; styles live in `components.rcss`.
- **card** — general, primary, surface

IMPORTANT: Do not add a variant without a real consumer, and do not add a group that is not both frequent and heavy. Every group is flat, `component.variant` to string; there are deliberately no nested sub-component groups.

```rml
<!-- Component via CCG -->
<div data-attr-class="ccg.panel.general + ' p-3'">...</div>
<button data-attr-class="ccg.button.success + ' px-3 py-1'">Confirm</button>

<!-- Conditional -->
<span data-attr-class="(ok ? ccg.text.success : ccg.text.danger)">{{status}}</span>
```

### Widget bundles

Class combinations repeated within one widget go in the model's `my` table, as plain utility classes. This is the recommended way to share combos in a new widget, and the generator scaffolds an empty `my = {}` for it.

```lua
my = {
    codeBlock = "p-3 bg-darker rounded border border-dark-alpha text-sm",
    svgIcon = "h-2-5 w-2-5 mx-1",
},
```

```rml
<div data-attr-class="my.codeBlock + ' mt-4'">...</div>
```

## Colors

Widget RCSS never hard-codes a color. Use these classes.

- **Theme-aware**, per faction theme, Base: `luaui/RmlWidgets/themes/` — `text-primary`, `bg-primary`, `border-primary`, `text-secondary`, `bg-accent`, and so on.
- **Fixed**, from the global palette (Repo: `luaui/RmlWidgets/terraform_shared/palette-standard-global.rcss`) — `text-light`, `text-medium`, `bg-darker`, `bg-darkest`, `border-dark`, `text-success`, `text-warning`, `text-danger`, `text-info`, `bg-success-alpha`, and so on.
- **Hover states** — `hover-brighten`, `hover-darken`, `hover-fade`, `hover-scale`.
- **Effects** — `box-shadow-sm`, `-md`, `-lg`, `text-outline-darker-lg`, `radial-focus-start`, `hazards-135`, `bg-gradient`.

In the rare RCSS that does write `rgba()`, alpha is 0–255, not 0–1 as in CSS: `rgba(255, 0, 0, 128)` is half-opacity red.

## Themes

Base: `luaui/RmlWidgets/themes/theme-{base,armada,cortex,legion}.rcss`. The theme names are `base` (yellow), `armada` (cyan), `cortex` (red), `legion` (green). Theme-specific rules go in `@media (theme: <name>)` blocks, and every RML document links all four theme stylesheets (see ./file-structure.md).

The current theme is Spring config `Spring.GetConfigString("rml_theme", "base")`. To switch it:

```lua
local themeUtils = VFS.Include("luaui/Include/rml_utilities/theme_utils.lua")
themeUtils.setAndApplyTheme("armada")
-- or via global callback:
WG.rml_theme_changed("armada")
```
