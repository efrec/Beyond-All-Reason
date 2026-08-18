# RmlUi Data Bindings Reference
Condensed from the [official RmlUi data bindings docs](https://mikke89.github.io/RmlUiDoc/pages/data_bindings.html).
## Data Variable Types
| Type | Description |
|------|-------------|
| **Scalar** | Single value (string, number, boolean). Read/write. |
| **Array** | Indexed container. Items can be any type. Has `.size` accessor. |
| **Struct** | Named members. Members can be any type. |
### Data Address Syntax
```
title                           -- top-level scalar
invader.health                  -- struct member
invaders[1].name                -- array index then member
invaders.size                   -- array size
a.very[5].long.data[99].address -- arbitrarily deep nesting
```
**Important**: Only top-level variables can be dirtied. Dirty `"invaders"`, not `"invaders[1].name"`.
## Data Views (Data -> Document)
### data-attr-*
Sets element attribute to expression result.
```rml
<img data-attr-sprite="item.icon"/>
<div data-attr-class="ccg.panel.general + ' p-3'"/>
```
### data-attrif-*
Sets attribute when true, removes when false. Value is empty string when set.
```rml
<input type="checkbox" data-attrif-disabled="rating > 70"/>
<button data-attrif-disabled="!canSubmit">Submit</button>
```
### data-class-*
Enables class when true, disables when false.
```rml
<h1 data-class-red="score < 30">Score</h1>
<div data-class-active="isSelected">Item</div>
```
### data-style-*
Sets CSS property to expression value.
```rml
<div data-style-width="progress + '%'"/>
<img data-style-image-color="invader.color"/>
```
### data-if
Sets `display: none` when false, removes inline display when true.
```rml
<div data-if="expanded">Expanded content</div>
<span data-if="rating >= 80">awesome</span>
```
**Caveat**: Element's stylesheet must define `display` other than `none`, or it stays hidden always.
### data-visible
Sets `visibility: hidden` when false. Element retains layout space (unlike `data-if`).
```rml
<div data-visible="collected_stars > 0">
    <img sprite="star"/>
</div>
```
### data-for
Repeats element for each item in array.
| Syntax | Iterator | Index |
|--------|----------|-------|
| `data-for="array"` | `it` | `it_index` |
| `data-for="item : array"` | `item` | `it_index` |
| `data-for="item, idx : array"` | `item` | `idx` |
Index is zero-based. An invisible sentinel element is appended after all entries.
```rml
<div data-for="invader : invaders">
    <h1>{{ invader.name }}</h1>
    <p>Invader {{it_index + 1}} of {{ invaders.size }}.</p>
    <p>Scores: <span data-for="invader.scores"> {{it}} </span></p>
</div>
```
**Warning**: Don't reuse global variable names as iterator names (shadowing). Loop elements may be reused, not destroyed/recreated.
### data-rml
Sets element's inner RML to expression result (can inject markup).
```rml
<div data-rml="incoming ? '<em>Send help!</em>' : 'Clear skies.'"></div>
```
### Text View {{ }}
Inline text interpolation. Not an attribute.
```rml
<span>x: {{ position.x }}, y: {{ position.y }}</span>
<span>{{ name | to_upper }}</span>
```
### data-alias-*
Creates alias variable at given scope. Enables reusable templates.
```rml
<div data-alias-title="t0" data-alias-icon="i0">
    <template src="data-title"/>
</div>
```
## Two-Way Bindings
### data-value
Syncs element's `value` with data variable. Listens for `change` events.
```rml
<input type="range" min="0" max="100" step="1" data-value="rating"/>
<input type="text" data-value="playerName"/>
```
**Restriction**: No expressions or assignments. For complex logic, use `data-attr-value` + `data-event-change`.
### data-checked
Binds checkbox/radio `checked` state. Checkbox: boolean variable. Radio: string variable matching `value` attribute.
```rml
<input type="radio" name="animal" value="dog" data-checked="animal"/> Dog
<input type="radio" name="animal" value="cat" data-checked="animal"/> Cat
<input type="checkbox" data-checked="pasta"/> Pasta
```
**Restriction**: No expressions. For complex logic:
```rml
<input type="checkbox" data-attrif-checked="pasta" data-event-change="pasta = ev.checked || force_pasta"/>
```
## Controllers (Document -> Data)
### data-event-*
Triggered on specified event. Supports assignment expressions and callback invocations.
**Variable assignment**:
```rml
<div data-event-click="selectedId = item.id">Select</div>
```
**Callback invocation**:
```rml
<div data-event-click="handleClick(item.id, item.name)">Click me</div>
```
**Multiple statements** (semicolon-separated):
```rml
<div data-event-click="handleClick(); hello_world = 'Hello!'"
     data-event-mousemove="mouse_pos = 'x: ' + ev.mouse_x + ', y: ' + ev.mouse_y">
</div>
```
**`ev` variable**: Access event properties — `ev.mouse_x`, `ev.mouse_y`, `ev.checked`, etc.
## Expression Syntax
### Operators (highest precedence first)
| Prec | Operator | Description |
|------|----------|-------------|
| 1 | `!` | Logical NOT |
| 2 | `*` `/` | Multiplication, division |
| 3 | `+` `-` | Addition/string concatenation, subtraction |
| 4 | `==` `!=` `<` `<=` `>` `>=` | Comparisons |
| 5 | `&&` `\|\|` | Logical AND, OR |
| 5 | `\|` | Transform pipe |
| 5 | `? :` | Ternary conditional |
Parentheses `()` override all precedence. Left-to-right evaluation within same level.
### Value Types
| Type | Syntax | Examples |
|------|--------|---------|
| Data address | Variable path | `rating`, `invader.name`, `items[0].id` |
| Number | Integer or float | `42`, `-3.2` |
| String | **Single quotes** | `'hello'`, `'world'` |
| Boolean | Keywords | `true`, `false` |
**String concatenation**: Use `+` operator (if either operand is a string).
**Boolean to string**: `true` → `"1"`, `false` → `"0"`.
### Expression Examples
| Expression | Result |
|------------|--------|
| `rating < 80` | `1` |
| `radius + 'm'` | `8.7m` |
| `(radius \| format(2)) + 'm'` | `8.70m` |
| `radius < 10.5 ? 'small' : 'large'` | `small` |
| `'hot' + 'dog' \| to_upper` | `HOTDOG` |
## Transform Functions
### Calling Syntax
```
transform_name(value)              -- function call
expression | transform_name        -- pipe (no args)
expression | transform_name(arg)   -- pipe (with extra args)
```
Pipes chain: `i * 3.14159 | round | format(2)`
### Built-in Functions
| Name | Args | Return | Description |
|------|------|--------|-------------|
| `to_upper` | `value` | String | Uppercase |
| `to_lower` | `value` | String | Lowercase |
| `round` | `value` | Number | Round to nearest integer |
| `format` | `value, precision, remove_trailing_zeros?` | String | Format number. `precision` = decimal places. Optional third arg removes trailing zeros. |
## Limitations and Gotchas
1. **No post-init data attributes** — Adding `data-*` attributes after element attachment has no effect.
2. **No DOM changes inside data models** — Don't manually add/remove elements inside `data-for` views (undefined behavior, may crash).
3. **Only top-level dirty** — Cannot dirty sub-paths, only top-level variable names.
4. **`<tabset>`/`<panel>`/`<tab>` compatibility** — Internal structure changes may break data bindings, especially with `data-for`.
5. **`<select>` limitations** — Use `data-value` on the `<select>` element for dynamic selection. `data-for` works for initial population.
6. **All `data-` attributes are reserved** — Don't use `data-` prefix for custom attributes.
7. **`{{` and `}}` are reserved** — All occurrences in RML are parsed as data bindings.
8. **Boolean-to-string** — `true` becomes `"1"` in string context. RCSS attribute selectors must match: `div[foo=1]` not `div[foo=true]`.
9. **`data-if` needs display** — Stylesheet must define non-`none` display, or element stays hidden.
10. **`data-for` reuse** — Loop elements may be reused rather than destroyed/recreated on array changes.
