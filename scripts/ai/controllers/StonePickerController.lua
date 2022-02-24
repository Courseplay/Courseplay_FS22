---@class StonePickerController : ImplementController
StonePickerController = CpObject(ImplementController)

function StonePickerController:init(vehicle, stonePicker)
    ImplementController.init(self, vehicle, stonePicker)
	self.stonePickerSpec = stonePicker.spec_stonePicker
end

function StonePickerController:getIsFull()
	return self.implement:getFillUnitFreeCapacity(self.stonePickerSpec.fillUnitIndex) <= 0
end

function StonePickerController:isUnloading()
	return self.implement:getDischargeState() == Dischargeable.DISCHARGE_STATE_OBJECT 
end

function StonePickerController:isClosingAnimationPlaying()
	return self.implement:getTipState() ~= Trailer.TIPSTATE_CLOSED
end

--- Waits while it's full or unloading finished.
function StonePickerController:getDriveData()
	local maxSpeed
	if self:getIsFull() or self:isUnloading() or self:isClosingAnimationPlaying() then 
		maxSpeed = 0
	end

	return nil, nil, nil, maxSpeed
end

--- Does the automatic unloading similar to the Pipe spec.
function StonePickerController:handleDischargeRaycast(superFunc, dischargeNode, hitObject, hitShape, hitDistance, hitFillUnitIndex, hitTerrain)
	if not self.rootVehicle.getIsCpActive or not self.rootVehicle:getIsCpActive() then 
		return superFunc(self, dischargeNode, hitObject, hitShape, hitDistance, hitFillUnitIndex, hitTerrain)
	end

	local stopDischarge = false

	if hitObject ~= nil then
		local fillType = self:getDischargeFillType(dischargeNode)
		local allowFillType = hitObject:getFillUnitAllowsFillType(hitFillUnitIndex, fillType)

		if allowFillType and hitObject:getFillUnitFreeCapacity(hitFillUnitIndex, fillType, self:getOwnerFarmId()) > 0 then
			self:setDischargeState(Dischargeable.DISCHARGE_STATE_OBJECT, true)
		else
			stopDischarge = true
		end
	else
		stopDischarge = true
	end

	if stopDischarge and self:getDischargeState() == Dischargeable.DISCHARGE_STATE_OBJECT then
		self:setDischargeState(Dischargeable.DISCHARGE_STATE_OFF, true)
	end
end
Dischargeable.handleDischargeRaycast = Utils.overwrittenFunction(Dischargeable.handleDischargeRaycast, StonePickerController.handleDischargeRaycast)
