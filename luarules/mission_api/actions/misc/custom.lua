local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function custom(func)
	func()
end

return {
	---Runs a Lua function written in the mission script.
	---
	---The function is called with no arguments, and its return value is ignored. Use it for behavior that no other action provides.
	---@class CustomAction
	---@field function Function The function to call.
	{
		type = 'Custom',
		parameters = {
			{ name = 'function', required = true, type = ParameterTypes.Function },
		},
		actionFunction = custom,
	}
}
