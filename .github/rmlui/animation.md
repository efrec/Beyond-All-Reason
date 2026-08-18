# Animation

IMPORTANT: A transition fires on a class or pseudo-class change, an animation fires on element creation. Read the section `Animation` in SKILL.md before this.

## Transitions

Syntax is `transition: <property> <duration> [<timing-function>]`.

```rcss
.element {
    transition: transform 0.15s quadratic-out;
    transition: opacity 0.2s linear-in-out;
    transition: all 0.3s cubic-in-out;
}
```

Timing functions, each with `-in`, `-out`, and `-in-out` variants: `back`, `bounce`, `circular`, `cubic`, `elastic`, `exponential`, `linear`, `quadratic`, `quartic`, `quintic`, `sine`. Use `linear-in-out` for constant speed.

- **Class changes only.** Updating a property through `data-style-*` or direct element style mutation does not trigger the transition. Animate by toggling a class (`data-class-active="isActive"`) and defining the transition on that class.
- **Aggressive easing jitters.** `exponential-out`, `elastic-*`, and `bounce-*` cause visible sub-pixel jitter on small transforms such as `translateX(5dp)`. Prefer `quadratic-out` or `cubic-out` for subtle UI shifts.

## Keyframes

Use `@keyframes` and the `animation` property when motion must fire on element creation — items appearing in a `data-for` loop, a tab's content repopulating, search results rendering. Transitions cannot do this: a freshly created element has no prior state to transition from, while animations play immediately on mount.

```rcss
.row { animation: 0.45s quadratic-out 1 slide-in; }   /* <duration> <tween> <iterations> <name> */
@keyframes slide-in {
    0%   { transform: translateX(-540dp); }
    100% { transform: translateX(0dp); }
}
```

These cost a long debugging session each. Trust them.

- **Animate `translateX` as a length (`dp`), never a percentage.** Measured: a `translateX(-100%)` to `translateX(0)` keyframe pair does not move, though upstream lists `translate` as taking `<length-percentage>`. Any `opacity` in the same keyframes still animates, so it looks like a fade and masks the problem. Pick a `dp` value that clears the element's travel, e.g. `-540dp` for a 540dp-wide drawer. In-repo: `gui_quick_start`'s `deduction-drift` holds its `translateX(-50%)` in the resting rule and animates `top`, `opacity`, and `font-size`, never the transform.
- **Transformed elements escape `overflow: hidden`.** A panel parked or sweeping off-screen via `translateX` paints outside its scroll container, e.g. over the tab rail, unless the clipping ancestor also carries `clip: always`. That is the documented RmlUi way to force-clip transformed children, and it is what lets a slide-in be a pure transform with no opacity-fade crutch.
- **No `animation-fill-mode`.** RmlUi has neither `forwards` nor `backwards`, which dictates how motion is staged. After a one-shot animation completes the element reverts to its resting RCSS style, so that resting style must equal the final keyframe (no `transform` override on the rule means `translateX(0)`, matching the `100%` frame) or the element visibly snaps back. During an `animation-delay` window the element shows its resting style rather than the `0%` frame, so a delayed start flashes the resting state before animating.
- **Stagger a cascade with in-keyframe holds, not `animation-delay`.** Because of that delay flash, give each position its own keyframe set that holds the hidden state for an increasing slot and then runs the same slide, all starting at frame 0. Select per position with `:nth-child`, which is supported. Cap the ladder (say at 6) and let later items fall back to the no-hold base keyframes so long lists do not over-delay.
  ```rcss
  @keyframes in    { 0%       { transform: translateX(-540dp); } 44%, 100% { transform: translateX(0dp); } }
  @keyframes in-2  { 0%, 10%  { transform: translateX(-540dp); } 54%, 100% { transform: translateX(0dp); } }
  .scroll-area > div:nth-child(2) .row { animation: 0.45s quadratic-out 1 in-2; }
  ```
- **`animation` is a shorthand only.** RmlUi parses `animation: <duration> <delay>? <tween>? [<iterations>|infinite]? alternate? paused? <name>`; there is no `animation-delay` or `animation-name` longhand. Keyframe percentages are duration-relative, so changing the duration rescales holds and slide together.

Worked example in-repo: the staggered, flash-free slide-in on `gui_options_rml`'s `.panel-with-abs-heading`, the option-group entrance.
