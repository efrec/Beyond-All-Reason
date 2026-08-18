# Performance

IMPORTANT: Block layout by default, shared elements over per-item elements, fixed heights on repeats. Read the section `Performance` in SKILL.md before this.

RmlUi layout runs on the engine's render thread. Every element added to the DOM costs layout time per frame, and hover, show, and hide interactions trigger relayout. In a game at 60+ FPS that is felt as input lag and frame drops, so patterns that are fine in a browser are expensive here.

## Shared elements over per-item elements

**Bad** — N tooltip elements inside a `data-for` loop, each with CSS hover show and hide:

```rml
<div data-for="item : items" class="row">
    <span>{{item.name}}</span>
    <!-- This creates N invisible tooltip elements in the DOM -->
    <div class="tooltip">{{item.desc}}</div>
</div>
```

**Good** — one shared element outside the loop, updated through a model value:

```rml
<div data-for="item : items" class="row" data-event-mouseover="setHovered(item.desc)">
    <span>{{item.name}}</span>
</div>
<!-- Single element, updated by changing one model string -->
<div data-if="hoveredDesc != ''">{{hoveredDesc}}</div>
```

This applies wherever information varies per item but only one is visible at a time: tooltips, detail panels, previews. Updating a model string is far cheaper than maintaining N hidden elements with CSS hover rules.

For tooltips the shared element already exists, so do not even build one. Base: `luaui/RmlWidgets/rml_tooltip_layer/`, always enabled. It provides a single global overlay: on hover call `WG['rml_tooltip'].Show(text, springX, springY)`, on mouse-out call `WG['rml_tooltip'].Hide()`, and pass an optional 4th `title` argument for a titled tooltip. `rml_style_guide` shows the hover-to-`Show`, mouseout-to-`Hide` pattern.

## Block layout, not flex

Block layout is single-pass: children flow top to bottom, each sized independently, and the parent never measures children to know their positions. Flex layout, especially `flex-direction: column` with content-sized children, is multi-pass, and nested flex-column compounds exponentially — a four-level deep content-sized flex hierarchy can trigger 16+ layout passes per frame.

Default to `display: block` for everything and reach for flex only when it is load-bearing. This is the single biggest layout-perf lever in the RML widgets: the options widget went from ~300ms layout time to near-instant by swapping nested flex-column for block with `margin-bottom` and fixed row heights.

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

Flex is justified in exactly two cases:

1. A container that needs a child to fill remaining space via `flex: 1`, e.g. a scroll area consuming the leftover height inside a fixed-height widget.
2. Horizontal column splits, `flex-direction: row` with `flex: <number>` children. Those children are themselves `display: block`.

When flex is justified, these still hold:

- **Use `flex: <number>`** (e.g. `flex: 1`) on flex items. It sets `flex-basis: 0`, skipping the content measurement pass entirely. See the [upstream docs](https://mikke89.github.io/RmlUiDoc/pages/rcss/flexboxes.html#performance).
- **Give the cross-axis a definite size** — a definite height in row layout, a definite width in column layout.
- **Never nest flex-column inside flex-column**, and never rely on deeply nested flex containers each sizing from their children's content.

## Fixed heights on repeats

Any element that appears many times (list rows, option cards, toggle rows) has an explicit `height` in RCSS. This eliminates content measurement: the layout engine knows the size without inspecting children.

```rcss
.slider-card { height: 22dp; }
.toggle-card { height: 20dp; }
.select-card { height: 22dp; }
```

Scroll containers are block, not flex column: use `overflow: hidden scroll` with block-flow children. A flex-column scroll container forces the engine to measure total content height for flex distribution before it can start scrolling.

## General rules

- Minimize total DOM element count, especially inside `data-for` loops.
- Prefer updating a model value over toggling visibility on many elements.
- Avoid CSS hover rules that trigger layout changes. Opacity is cheaper than display toggling, but a single shared element is cheapest.
- Use `data-if` to remove rarely-needed elements from the DOM entirely, rather than hiding them with opacity or display.
- Default to `display: block`, and use flex only for the two cases above.
- Hard-code heights on any element that appears repeatedly, to skip content measurement.
