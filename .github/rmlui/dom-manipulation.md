# DOM manipulation

IMPORTANT: DOM manipulation is an escape hatch with exactly three sanctioned cases. Read the section `The model is king` in SKILL.md before this.

## Using the API

An escape looks like this, marker first:

```lua
-- rml-dom-escape: <one-line technical reason matching a sanctioned case>
local element = document:GetElementById("my-element")
element:SetClass("active", true)
```

Before writing any of it, ask whether a model field plus data binding can express this. Almost always they can, so they must. Ask again when copying from an existing widget.

## Validation

Reaching for the DOM to drive ordinary UI state is the most common way RML widgets in this codebase go wrong. When validating a widget, detect or dismiss such cases early.

Existing call sites are a known baseline and are not to be migrated wholesale; the marker is what separates a sanctioned escape from a defect. New and changed code follows the rules. To size the baseline in the tree you are working in:

```bash
grep -roIE "GetElementById|QuerySelectorAll|QuerySelector|:SetClass|:SetAttribute|:SetProperty|inner_rml|AppendChild|RemoveChild|InsertBefore" --include=*.lua luaui/RmlWidgets/ | wc -l
```
