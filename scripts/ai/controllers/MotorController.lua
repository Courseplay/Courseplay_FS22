--- Adds fuel save mode.
---@class MotorController : ImplementController
MotorController = CpObject(ImplementController)
MotorController.delayMs = 10 * 1000 -- 30sec
MotorController.speedThreshold = 0.1
function MotorController:init(vehicle, implement)
    ImplementController.init(self, vehicle, implement)
	self.motorSpec = implement.spec_motorized
	self.timer = CpTemporaryObject(true)
	self.timerSet = false
	self.vehicle.spec_cpAIWorker.motorDisabled = false
end

function MotorController:update()
	if not self.settings.fuelSave:getValue() then 
		if not self.motorSpec.isMotorStarted then 
			self:startMotor()
			self.vehicle:raiseAIEvent("onAIFieldWorkerContinue", "onAIImplementContinue")
		end
		self.timerSet = false
		return
	end
	if self:isFuelSaveDisabled() or self.driveStrategy:getMaxSpeed() > self.speedThreshold then
		if not self.motorSpec.isMotorStarted then 
			self:startMotor()
			self.vehicle:raiseAIEvent("onAIFieldWorkerContinue", "onAIImplementContinue")
		end
		self.timerSet = false
	elseif self.vehicle:getLastSpeed() <= self.speedThreshold then
		if not self.timerSet then 
			--- Resets the timer
			self.timer:set(false, self.delayMs)
			self.timerSet = true
		end
		if self.timer:get() then 
			if self.motorSpec.isMotorStarted then
				self.vehicle:raiseAIEvent("onAIFieldWorkerBlock", "onAIImplementBlock")
				self:stopMotor()
			end
		end
	end
	if self:isFuelLow(0.1) then -- 10% 
		self:setInfoText(InfoTextManager.FUEL_IS_LOW)
	else 
		self:clearInfoText(InfoTextManager.FUEL_IS_LOW)
	end
	if self:isFuelEmpty() then 
		self.vehicle:stopCurrentAIJob(AIMessageErrorOutOfFuel.new())
	end
end

function MotorController:isFuelLow(threshold)
    for _, fillUnit in pairs(self.motorSpec.propellantFillUnitIndices) do
        if self.implement:getFillUnitFillLevelPercentage(fillUnit) < threshold then 
            return true
        end
     end
end

function MotorController:isFuelEmpty()
	for _, fillUnit in pairs(self.motorSpec.propellantFillUnitIndices) do
		if self.implement:getFillUnitFillLevel(fillUnit) == 0 then
			return true
		end
	end
end

--- Fuel save disabled, then we need to make sure the motor gets turned back on.
function MotorController:isFuelSaveDisabled()
	return not self.driveStrategy:isFuelSaveAllowed()
end

function MotorController:startMotor()
	self.vehicle.spec_cpAIWorker.motorDisabled = false
	self.implement:startMotor()
	self:debug("Started motor after fuel save.")
end

function MotorController:stopMotor()
	self.implement:stopMotor()
	self.vehicle.spec_cpAIWorker.motorDisabled = true
	self:debug("Stopped motor for fuel save.")
end