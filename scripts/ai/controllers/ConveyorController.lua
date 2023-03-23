--- Raises/lowers the additional cutters, like the straw/grass pickup for harvesters.
--- Also disables the cutter, while it's waiting for unloading.
---@class ConveyorController : ImplementController
ConveyorController = CpObject(ImplementController)

function ConveyorController:init(vehicle, implement)
    ImplementController.init(self, vehicle, implement)
    self.conveyorSpec = self.implement.spec_conveyor

	self.isDischargeEnabled = false
end

function ConveyorController:getDriveData()
	local maxSpeed
	if self.isDischargeEnabled then
	
		if self:canDischargeToObject() then 
			if not self:isDischarging() then 
				self.implement:setDischargeState(Dischargeable.DISCHARGE_STATE_OBJECT)
			end
		else 
			if self:isDischarging() then 
				self.implement:setDischargeState(Dischargeable.DISCHARGE_STATE_OFF)
			end
			maxSpeed = 0
		end
		if self:isDischarging() and self:canDischargeToObject() then 
			self:clearInfoText(InfoTextManager.WAITING_FOR_UNLOADER)
		else 
			self:setInfoText(InfoTextManager.WAITING_FOR_UNLOADER)
		end
	end
	return nil, nil, nil, maxSpeed
end

function ConveyorController:isDischarging()
	return self.implement:getDischargeState() ~= Dischargeable.DISCHARGE_STATE_OFF
end

function ConveyorController:enableDischargeToObject()
	self.isDischargeEnabled = true
end

function ConveyorController:disableDischarge()
	self.isDischargeEnabled = false
	self:clearInfoText(InfoTextManager.WAITING_FOR_UNLOADER)
end

function ConveyorController:onFinished()
	self.implement:aiImplementEndLine()
	self.implement:setIsTurnedOn(false)
	self:disableDischarge()
end

function ConveyorController:onLowering()
	self.implement:aiImplementStartLine()
end

function ConveyorController:onRaising()
	self.implement:aiImplementEndLine()
end

function ConveyorController:canDischargeToObject()
	return self.implement:getCanDischargeToObject(self.implement:getCurrentDischargeNode())
end

function ConveyorController:getDischargeFillType()
	return self.implement:getDischargeFillType(self:getDischargeNode())
end

function ConveyorController:getDischargeNode()
	return self.implement:getCurrentDischargeNode()
end

function ConveyorController:getPipeOffsetX()
	local x, _, _ = localToLocal(self:getDischargeNode().node, self.implement.rootNode, 0, 0, 0)
	return x
end

function ConveyorController:getPipeOffsetZ()
	return ImplementUtil.getDistanceToImplementNode(self.vehicle:getAIDirectionNode(), 
		self.implement, self:getDischargeNode().node)
end

function ConveyorController:isPipeOnTheLeftSide()
	return self:getPipeOffsetX() >= 0
end

function ConveyorController:isPipeMoving()
	return not self.implement:getCanAIImplementContinueWork()
end