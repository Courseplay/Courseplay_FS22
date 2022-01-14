---@class PickupController : ImplementController
PickupController = CpObject(ImplementController)
PickupController.maxFillLevelPercentage = 0.99

function PickupController:init(vehicle,implement)
    ImplementController.init(self, vehicle, implement)
	self.pickup = implement
end
--- Registers event listeners for lowering/raising of the pickup.
local function lowerPickup(pickup,superFunc,...)
	if superFunc ~= nil then superFunc(pickup,...) end
	if pickup.rootVehicle and pickup.rootVehicle:getIsCpActive() then
		pickup:setPickupState(true)
	end
end
local function raisePickup(pickup,superFunc,...)
	if superFunc ~= nil then superFunc(pickup,...) end
	if pickup.rootVehicle and pickup.rootVehicle:getIsCpActive() then
		pickup:setPickupState(false)
	end
end
Pickup.onAIImplementStartLine = Utils.overwrittenFunction(Pickup.onAIImplementStartLine,lowerPickup)
Pickup.onAIImplementEndLine = Utils.overwrittenFunction(Pickup.onAIImplementStartLine,raisePickup)
Pickup.onAIImplementEnd = Utils.overwrittenFunction(Pickup.onAIImplementStartLine,raisePickup)