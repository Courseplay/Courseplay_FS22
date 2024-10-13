--- Adds fuel save mode.
--- Also shuts the driver down, once the fuel level is lower than the threshold.
---@class MotorController : ImplementController
MotorController = CpObject(ImplementController)
MotorController.delayMs = 10 * 1000 -- 10sec
MotorController.speedThreshold = 0.1
function MotorController:init(vehicle, implement)
    ImplementController.init(self, vehicle, implement)
	self.motorSpec = implement.spec_motorized
	self.timer = CpTemporaryObject(true)
	self.timerSet = false
	self.vehicle.spec_cpAIWorker.motorDisabled = false
	self.isValid = true
	self.fuelThresholdSetting = g_Courseplay.globalSettings.fuelThreshold
	self.refuelData = {
		timer = CpTemporaryObject(true),
		hasChanged = false,
		lastFillLevels = {
			[self.implement] = {}
		}
	}
	for _, fillUnitIndex in ipairs(self.motorSpec.propellantFillUnitIndices) do
		self.refuelData.lastFillLevels[self.implement][fillUnitIndex] = -1
	end
end

function MotorController:update()
	if not self.isValid then
		return
	end
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
	local needsFuelLowInfo = false
	if self.refuelData.timer:get() then
		--- Only apply this if no refueling is active.
		if self:isFuelLow(self.fuelThresholdSetting:getValue()) then
			self.vehicle:stopCurrentAIJob(AIMessageErrorOutOfFuel.new())
		elseif self:isFuelLow(self.fuelThresholdSetting:getValue() + 5) then
			needsFuelLowInfo = true
		end
	end
	if needsFuelLowInfo then 
		self:setInfoText(InfoTextManager.FUEL_IS_LOW)
	else
		self:clearInfoText(InfoTextManager.FUEL_IS_LOW)
	end
end

--- There is a time problem with the release of the driver, when no player is entered,
--- so we use this flag to make sure the :update() isn't used after :delete() was called.
function MotorController:delete()
	self.isValid = false
end

function MotorController:isFuelLow(threshold)
    for _, fillUnit in pairs(self.motorSpec.propellantFillUnitIndices) do
        if self.implement:getFillUnitFillLevelPercentage(fillUnit)*100 < threshold then
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

function MotorController:onStartRefuelling() 
	ImplementUtil.hasFillLevelChanged(self.refuelData.lastFillLevels, true)
	self.refuelData.hasChanged = false
	self.refuelData.timer:set(false, 10 * 1000)
end

function MotorController:onUpdateRefuelling()
	if ImplementUtil.tryAndCheckRefillingFillUnits(self.refuelData.lastFillLevels) or 
		ImplementUtil.hasFillLevelChanged(self.refuelData.lastFillLevels) then 
		self.refuelData.timer:set(false, 10 * 1000)
        self.refuelData.hasChanged = true
	end
	return self.refuelData.timer:get(), self.refuelData.hasChanged
end

function MotorController:onStopRefuelling()
	local spec = self.implement.spec_fillUnit
	if spec.fillTrigger.isFilling then 
		self.implement:setFillUnitIsFilling(false)
	end
end

function MotorController:onFinished()
	self:onStopRefuelling()
end