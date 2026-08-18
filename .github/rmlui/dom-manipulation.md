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

Reaching for the DOM to drive ordinary UI state is the most common way RML widgets in this codebase go wrong. `lint-widgets.sh` flags an unmarked DOM call on changed lines, and `--all` sizes the existing baseline. That baseline is a known quantity, not a migration target: the marker is what separates a sanctioned escape from a defect. New and changed code follows the rules.
