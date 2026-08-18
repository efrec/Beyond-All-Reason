# Direct DOM Manipulation

IMPORTANT: Read the section `DOM manipulation` in the main document before this.

## Overview

Follow this general appearance to use the API:

```lua
-- rml-dom-escape: <one-line technical reason matching a sanctioned case>
local element = document:GetElementById("my-element")
element:SetClass("active", true)
```

Before writing any of this, ask: *Can a model field plus data binding express this?* Almost always, the model field and binding work, so must be used. When copying from existing examples, you must ask yourself the same.

## Validation

Reaching for the DOM to drive ordinary UI state is the most common way RML widgets in this codebase go wrong. When validating them, detect or dismiss such cases early.

Around 250 such call sites exist today which are not to be migrated. The bulk is SVG code carrying a `-- rml-dom-escape: SVG injection` marker. The remainder is a known baseline of acceptable defects. New and changed code must follow the rules for DOM manipulation.