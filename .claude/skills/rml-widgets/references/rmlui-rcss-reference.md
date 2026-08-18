# RmlUi RCSS Reference
Condensed from the [official RmlUi RCSS docs](https://mikke89.github.io/RmlUiDoc/pages/rcss.html). RCSS is based on CSS2 with select CSS3 features — it is NOT full CSS.
## Units
| Unit | Description |
|------|-------------|
| `px` | 1 pixel on output medium |
| `dp` | 1 pixel scaled by dp-ratio (use for all UI sizing) |
| `em` | Relative to element font-size |
| `rem` | Relative to root (body) font-size |
| `vw` / `vh` | 1% of context width / height |
| `%` | Percentage of containing block |
## Color Formats
- Named: `red`, `blue`, `transparent`, `orange`, `grey`, etc.
- Hex: `#RGB`, `#RGBA`, `#RRGGBB`, `#RRGGBBAA`
- Functions: `rgb()`, `rgba()`, `hsl()`, `hsla()`
- **IMPORTANT**: `rgba()` alpha is **0-255** (or 0%-100%), NOT 0-1 like CSS
## Key Differences from CSS
### Not Supported
- `border-style` (all borders are solid)
- `background-image` (use decorators instead)
- `background` is alias for `background-color` only
- `text-align: justify`
- `font-style: oblique`, relative `font-weight` (`bolder`/`lighter`)
- `border-radius` percentages or elliptic corners
- `visibility: collapse`
- Pseudo-elements `::before`, `::after`, `::first-letter`, `::placeholder` (none exist; form control internals are real child elements, see Pseudo-elements below)
- CSS `order` property for flexbox
- `flex-basis: content`
- Nested `@media` rules
- CSS Level 4 media query syntax (`<=`, `>=`)
### Behaves Differently
- `:hover`, `:active`, `:focus` **propagate through parents** (unlike CSS)
- `position: fixed` = `absolute` but ignores scrolling
- `z-index` applies to **all** elements (not just positioned)
- `opacity` is **inherited** (unlike CSS)
- `overflow: hidden` — positioned/transformed elements do NOT affect clipping
- Transitions only trigger on **class/pseudo-class changes** (not arbitrary property changes)
- Collapsing margins: siblings collapse, but **nested margins do NOT**
- `inline-flex` requires a **definite (non-auto) width**
- Tweening functions use `<name>-in`/`-out`/`-in-out` (not `ease`, `cubic-bezier()`)
### RCSS-Only Properties
| Property | Values | Description |
|----------|--------|-------------|
| `drag` | `none \| drag \| drag-drop \| block \| clone` | Drag behavior |
| `tab-index` | `none \| auto` | Focus tab order |
| `image-color` | `<colour>` | Multiply color with images/decorators |
| `decorator` | See Decorators | Element skinning |
| `font-effect` | See Font Effects | Text effects |
| `clip` | `auto \| none \| always \| <number>` | Ancestor clipping control |
| `nav-up/right/down/left` | `none \| auto \| <id>` | Spatial navigation |
| `mask-image` | `none \| <decorator>` | Masking |
| `filter`, `backdrop-filter` | `<filter-function>()` | Filter effects |
| `overscroll-behavior` | `auto \| contain` | Scroll containment |
## Box Model
Standard CSS box model. `box-sizing: content-box` (default) or `border-box`.
- **Margin**: `auto` for centering, negative values allowed, percentages relative to containing block width
- **Padding**: No negative values, percentages relative to containing block width
- **Border**: Width + color only (always solid). No `border-style` property.
- **Border-radius**: `<length>` values only (no percentages, no elliptic)
- **Box-shadow**: `[<color>? <offset-x> <offset-y> <blur>? <spread>? inset?]+` (comma-separated for multiple)
## Flexbox
### Container Properties
| Property | Values | Default |
|----------|--------|---------|
| `display` | `flex \| inline-flex` | -- |
| `flex-direction` | `row \| row-reverse \| column \| column-reverse` | `row` |
| `flex-wrap` | `nowrap \| wrap \| wrap-reverse` | `nowrap` |
| `justify-content` | `flex-start \| flex-end \| center \| space-between \| space-around \| space-evenly` | `flex-start` |
| `align-items` | `flex-start \| flex-end \| center \| baseline \| space-around \| stretch` | `stretch` |
| `align-content` | `flex-start \| flex-end \| center \| space-between \| space-around \| space-evenly \| stretch` | `stretch` |
| `gap` / `row-gap` / `column-gap` | `<length> \| <percentage>` | `0px` |
### Item Properties
| Property | Values | Default |
|----------|--------|---------|
| `flex` | `auto \| none \| <grow> <shrink>? <basis>?` | `0 1 auto` |
| `flex-grow` | `<number>` | `0` |
| `flex-shrink` | `<number>` | `1` |
| `flex-basis` | `<length> \| <percentage> \| auto` | `auto` |
| `align-self` | `auto \| flex-start \| flex-end \| center \| baseline \| space-around \| stretch` | `auto` |
### Flex Shorthand
| Shorthand | Equivalent | Use Case |
|-----------|-----------|----------|
| `flex: initial` | `0 1 auto` | Content-sized, shrinks but no grow |
| `flex: auto` | `1 1 auto` | Content-sized, then grow/shrink to fill |
| `flex: none` | `0 0 auto` | Fixed content size |
| `flex: <N>` (N >= 1) | `<N> 1 0` | Proportional sizing (**best performance**) |
### Flexbox Limitations
- No `order` property
- No `flex-basis: content`
- No anonymous flex items from unwrapped text
- `inline-flex` needs definite width
- Baseline alignment is approximate
### Performance Tips
- Use `flex: <number>` shorthand for best performance
- Set definite height on items (or width in column layout)
- Avoid content-based sizing on complex items
## Visual Properties
### Display
`inline | block | inline-block | flow-root | flex | inline-flex | table | table-row | table-cell | none`
### Position
`static | relative | absolute | fixed`
`fixed` = absolute but ignores scrolling. `top/right/bottom/left/inset`: `auto | <length> | <%>`
### Overflow
`overflow-x/y`: `visible | hidden | auto | scroll`
If either axis is non-visible, clipping occurs on **both** axes.
### Visibility
`visible | hidden` — hidden preserves layout space.
### Opacity
`0` to `1`. **Inherited** in RCSS.
### Z-Index
Applies to **all** elements (not just positioned). `auto | <number>`.
## Decorators
Declared via `decorator` property. Multiple comma-separated, rendered top to bottom.
```rcss
decorator: <type>( <properties> ) <paint-area>?;
```
`paint-area`: `border-box | padding-box | content-box` (default: `padding-box`)
### Types
| Decorator | Syntax | Description |
|-----------|--------|-------------|
| `image` | `image(src orientation? fit? align-x? align-y?)` | Single image. Fit: `fill\|contain\|cover\|scale-none\|scale-down\|repeat` |
| `horizontal-gradient` | `horizontal-gradient(start-color stop-color)` | No shader required |
| `vertical-gradient` | `vertical-gradient(start-color stop-color)` | No shader required |
| `linear-gradient` | `linear-gradient(...)` | CSS-like syntax, needs shader |
| `radial-gradient` | `radial-gradient(...)` | CSS-like syntax, needs shader |
| `conic-gradient` | `conic-gradient(...)` | CSS-like syntax, needs shader |
| `ninepatch` | `ninepatch(outer-sprite, inner-sprite, edge?)` | Sprite-only, performant |
| `tiled-box` | `tiled-box(9 images...)` | 9-slice: corners fixed, edges stretch, center stretches both |
| `tiled-horizontal` | `tiled-horizontal(...)` | Single-axis tiling |
| `tiled-vertical` | `tiled-vertical(...)` | Single-axis tiling |
### @decorator Rule
```rcss
@decorator my-bg : image {
    image-src: /images/bg.png;
    image-fit: cover;
}
div { decorator: my-bg; }  /* no parentheses */
```
## Font Effects
Inherited. Multiple comma-separated, applied in reverse order.
| Effect | Syntax | Description |
|--------|--------|-------------|
| `outline` | `outline(width color)` | Text outline |
| `shadow` | `shadow(offset-x offset-y color)` | Drop shadow |
| `blur` | `blur(width color)` | Blur (set `color: transparent` to hide original) |
| `glow` | `glow(outline-width blur-width? offset-x? offset-y? color)` | Outline + blur combo |
```rcss
h1 { font-effect: outline(2px black); }
p  { font-effect: glow(3px #ee9); }
```
## Animations and Transitions
### @keyframes
```rcss
@keyframes my-anim {
    0%, 30% { background-color: #d99; }
    50%     { background-color: #9d9; }
    to      { background-color: #f9f; width: 100%; }
}
```
### animation Property
```rcss
animation: <duration> <delay>? <tweening>? [<iterations>|infinite]? alternate? paused? <keyframes-name>;
```
Duration before delay. Multiple animations comma-separated.
```rcss
#el { animation: 2s cubic-in-out infinite alternate my-anim; }
```
### transition Property
```rcss
transition: [<property>+ | all] <duration> <delay>? <tweening>?;
```
**Only triggers on class/pseudo-class changes** (not arbitrary style changes).
```rcss
#btn {
    transition: padding-left background-color transform 1.6s elastic-out;
    transform: scale(1.0);
}
#btn:hover {
    padding-left: 60px;
    transform: scale(1.5);
}
```
### Tweening Functions
Format: `<name>-in | <name>-out | <name>-in-out`
Names: `back`, `bounce`, `circular`, `cubic`, `elastic`, `exponential`, `linear`, `quadratic`, `quartic`, `quintic`, `sine`
### Transform Functions
| Function | Args |
|----------|------|
| `translate(x, y)` | `<length-percentage>` |
| `translateX/Y(v)` | `<length-percentage>` |
| `scale(x, y?)` | `<number>` |
| `scaleX/Y(v)` | `<number>` |
| `rotate(angle)` | `deg` or `rad` |
| `skew(x, y)` | `deg` or `rad` |
| `skewX/Y(angle)` | `deg` or `rad` |
| `perspective(d)` | `<length>` |
`transform-origin`: `<x> || <y>` (default: `50% 50%`). Percentages relative to border-box.
## Media Queries
```rcss
@media (<feature>) and (<feature>) { ... }
```
| Feature | Range (min-/max-) | Value |
|---------|-------------------|-------|
| `width` | Yes | `<length>` |
| `height` | Yes | `<length>` |
| `aspect-ratio` | Yes | `<ratio>` |
| `resolution` | Yes | `<resolution>` (e.g., `2x`) |
| `orientation` | No | `landscape \| portrait` |
| `theme` | No | `<string>` — BAR uses this for faction themes |
Operators: `and`, `not`. No `or`, no nesting, no CSS Level 4 syntax.
**BAR theme usage**:
```rcss
@media (theme: armada) {
    .text-primary { color: #00ccff; }
}
```
## Selectors
### Basic
`*`, `E` (type), `.class`, `#id`, `[attr]`, `[attr=val]`, `[attr~=val]`, `[attr|=val]`, `[attr^=val]`, `[attr$=val]`, `[attr*=val]`
### Combinators
`E F` (descendant), `E > F` (child), `E + F` (adjacent sibling), `E ~ F` (general sibling)
### Pseudo-classes
`:hover`, `:active`, `:focus`, `:focus-visible` — all **propagate through parents**
`:checked`, `:empty`, `:not(s1, s2, ...)`
### Structural
`:first-child`, `:last-child`, `:nth-child(an+b)`, `:nth-last-child(an+b)`, `:first-of-type`, `:last-of-type`, `:nth-of-type(an+b)`, `:only-child`, `:only-of-type`, `:scope`
### Pseudo-elements
**None.** No `::before`, `::after`, `::first-letter`, `::placeholder`.
Verified against the pinned RmlUi source (`rts/lib/RmlUi` @ `2230d1a6e8`):
`grep -rn placeholder` returns zero hits anywhere in the codebase. Form
control internals are real generated child elements, not pseudo-elements
— style them with child selectors: `input #text` (text content),
`input #selection` (selection highlight), source:
`Source/Core/Elements/WidgetTextInput.cpp`.
## Sprite Sheets
```rcss
@spritesheet icons {
    src: /images/icons.png;
    resolution: 2x;
    icon-play: 0px 0px 32px 32px;
    icon-stop: 32px 0px 32px 32px;
}
```
Reference sprites by name in decorators. Unmatched names treated as file paths.
