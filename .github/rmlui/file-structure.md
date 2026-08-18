# Lua initialization pattern

Every RML widget follows this file structure:

```lua
if not RmlUi then
    return
end

local widget = widget ---@type Widget
local utils = VFS.Include("luaui/Include/rml_utilities/utils.lua")

local WIDGET_ID = "widget_name"
local MODEL_NAME = "widget_name_model"
local RML_PATH = "luaui/RmlWidgets/widget_name/widget_name.rml"

local document
local dm_handle

-- Factory function — creates a fresh model table each init
local function initModel()
    return {
        someValue = "initial",

        -- Widget-specific utility-class bundles (reused class combos)
        my = {
            customStyle = "p-3 bg-darker rounded",
        },

        handleAction = function(event, arg)
            dm_handle.someValue = "updated"
        end,
    }
end

function widget:GetInfo()
    return {
        name = "Widget Name",
        desc = "Description",
        author = "Author",
        date = "2025",
        license = "GNU GPL, v2 or later",
        layer = -1000,
        enabled = false,
    }
end

function widget:Initialize()
    local result = utils.initializeRmlWidget(self, {
        widgetId = WIDGET_ID,
        modelName = MODEL_NAME,
        rmlPath = RML_PATH,
        initModel = initModel(),
        useCommonClassGroups = true, -- injects model.ccg.* (heavy-repeat shorthands)
    })
    if not result then return false end
    document = result.document
    dm_handle = result.dm_handle
    return true
end

function widget:Shutdown()
    utils.shutdownRmlWidget(self, {
        widgetId = WIDGET_ID,
        modelName = MODEL_NAME,
    }, document, dm_handle)
    document = nil
    dm_handle = nil
end

-- Most widgets don't need this — the generator omits it. Add it only
-- for genuine per-frame work, and never poll game state here: express
-- UI state through the model + data binding (see "The model is king").
function widget:Update()
    if not dm_handle then return end
end
```

## Reload/debug buttons

IMPORTANT: Do not add reload/debug buttons, `rmlDebugControls`, or `isRmlDebugEnabled` gating to a new widget. New and generated widgets have no reload/debug buttons (but one). **`rml_starter` is the sole widget with always-visible `reload` / `debug` buttons** (ungated), as a dev convenience.

Instead, to reload or debug during development:
- Use `/luaui reload` (reloads all widgets) or the `reload` button on **rml_starter**.
- Use the debugger overlay: **Options > Dev > Debug > "RmlUi Debugger"** (or rml_starter's `debug` button). This calls `RmlUi.SetDebugContext`.

The safe pattern to trigger a manual reload from a model function is a `reloadRequested` flag the model function sets, acted upon in `widget:Update`. Defer this response so the model is not torn down inside its own data-event dispatch (use-after-free). Avoid needing to do this.

Reload rules:
- Always use `initModel()` as a factory (fresh table each init) to avoid stale references
- Model functions reference `dm_handle` directly to read/write properties
- All model properties must be defined at init time — you cannot add new keys later
- Store `document` and `dm_handle` as file-local upvalues
