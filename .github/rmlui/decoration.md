# Decoration

Angled and structural decoration — tapers, chamfers, diagonal edges, notches — is done three ways in this codebase. This file is the complete guidance on them; for deeper rationale, read the example widgets named here.

1. **SVG shape, container-scaled** — Base: `luaui/Include/rml_utilities/{svg_shapes,svg_decorators}.lua`. Parameterizable at runtime (`depth`, `side`, `fill`, `outline`), but the viewBox stretches non-uniformly under `preserveAspectRatio="none"`, so diagonal angles distort with the container's aspect ratio.
2. **Rotated `div` plus parent `clip: always`** — a pure RCSS pattern. Base: `luaui/RmlWidgets/rml_style_guide/rml_style_guide.rcss:49-105`. An oversized rotated child sits mostly outside the parent, and the parent's `clip: always` cuts the visible portion to a straight diagonal at exactly the rotation angle. The angle stays stable at any container size, and it supports theme-color fill through utility classes and `@keyframes` animation.
3. **Hybrid SVG plus overhang clip** — an SVG shape sized to its intended visible dimensions and positioned with small negative offsets, so the parent clips the viewBox boundary cleanly. A sub-pixel edge cleanup trick, and niche. Base: `luaui/RmlWidgets/svg_test/svg_test.lua`, `buildAngleDecoratorSVG`.

The trade-off in one line: take 2 when the angle must stay stable across variable container sizes, take 1 when you need runtime parameterization, and take 3 only when you are already on 1 and hitting sub-pixel edge artifacts.

Approaches 1 and 3 build markup through the DOM, which is the sanctioned SVG injection case; carry the `rml-dom-escape` marker (see ./dom-manipulation.md).
