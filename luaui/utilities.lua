-------------------------------------------------------------------------------------
--
-- DO NOT LOAD ANY GLOBAL UTILITIES HERE!
--
-- Load utility files whose functionality is applicable to widgets ONLY
-- Utility files with global functionality should go in /common/Utilities/
-- 
-------------------------------------------------------------------------------------

local utilitiesFiles = VFS.DirList('luaui/Utilities/', "*.lua")
for i = 1, #utilitiesFiles do
  VFS.Include(utilitiesFiles[i])
end
