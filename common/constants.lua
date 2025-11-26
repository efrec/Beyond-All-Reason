-- common/constants.lua --------------------------------------------------------
-- Include only global constant values that must be available generally to envs.

if CMD then
	CMD.ANY = "a" --- Match string for permissive command matching, including NIL.
	CMD.NIL = "n" --- Match string for empty or malformed commands with cmdID == nil.
	CMD.BUILD = "b" --- Match string for commands with non-nil cmdID, and cmdID < 0.
end
