-- luaui/Utilities/springOverrides.lua -----------------------------------------
-- Spring function overrides for LuaUI. It is loaded along with luaui/Utilities.
-- For now, just poisons SetTeamColor, but there is more work to be done here.

local base = Spring.Base or {}
Spring.Base = base

if Spring.SetTeamColor and Spring.GetModOptions then
	if Spring.GetModOptions().teamcolors_anonymous_mode ~= "disabled" then
		-- disabling individual Spring functions isnt really good enough
		-- disabling user widget draw access would probably do the job but that wouldnt be easy to do
		Spring.SetTeamColor = function()
			return true
		end
	end
end
