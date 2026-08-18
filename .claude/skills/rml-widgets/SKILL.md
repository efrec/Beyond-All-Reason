---
name: rml-widgets
description: Build and test widgets using RmlUi for Beyond All Reason. Use when making extra UI for components that do not update at gameplay rates.
---

# RML widgets

RmlUi is a web-like UI framework for C++. This skill holds the BAR widget doctrine and upstream API reference.

## Reference

- **[rmlui-lua-api.md](references/rmlui-lua-api.md)** — Element / Document / Context / Event APIs
- **[rmlui-data-bindings.md](references/rmlui-data-bindings.md)** — Data binding attributes and expression language
- **[rmlui-rcss-reference.md](references/rmlui-rcss-reference.md)** — RCSS selectors, flexbox, decorators, animations

## Key doctrine

- **The model is king.** Change the view by mutating the data model; data binding updates the DOM.
- **No `widget:` methods for UI behaviour.** Define handlers in `initModel()` and bind with `data-event-*`.
- **Utility classes by default.** CCG only for frequent, heavy bundles.
- **Block layout by default.** Flex justified only for children filling remaining space or horizontal splits.
- **Mark DOM escapes.** Inline `-- rml-dom-escape: <reason>` for the three unavoidable cases (data-binding bugs, SVG injection, hot paths).

## Widget dev workflow

**Start:** Run `luaui/RmlWidgets/rml_starter/generate-widget.sh --name widget_name`.

**Checklist** (copy and track):
- [ ] Model: fields and handlers (initModel())
- [ ] Bindings: markup reads and updates model
- [ ] Lint: `bash .github/rml-widgets/scripts/lint-widgets.sh` — fix errors, warnings pass
- [ ] Styles: utility classes, no hard-coded colors
- [ ] Performance: block layout default, explicit heights on repeats

**Pause point** (if interrupted, save this):
```
[widget_name] status:
- Model: [fields completed / TODO]
- Bindings: [data-* attributes tested / TODO]
- Lint: [errors / warnings / clean]
- Performance: [baseline FPS / TODO]
```

## Verification before hand-off

Run these before committing or passing to someone else:

1. **Lint clean:** `bash .github/rml-widgets/scripts/lint-widgets.sh` → no errors
2. **Model reads:** All `{{var}}` interpolations pull from model, not hardcoded
3. **No inline handlers:** No `onclick=`, `onkeyup=` in markup
4. **Colors from utilities:** No `rgba()` or hex in RCSS
5. **Layout efficient:** No nested flex-column, explicit heights on repeats

## Common patterns

**Toggle visibility:** class change + transition
```rml
<div data-class-hidden="!isVisible"></div>
```
```rcss
div { display: block; transition: opacity 0.3s; }
div.hidden { opacity: 0; pointer-events: none; }
```

**List with dynamic count:** data-for on array, mutate the array
```rml
<div data-for="item : items">{{item.name}}</div>
```
```lua
table.insert(dm_handle.items, { name = "new" })  -- RmlUi updates
```

**Read input value in handler:** Get from element, not model (data-value timing)
```lua
handleInput = function()
    local value = ev.current_element:GetAttribute("value")
    dm_handle.result = value
end,
```
