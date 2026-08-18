# File structure

IMPORTANT: Generate the three files, never hand-copy another widget. Read the section `File structure` in SKILL.md before this.

A widget is three files in `luaui/RmlWidgets/widget_name/`, scaffolded by `rml_starter/generate-widget.sh --name widget_name`.

## widget_name.lua

Logic, data model, event handlers. Base: `luaui/Include/rml_utilities/utils.lua`.

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

Model rules, all of them consequences of reload creating a fresh model:

- **Factory** — `initModel()` returns a new table each init, so no state survives a reload as a stale reference.
- **Access** — model functions read and write properties through `dm_handle` directly.
- **Keys** — every property exists at init time; keys added later are not bound.
- **Upvalues** — `document` and `dm_handle` are file-local.

## widget_name.rml

Markup, and the document's stylesheets.

```rml
<rml>
<head>
    <title>Widget Name</title>

    <!-- Mandatory stylesheet order -->
    <link rel="stylesheet" href="../styles.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../rml-utility-classes.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../palette-standard-global.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../components.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../themes/theme-base.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../themes/theme-armada.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../themes/theme-cortex.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../themes/theme-legion.rcss" type="text/rcss" />

    <!-- Widget-specific styles last -->
    <link rel="stylesheet" href="widget_name.rcss" type="text/rcss" />
</head>
<body id="widget_name-widget" class="widget-shadow rounded-lg">
    <div id="widget-container" data-model="widget_name_model">
        <!-- All content inside the data-model wrapper -->
    </div>
</body>
</rml>
```

- **Stylesheet order** — shared sheets in the order above, all four themes among them, the widget's own sheet last. In situ: `../terraform_shared/{styles,rml-utility-classes,palette-standard-global}.rcss`, no components or themes.
- **Body id** — `widget_name-widget`, matching the RCSS selector.
- **Body classes** — `widget-shadow rounded-lg`, for the consistent drop shadow and rounding.
- **Wrapper** — one `div` carrying `data-model="model_name"`, with all content inside it.

## widget_name.rcss

The widget box and its container. Both are block layout: the widget box has a definite size, so the container needs no flex to fill it (see ./performance.md).

```rcss
#widget_name-widget {
    position: absolute;
    top: 100dp;
    left: 50dp;
    width: 300dp;
    height: 400dp;
    display: block;
}

#widget-container {
    display: block;
    position: relative;   /* anchor for absolutely-positioned children */
    height: 100%;
    padding: 12dp;
}
```

## Reload and debug

IMPORTANT: Do not add reload or debug buttons or debug-gating flags to a widget. `rml_starter` is the sole widget shipping `reload` and `debug` controls, as a dev convenience.

Reload and debug during development instead:

- **Reload** — `/luaui reload` reloads all widgets, as does `rml_starter`'s `reload` button.
- **Debug** — the debugger overlay lives at Options > Dev > Debug > "RmlUi Debugger", and behind `rml_starter`'s `debug` button. Both call `RmlUi.SetDebugContext`.

A model function that must trigger a reload sets a `reloadRequested` flag which `widget:Update` acts on, so the model is not torn down inside its own data-event dispatch (use-after-free). Avoid needing this.
