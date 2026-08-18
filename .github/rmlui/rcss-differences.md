# RCSS differs from CSS

RCSS is based on CSS2 with selected CSS3 features — **not full CSS**. If a CSS feature silently isn't working, check here:

- **`rgba()` alpha is 0–255**, not 0–1 (see Color classes above).
- **Borders are always solid.** No `border-style` property; `border: 1dp <color>` is the only form.
- **No `background-image`.** Use decorators (`decorator: image(...)`).
- **`background` only sets `background-color`** — it's not a shorthand for background-image etc.
- **`:hover`, `:active`, `:focus` propagate through parents** (unlike CSS). Hovering a child puts the parent into `:hover` too.
- **`opacity` is inherited** (unlike CSS).
- **Only `::placeholder` is supported as a pseudo-element.** No `::before`, `::after`, `::first-letter`.
- **No `order` property for flex items.** No `flex-basis: content`.
- **`inline-flex` needs a definite width**, otherwise it collapses.
- **No nested `@media`**, no CSS Level 4 media query syntax (`<=`, `>=`).
- **Transitions only fire on class/pseudo-class changes** (see Transitions above).
- **`@keyframes` translate must use a length, not `%`** — `translateX(%)` doesn't interpolate; transformed elements also need `clip: always` on an ancestor to respect `overflow: hidden` (see Keyframe Animations above).
