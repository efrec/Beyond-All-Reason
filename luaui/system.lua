--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    system.lua
--  brief:   defines the global entries placed into a widget's table
--  author:  Dave Rodgers
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if (System == nil) then
	if tracy == nil then
		Spring.Echo("Widgetside tracy: No support detected, replacing tracy.* with function stubs.")
		local noop = function () end
		tracy = {
			ZoneBeginN = noop,
			ZoneBegin  = noop,
			ZoneEnd    = noop,
			Message    = noop,
			ZoneName   = noop,
			ZoneText   = noop,
		}
	end

	System = {
		--
		--  Custom Spring tables
		--
		Script = Script,
		Spring = Spring,
		Engine = Engine,
		Platform = Platform,
		Game = Game,
		GameCMD = Game.CustomCommands.GameCMD,
		gl = gl,
		GL = GL,
		CMD = CMD,
		CMDTYPE = CMDTYPE,
		VFS = VFS,
		LOG = LOG,

		UnitDefs        = UnitDefs,
		UnitDefNames    = UnitDefNames,
		FeatureDefs     = FeatureDefs,
		FeatureDefNames = FeatureDefNames,
		WeaponDefs      = WeaponDefs,
		WeaponDefNames  = WeaponDefNames,

		--
		--  Custom LuaUI variables
		--
		Commands = Commands,
		fontHandler = fontHandler,
		LUAUI_DIRNAME = LUAUI_DIRNAME,

		--
		-- Custom libraries
		--
		Json = Json,
		RmlUi = RmlUi,
		socket = socket,

		--
		--  Standard libraries
		--
		io = io,
		os = os,
		math = math,
		debug = debug,
		tracy = tracy,
		table = table,
		string = string,
		package = package,
		coroutine = coroutine,

		--
		--  Standard functions and variables
		--
		assert         = assert,
		error          = error,

		print          = print,

		next           = next,
		pairs          = pairs,
		pairsByKeys    = pairsByKeys, -- custom: defined in `common\tablefunctions.lua`
		ipairs         = ipairs,

		tonumber       = tonumber,
		tostring       = tostring,
		type           = type,

		collectgarbage = collectgarbage,
		gcinfo         = gcinfo,

		unpack         = unpack,
		select         = select,
		dofile         = dofile,
		loadfile       = loadfile,
		loadlib        = loadlib,
		loadstring     = loadstring,
		require        = require,

		getmetatable   = getmetatable,
		setmetatable   = setmetatable,

		rawequal       = rawequal,
		rawget         = rawget,
		rawset         = rawset,

		getfenv        = getfenv,
		setfenv        = setfenv,

		pcall          = pcall,
		xpcall         = xpcall,

		_VERSION       = _VERSION
	}
end
