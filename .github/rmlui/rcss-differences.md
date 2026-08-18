# RCSS differs from CSS

RCSS is based on CSS2 with selected CSS3 features, not full CSS. When a CSS feature silently does nothing, check here:

- **`rgba()` alpha is 0–255**, not 0–1 (see ./styling.md).
- **Borders are always solid.** There is no `border-style` property; `border: 1dp <color>` is the only form.
- **No `background-image`.** Use decorators, `decorator: image(...)`.
- **`background` only sets `background-color`.** It is not a shorthand for background-image and the rest.
- **`:hover`, `:active`, and `:focus` propagate through parents**, unlike CSS. Hovering a child puts the parent into `:hover` too.
- **`opacity` is inherited**, unlike CSS.
- **There are no pseudo-elements.** No `::before`, `::after`, `::first-letter`, `::placeholder`. Form internals are styled through child selectors instead: `input #text`, `input #selection`.
- **No `order` property for flex items**, and no `flex-basis: content`.
- **`inline-flex` needs a definite width**, or it collapses.
- **No nested `@media`**, and no CSS Level 4 media query syntax (`<=`, `>=`).
- **Transitions fire only on class and pseudo-class changes** (see ./animation.md).
- **`@keyframes` transforms translate by length, not `%`.** Measured: `translateX(%)` does not interpolate. Transformed elements also need `clip: always` on an ancestor to respect `overflow: hidden` (see ./animation.md).
