---@class PickupController : ImplementController
PickupController = CpObject(ImplementController)
PickupController.maxFillLevelPercentage = 0.99

function PickupController:init(vehicle)
    self.pickup = AIUtil.getImplementOrVehicleWithSpecialization(vehicle, Pickup)
    ImplementController.init(self, vehicle, self.pickup)
	
	--- Registers event listeners for lowering/raising of the pickup.
	local function lowerPickup(pickup,superFunc,...)
		if superFunc ~= nil then superFunc(pickup,...) end
		pickup:setPickupState(true)
	end
	local function raisePickup(pickup,superFunc,...)
		if superFunc ~= nil then superFunc(pickup,...) end
		pickup:setPickupState(false)
	end

	self:registerOverwrittenFunction(Pickup,"onAIImplementStartLine",lowerPickup)
	self:registerAIEvents(Pickup,"onAIImplementStartLine")
	self:registerOverwrittenFunction(Pickup,"onAIImplementEndLine",raisePickup)
	self:registerAIEvents(Pickup,"onAIImplementEndLine")
	self:registerOverwrittenFunction(Pickup,"onAIImplementEnd",raisePickup)
	self:registerAIEvents(Pickup,"onAIImplementEnd")
end

