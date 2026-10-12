local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function issueOrders(unitName, orders)
	local tracking = GG['MissionAPI'].Modules.Tracking
	if tracking.IsUnitNameUntracked(unitName) then return end

	local convertedOrders = GG['MissionAPI'].Modules.Loadout.ConvertOrdersTargetingNames(orders)

	-- Fence around mission-issued orders for UnitOrdered triggers using `ignoreMissionActions`.
	GG['MissionAPI'].issuingOrders = true
	Spring.GiveOrderArrayToUnitMap(GG['MissionAPI'].trackedUnitIDs[unitName], convertedOrders)
	GG['MissionAPI'].issuingOrders = nil
end

return {
	---Gives the units with a name a list of orders, as if the player had issued them.
	---
	---Every unit with the name receives the whole list. Each order is { command, params, options }: command is a command ID, or a unit def name for a build order; params are the command's numbers, such as { x, y, z } for a move or { x, y, z, radius } for an area command; and options are any of 'shift', 'alt', 'ctrl', 'right', and 'meta'. Add 'shift' to queue an order behind the previous ones; without it, the order replaces the unit's current queue. Where a command targets a unit or feature, params may be { unitName = '...' } or { featureName = '...' } instead, and the order is repeated for every unit or feature with that name, with the copies queued behind the first. UnitOrdered and RallyOrdered triggers ignore these orders unless they set ignoreMissionActions = false. Nothing happens when no unit has the name.
	---@class IssueOrdersAction
	---@field unitName UnitName The name whose units receive the orders.
	---@field orders Orders The orders to give, in list order.
	{
		type = 'IssueOrders',
		parameters = {
			{ name = 'unitName', required = true, type = ParameterTypes.UnitName },
			{ name = 'orders', required = true, type = ParameterTypes.Orders },
		},
		actionFunction = issueOrders,
	}
}
