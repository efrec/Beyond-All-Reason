# DOM manipulation

IMPORTANT: DOM manipulation is an escape hatch with exactly three sanctioned cases. Read the section `The model is king` in SKILL.md before this.

## Using the API

An escape looks like this, marker first:

```lua
-- rml-dom-escape: <one-line technical reason matching a sanctioned case>
local element = document:GetElementById("my-element")
element:SetClass("active", true)
```

Before writing any of it, ask: *can a model field plus data binding express this?* Almost always they can, so they must. Ask the same question again when copying from an existing widget.

## Validation

Reaching for the DOM to drive ordinary UI state is the most common way RML widgets in this codebase go wrong. When validating a widget, detect or dismiss such cases early.

Around 250 call sites exist today which are not to be migrated. The bulk is SVG code carrying a `-- rml-dom-escape: SVG injection` marker, and the remainder is a known baseline of acceptable defects. New and changed code follows the rules.
