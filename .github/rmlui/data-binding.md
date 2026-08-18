# Data binding

IMPORTANT: Data binding is the only sanctioned way the UI updates. Read the section `The model is king` in SKILL.md before this.

## Binding attributes

| Syntax | Purpose | Example |
|--------|---------|---------|
| `{{var}}` | Text interpolation | `<span>{{playerName}}</span>` |
| `data-if="expr"` | Conditional display (removes from layout) | `<div data-if="expanded">...</div>` |
| `data-visible="expr"` | Conditional visibility (keeps layout space) | `<div data-visible="showStar">...</div>` |
| `data-for="item : array"` | Array iteration | `<div data-for="tab : tabs">{{tab.label}}</div>` |
| `data-attr-class="expr"` | Dynamic class binding | `data-attr-class="'btn w-full ' + (active ? 'bg-primary' : 'bg-darker')"` |
| `data-attrif-name="bool"` | Set attribute when true, remove when false | `<button data-attrif-disabled="!canSubmit">` |
| `data-class-name="bool"` | Toggle a single CSS class | `data-class-loading="isLoading"` |
| `data-style-prop="expr"` | Dynamic CSS property | `data-style-width="progress + '%'"` |
| `data-rml="expr"` | Set inner RML (can inject markup) | `<div data-rml="statusHtml"></div>` |
| `data-value="var"` | Two-way input binding (no expressions) | `<input data-value="playerName" />` |
| `data-checked="var"` | Two-way checkbox/radio binding | `<input type="checkbox" data-checked="enabled" />` |
| `data-event-click="fn()"` | Call model function on event | `data-event-click="handleAction(item.id)"` |
| `data-event-mousedown="fn()"` | Any DOM event (`mousedown`, `change`, `mouseover`, ...) | `data-event-mousedown="setTab(tab.id)"` |
| ~~`onclick="widget:Method()"`~~ | Anti-pattern, found only in legacy widgets. Put the function in the model and bind it with `data-event-*`. | — |

Conditional classes, built from utility classes:

```rml
<button data-attr-class="'tab-btn px-3 py-1 rounded ' + (active ? 'bg-primary text-light' : 'bg-darker text-medium')">
    {{tab.label}}
</button>
```

## Event handlers

The handler is a function in the table returned by `initModel()`, and it receives the `Event` as its implicit first argument, `ev`.

```rml
<button data-event-click="confirm()">OK</button>
<input data-event-keyup="onType(ev.key_identifier)" />
```

```lua
-- inside the table returned by initModel():
confirm = function() dm_handle.status = "ok" end,
onType  = function(ev, keyId)
    local el = ev and ev.current_element -- the element the handler is on
    performFilter((el and el:GetAttribute("value")) or "")
end,
```

- **No `element` token** — that token belongs to the legacy inline `onclick="widget:Fn(element)"` syntax alone.
- **`ev.current_element`** — the element the handler is bound to.
- **`ev.target_element`** — the element the event originated on, which may be a child the user actually clicked. Getting this wrong silently misfires on handler elements that have children.

Reading an element's attribute this way is also how you dodge the `data-value` commit timing in the gotchas.

## Expression syntax

Expressions (in `data-if`, `data-for`, `data-attr-*`, `data-event-*`, and the rest) are a small language of their own, not Lua:

- **String literals** — single quotes, `'hello'`. Double quotes are the RML attribute delimiter.
- **Concatenation** — `+`, as in `'Player ' + name`. It works if either operand is a string.
- **Transform pipes** — `radius | round`, `name | to_upper`, `value | format(2)`, chained as `i * 3.14 | round | format(2)`.
- **Built-in transforms** — `to_upper`, `to_lower`, `round`, `format(precision, removeTrailingZeros?)`.
- **Operators**, in precedence order — `!`, `* /`, `+ -`, `== != < <= > >=`, `&& ||`, `|` (pipe), `? :` (ternary).

## Gotchas

- **`data-if` needs `display` defined.** The element's stylesheet must set `display` to something other than `none`, or the element stays hidden regardless of the expression.
- **`data-value` and `data-checked` take no expressions.** For anything more complex, use `data-attr-value` with `data-event-change`.
- **`data-value` commits after the event fires.** A handler reading the bound model variable sees the previous value, so read the attribute off `ev.current_element` instead.
- **Only top-level vars can be dirtied.** After mutating `items[3].name` you dirty `"items"`, not `"items[3].name"`.
- **Mutate the driving array, never the DOM inside a `data-for`.** Updating the underlying Lua table and dirtying the top-level variable is the supported workflow; the engine reuses loop elements and rebinds them. Calling `AppendChild`, `RemoveChild`, or `inner_rml` on elements inside a data-binding region is undefined behaviour and can crash.
- **No post-init `data-*` attributes.** Data bindings added to an element after the document loads have no effect.
- **Don't shadow globals with iterator names.** `data-for="tab : tabs"` is fine; `data-for="widget : widgets"` shadows the global `widget`.
- **`{{` and `}}` are reserved anywhere in RML.** They parse as data bindings even inside comments and script blocks.
