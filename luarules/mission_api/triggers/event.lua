-- Raised by whatever names it: an objective's `onCompleted`, for now.
-- Declares no callins and no parameters, so nothing else can fire it.

---Fires only when an objective names it in one of its events (onActivated, onProgress, onCompleted, or onCanceled). It has no parameters and never fires on its own.
---@class EventTrigger

return {
	type = 'Event',
	parameters = {},
}
