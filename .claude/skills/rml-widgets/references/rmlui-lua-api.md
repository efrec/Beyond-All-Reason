# RmlUi Lua API Reference
Condensed from the [official RmlUi Lua manual](https://mikke89.github.io/RmlUiDoc/pages/lua_manual.html).
## Element
Base type for all DOM elements. No constructor — create via `Document:CreateElement()`.
### Properties
| Property | Type | RO | Description |
|----------|------|----|-------------|
| `id` | `string` | No | Element ID |
| `inner_rml` | `string` | No | Element's RML content (read/write) |
| `class_name` | `string` | No | Space-separated class list |
| `tag_name` | `string` | Yes | Tag name |
| `style` | `ElementStyleProxy` | -- | RCSS properties: `element.style.width = "40px"`. Values are unparsed strings. |
| `attributes` | `ElementAttributesProxy` | Yes | Map-like attribute proxy |
| `child_nodes` | `ElementChildNodesProxy` | Yes | Array of visible children (1-based in Lua) |
| `first_child` | `Element?` | Yes | First child or nil |
| `last_child` | `Element?` | Yes | Last child or nil |
| `parent_node` | `Element?` | Yes | Parent element or nil |
| `next_sibling` | `Element?` | Yes | Next sibling or nil |
| `previous_sibling` | `Element?` | Yes | Previous sibling or nil |
| `owner_document` | `Document` | Yes | Owning document |
| `offset_left` | `number` | Yes | Left offset from offset parent |
| `offset_top` | `number` | Yes | Top offset from offset parent |
| `offset_width` | `number` | Yes | Width excluding margins |
| `offset_height` | `number` | Yes | Height excluding margins |
| `offset_parent` | `Element` | Yes | Offset parent element |
| `client_left` | `number` | Yes | Left border to left client edge |
| `client_top` | `number` | Yes | Top border to top client edge |
| `client_width` | `number` | Yes | Client area width |
| `client_height` | `number` | Yes | Client area height |
| `scroll_left` | `number` | No | Horizontal scroll offset |
| `scroll_top` | `number` | No | Vertical scroll offset |
| `scroll_width` | `number` | Yes | Scrollable content width |
| `scroll_height` | `number` | Yes | Scrollable content height |
### Methods
| Method | Signature | Description |
|--------|-----------|-------------|
| `GetElementById` | `(id: string) -> Element` | Find element by ID in this document |
| `GetElementsByTagName` | `(tag: string) -> table` | All descendants with tag |
| `QuerySelector` | `(selectors: string) -> Element` | First descendant matching selector |
| `QuerySelectorAll` | `(selectors: string) -> table` | All descendants matching selector |
| `Matches` | `(selectors: string) -> boolean` | Whether element matches selector |
| `SetAttribute` | `(name: string, value: string)` | Set attribute |
| `GetAttribute` | `(name: string) -> Variant` | Get attribute (empty string if missing) |
| `HasAttribute` | `(name: string) -> boolean` | Check attribute exists |
| `RemoveAttribute` | `(name: string)` | Remove attribute |
| `SetClass` | `(name: string, value: boolean)` | Set or clear a class |
| `IsClassSet` | `(name: string) -> boolean` | Check if class is set |
| `AppendChild` | `(element: ElementPtr) -> Element?` | Append child. **Returns Element** (use this for SetAttribute). |
| `InsertBefore` | `(element: ElementPtr, adjacent: Element) -> Element?` | Insert before adjacent |
| `RemoveChild` | `(element: Element) -> boolean` | Remove child |
| `ReplaceChild` | `(inserted: ElementPtr, replaced: Element) -> boolean` | Replace child |
| `HasChildNodes` | `() -> boolean` | Whether element has children |
| `AddEventListener` | `(event: string, listener: function\|string, in_capture: boolean)` | Add event listener. **Cannot be removed.** |
| `DispatchEvent` | `(event: string, parameters: table)` | Dispatch custom event |
| `ScrollIntoView` | `(align_top: boolean)` | Scroll into view (true=top, false=bottom) |
| `Focus` | `()` | Give input focus |
| `Blur` | `()` | Remove input focus |
| `Click` | `()` | Simulate click |
**Important**: `child_nodes` is 1-based (Lua convention). `AppendChild` converts `ElementPtr` to `Element` — use the return value for further operations.
## Document
Inherits all Element properties and methods.
### Document-Specific Properties
| Property | Type | RO | Description |
|----------|------|----|-------------|
| `context` | `Context` | Yes | Owning context |
| `title` | `string` | No | Document title |
### Document-Specific Methods
| Method | Signature | Description |
|--------|-----------|-------------|
| `CreateElement` | `(tag: string) -> ElementPtr` | Create element. Returns `ElementPtr` (not `Element`). |
| `CreateTextNode` | `(text: string) -> ElementPtr` | Create text node |
| `Show` | `(modal?: DocumentModal, focus?: DocumentFocus)` | Show document |
| `Hide` | `()` | Hide document |
| `Close` | `()` | Close and destroy document |
| `PullToFront` | `()` | Bring to front of z-order |
| `PushToBack` | `()` | Send to back of z-order |
**ElementPtr limitation**: Cannot call `SetAttribute` on `ElementPtr` directly. Workaround:
```lua
local ptr = document:CreateElement('div')
local elem = document:AppendChild(ptr)  -- returns Element
elem:SetAttribute('class', 'my-class')
```
### Document Enums
`DocumentModal`: `.None`, `.Modal`, `.Keep`
`DocumentFocus`: `.None`, `.Document`, `.Keep`, `.Auto`
## Context
### Properties
| Property | Type | RO | Description |
|----------|------|----|-------------|
| `name` | `string` | Yes | Context name |
| `dimensions` | `Vector2i` | No | Context dimensions |
| `dp_ratio` | `number` | No | Density-independent pixel ratio |
| `documents` | `ContextDocumentsProxy` | Yes | Documents (iterable via `ipairs`, indexable by string ID) |
| `focus_element` | `Element` | Yes | Currently focused element |
| `hover_element` | `Element` | Yes | Element under cursor |
| `root_element` | `Element` | Yes | Root element |
### Methods
| Method | Signature | Description |
|--------|-----------|-------------|
| `LoadDocument` | `(path: string) -> Document` | Load document from RML file |
| `CreateDocument` | `(tag: string) -> Document` | Create empty document |
| `UnloadDocument` | `(document: Document)` | Unload specific document |
| `UnloadAllDocuments` | `()` | Unload all documents |
| `IsMouseInteracting` | `() -> boolean` | Whether mouse interacting with elements |
| `Update` | `() -> boolean` | Update context (refreshes data views) |
| `Render` | `() -> boolean` | Render context |
| `AddEventListener` | `(event: string, listener: function\|string, element_context?: Element, in_capture: boolean)` | Context-level event listener |
## Event
### Properties
| Property | Type | Description |
|----------|------|-------------|
| `type` | `string` | Event type name |
| `target_element` | `Element` | Original target element |
| `current_element` | `Element` | Element event has propagated to |
| `parameters` | `EventParametersProxy` | Event parameters (dictionary-like) |
### Methods
| Method | Description |
|--------|-------------|
| `StopPropagation()` | Stop propagation through event cycle |
| `StopImmediatePropagation()` | Stop propagation including other listeners on current element |
**Global variables in event handlers**: When an event fires, `element`, `document`, and `event` are set as globals.
## Global `rmlui` Table
| Property/Method | Description |
|-----------------|-------------|
| `rmlui.contexts` | Proxy of active contexts (by index or name string) |
| `rmlui:CreateContext(name, dimensions)` | Create context. `dimensions`: `Vector2i` |
| `rmlui:LoadFontFace(path, fallback, face_index)` | Load font. `fallback`: use for unknown chars |
| `rmlui.key_identifier` | Enum of input key identifiers |
| `rmlui.key_modifier` | Enum of input key modifiers |
## Utility Types
### Vector2f / Vector2i
| Property | Type | Description |
|----------|------|-------------|
| `x` | `number` / `integer` | X component |
| `y` | `number` / `integer` | Y component |
| `magnitude` | `number` | Vector magnitude (read-only) |
Constructor: `Vector2f.new(x, y)`, `Vector2i.new(x, y)`
Vector2f also has: `DotProduct(other)`, `Normalise()`, `Rotate(angle)`
Operators: `+`, `-`, `*`, `/`, `==`
### Colourb
Byte-channel color (0-255 per channel).
| Property | Type | Description |
|----------|------|-------------|
| `red`, `green`, `blue`, `alpha` | `integer` | Color channels (0-255) |
Constructor: `Colourb.new(r, g, b, a)`
## Form Control Elements
### ElementFormControl (inherits Element)
| Property | Type | Description |
|----------|------|-------------|
| `disabled` | `boolean` | Whether control is disabled |
| `name` | `string` | Control name |
| `value` | `string` | Control value |
### ElementFormControlInput (inherits ElementFormControl)
| Property | Type | Description |
|----------|------|-------------|
| `checked` | `boolean` | For radio/checkbox |
| `maxlength` | `integer` | Maximum input length |
| `size` | `integer` | Approximate visible characters |
| `max`, `min`, `step` | `integer` | For range inputs |
Methods: `GetSelection() -> start, end, text`, `Select()`, `SetSelection(start, end)`
### ElementFormControlSelect (inherits ElementFormControl)
| Property | Type | Description |
|----------|------|-------------|
| `options` | `SelectOptionsProxy` | Array of options (`.value`, `.element`) |
| `selection` | `integer` | Currently selected index |
Methods: `Add(rml, value, before?) -> index`, `Remove(index)`, `RemoveAll()`
### ElementFormControlTextArea (inherits ElementFormControl)
Properties: `cols`, `rows`, `maxlength`, `wordwrap`
Methods: `GetSelection()`, `Select()`, `SetSelection(start, end)`
### ElementTabSet (inherits Element)
Properties: `active_tab` (index), `num_tabs` (read-only)
Methods: `SetPanel(index, rml)`, `SetTab(index, rml)`
## Proxy Types
All proxies support `__index` and `__pairs`. Only `ElementChildNodesProxy` supports `#` (length operator).
| Proxy | Access Pattern |
|-------|---------------|
| `ContextDocumentsProxy` | `ctx.documents[1]` or `ctx.documents['id']` |
| `ElementAttributesProxy` | `elem.attributes.name` |
| `ElementChildNodesProxy` | `elem.child_nodes[1]`, `#elem.child_nodes` |
| `ElementStyleProxy` | `elem.style.width = "50px"`, iterable |
| `EventParametersProxy` | `event.parameters.key` |
| `SelectOptionsProxy` | `select.options[1].value` |
