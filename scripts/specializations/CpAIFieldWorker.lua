--- This spec is only for overwriting giants function of the AIFieldWorker.
local modName = CpAIFieldWorker and CpAIFieldWorker.MOD_NAME -- for reload

---@class CpAIFieldWorker
CpAIFieldWorker = {}

--- Additional Specs for vehicle/implements to use cp with,
--- as these are not supported by the giants helper.  
CpAIFieldWorker.validImplementSpecs = {
    Baler,
    BaleWrapper,
    BaleLoader,
    Cutter,
    ForageWagon
}

CpAIFieldWorker.MOD_NAME = g_currentModName or modName
CpAIFieldWorker.NAME = ".cpAIFieldWorker"
CpAIFieldWorker.SPEC_NAME = CpAIFieldWorker.MOD_NAME .. CpAIFieldWorker.NAME
CpAIFieldWorker.KEY = "."..CpAIFieldWorker.MOD_NAME..CpAIFieldWorker.NAME .. "."

function CpAIFieldWorker.initSpecialization()
    local schema = Vehicle.xmlSchemaSavegame
end

function CpAIFieldWorker.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(AIFieldWorker, specializations) 
end

function CpAIFieldWorker.register(typeManager,typeName,specializations)
	if CpAIFieldWorker.prerequisitesPresent(specializations) then
		typeManager:addSpecialization(typeName, CpAIFieldWorker.SPEC_NAME)
	end
end

function CpAIFieldWorker.registerEvents(vehicleType)
    SpecializationUtil.registerEvent(vehicleType, "onCpFinished")
	SpecializationUtil.registerEvent(vehicleType, "onCpEmpty")
    SpecializationUtil.registerEvent(vehicleType, "onCpFull")
end

function CpAIFieldWorker.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", CpAIFieldWorker)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", CpAIFieldWorker)
    SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", CpAIFieldWorker)
    SpecializationUtil.registerEventListener(vehicleType, "onEnterVehicle", CpAIFieldWorker)
    SpecializationUtil.registerEventListener(vehicleType, "onLeaveVehicle", CpAIFieldWorker)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdateTick", CpAIFieldWorker)
    SpecializationUtil.registerEventListener(vehicleType, "onCpEmpty", CpAIFieldWorker)
    SpecializationUtil.registerEventListener(vehicleType, "onCpFull", CpAIFieldWorker)
end

function CpAIFieldWorker.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "getIsCpActive", CpAIFieldWorker.getIsCpActive)
    SpecializationUtil.registerFunction(vehicleType, "getIsCpFieldWorkActive", CpAIFieldWorker.getIsCpFieldWorkActive)
    SpecializationUtil.registerFunction(vehicleType, "getIsCpHarvesterWaitingForUnload",
            CpAIFieldWorker.getIsCpHarvesterWaitingForUnload)
    SpecializationUtil.registerFunction(vehicleType, "getIsCpHarvesterWaitingForUnloadInPocket",
            CpAIFieldWorker.getIsCpHarvesterWaitingForUnloadInPocket)
    SpecializationUtil.registerFunction(vehicleType, "getIsCpHarvesterWaitingForUnloadAfterPulledBack",
            CpAIFieldWorker.getIsCpHarvesterWaitingForUnloadAfterPulledBack)
    SpecializationUtil.registerFunction(vehicleType, "getIsCpHarvesterManeuvering", CpAIFieldWorker.getIsCpHarvesterManeuvering)
    SpecializationUtil.registerFunction(vehicleType, "holdCpHarvesterTemporarily", CpAIFieldWorker.holdCpHarvesterTemporarily)
    SpecializationUtil.registerFunction(vehicleType, "cpStartFieldworker", CpAIFieldWorker.startFieldworker)
    SpecializationUtil.registerFunction(vehicleType, "cpStartStopDriver", CpAIFieldWorker.startStopDriver)
    SpecializationUtil.registerFunction(vehicleType, "startCpAtFirstWp", CpAIFieldWorker.startCpAtFirstWp)
    SpecializationUtil.registerFunction(vehicleType, "getCanStartCpFieldWork", CpAIFieldWorker.getCanStartCpFieldWork)
end

function CpAIFieldWorker.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, 'updateAIFieldWorkerImplementData',CpAIFieldWorker.updateAIFieldWorkerImplementData)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, 'stopCurrentAIJob',CpAIFieldWorker.stopCurrentAIJob)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, 'stopFieldWorker',CpAIFieldWorker.stopFieldWorker)
end
------------------------------------------------------------------------------------------------------------------------
--- Event listeners
---------------------------------------------------------------------------------------------------------------------------
function CpAIFieldWorker:onLoad(savegame)
	--- Register the spec: spec_CpAIFieldWorker
    self.spec_cpAIFieldWorker = self["spec_" .. CpAIFieldWorker.SPEC_NAME]
    local spec = self.spec_cpAIFieldWorker
    spec.cpJob = g_currentMission.aiJobTypeManager:createJob(AIJobType.FIELDWORK_CP)
    spec.isActive = false
end

function CpAIFieldWorker:onPostLoad(savegame)

end

function CpAIFieldWorker:saveToXMLFile(xmlFile, baseKey, usedModNames)
   
end

function CpAIFieldWorker:onEnterVehicle(isControlling)
    
end

function CpAIFieldWorker:onLeaveVehicle(isControlling)
   
end

function CpAIFieldWorker:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
	if self.isClient then
		local spec = self.spec_cpAIFieldWorker

		self:clearActionEventsTable(spec.actionEvents)

        if self.spec_aiJobVehicle.supportsAIJobs and self:getIsActiveForInput(true, true) then
			local _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.CP_START_STOP, self, CpAIFieldWorker.startStopDriver, false, true, false, true, nil)
            g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_HIGH)
            CpAIFieldWorker.updateActionEvents(self)
		end
	end
end

function CpAIFieldWorker:updateActionEvents()
    local spec = self.spec_cpAIFieldWorker
    local giantsSpec = self.spec_aiJobVehicle
	local actionEvent = spec.actionEvents[InputAction.CP_START_STOP]

	if actionEvent ~= nil and self.isActiveForInputIgnoreSelectionIgnoreAI then
		if self:getShowAIToggleActionEvent() then
            if self:getIsAIActive() then 
                g_inputBinding:setActionEventText(actionEvent.actionEventId, "CP: "..giantsSpec.texts.dismissEmployee)
            else
			    g_inputBinding:setActionEventText(actionEvent.actionEventId, "CP: "..giantsSpec.texts.hireEmployee)
            end

			g_inputBinding:setActionEventActive(actionEvent.actionEventId, true)
		else
			g_inputBinding:setActionEventActive(actionEvent.actionEventId, false)
		end
	end
end

function CpAIFieldWorker:onUpdateTick(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
	CpAIFieldWorker.updateActionEvents(self)
end

--- Makes sure the ai implements are set correctly otherwise a few of the ai events might not be working.
function CpAIFieldWorker:updateAIFieldWorkerImplementData(superFunc)

    local function isValid(object)
        local isAllowed = false 
        --- Add missing implements, that are not enabled for the giants helper.
        for i,spec in pairs(CpAIFieldWorker.validImplementSpecs) do 
            if SpecializationUtil.hasSpecialization(spec,object.specializations) then 
                return true
            end
        end
        return object:getCanImplementBeUsedForAI() 
    end

    if self:getIsCpActive() then 
        local spec = self.spec_aiFieldWorker
	    spec.aiImplementList = {}
        for i,implement in pairs(AIUtil.getAllAttachedImplements(self)) do 
            if isValid(implement.object) then 
                table.insert(spec.aiImplementList,
                    {
                        object = implement.object
                    }
                )
            end
        end
        
    else 
        superFunc(self)
    end
end

--- Hold the harvester (set its speed to 0) for a period of periodMs milliseconds.
--- Calling this again will restart the timer with the new value. Calling with 0 will end the temporary hold
--- immediately.
---@param periodMs number
function CpAIFieldWorker:holdCpHarvesterTemporarily(periodMs)
    return self.spec_cpAIFieldWorker.combineDriveStrategy and
            self.spec_cpAIFieldWorker.combineDriveStrategy:hold(periodMs)
end

--- Directly starts a cp driver or stops a currently active job.
function CpAIFieldWorker:startStopDriver()
    CpUtil.infoVehicle(self,"Start/stop cp helper")
    local spec = self.spec_cpAIFieldWorker
    if self:getIsAIActive() then
		self:stopCurrentAIJob(AIMessageSuccessStoppedByUser.new())
        CpUtil.infoVehicle(self,"Stopped current helper.")
	else
        if (self:hasCpCourse() and self:getCanStartCpFieldWork()) or CpAIFieldWorker.getCanStartFindingBales(self) then
            spec.cpJob:applyCurrentState(self, g_currentMission, g_currentMission.player.farmId, true)
            spec.cpJob:setValues()
         --   local success = spec.cpJob:validate(false)
         --   if success then
            if true then
                g_client:getServerConnection():sendEvent(AIJobStartRequestEvent.new(spec.cpJob, self:getOwnerFarmId()))
                CpUtil.infoVehicle(self,"Cp helper started.")
            else
                CpUtil.infoVehicle(self,"Job parameters not valid.")
            end
        else
            CpUtil.infoVehicle(self,"Could not start CP helper, it needs a course when not collecting bales.")
        end
	end
end

function CpAIFieldWorker:getCanStartFindingBales()
    if (AIUtil.hasImplementWithSpecialization(self, BaleWrapper) or
            AIUtil.hasImplementWithSpecialization(self, BaleLoader)) and
            self.spec_cpAIFieldWorker.cpJob:getCpJobParameters().startAt:getValue() == CpJobParameters.START_FINDING_BALES then
        return true
    else
        return false
    end
end

function CpAIFieldWorker:getCanStartCpFieldWork()
    -- built in helper can't handle it, but we may be able to ...
    for i,spec in pairs(CpAIFieldWorker.validImplementSpecs) do 
        if AIUtil.getImplementOrVehicleWithSpecialization(self, spec) then
            return true
        end
    end
    return self:getCanStartFieldWork()
end

--- Custom version of AIFieldWorker:startFieldWorker()
function CpAIFieldWorker:startFieldworker()
    self.spec_cpAIFieldWorker.isActive = true
    
    local spec = self.spec_aiFieldWorker
	spec.isActive = true

	if self.isServer then
		self:updateAIFieldWorkerImplementData()
	--	self:updateAIFieldWorkerDriveStrategies()

	--	spec.checkImplementDirection = true
	end

	AIFieldWorker.hiredHirables[self] = self

	if self:getAINeedsTrafficCollisionBox() and AIFieldWorker.TRAFFIC_COLLISION ~= nil and AIFieldWorker.TRAFFIC_COLLISION ~= 0 and spec.aiTrafficCollision == nil then
		local collision = clone(AIFieldWorker.TRAFFIC_COLLISION, true, false, true)
		spec.aiTrafficCollision = collision
	end
    
    --- Calls the giants startFieldWorker function.
  --  self:startFieldWorker()
    if self.isServer then 
        --- Replaces drive strategies.
        CpAIFieldWorker.replaceAIFieldWorkerDriveStrategies(self)
    end
end

function CpAIFieldWorker:stopFieldWorker(superFunc,...)
    superFunc(self,...)
    self.spec_cpAIFieldWorker.isActive = false
    self:updateAIFieldWorkerImplementData()
end

-- We replace the Giants AIDriveStrategyStraight with our AIDriveStrategyFieldWorkCourse  to take care of
-- field work.
function CpAIFieldWorker:replaceAIFieldWorkerDriveStrategies()
    CpUtil.infoVehicle(self, 'This is a CP field work job, start the CP AI driver, setting up drive strategies...')
    local spec = self.spec_aiFieldWorker
    if spec.driveStrategies ~= nil then
        for i = #spec.driveStrategies, 1, -1 do
            spec.driveStrategies[i]:delete()
            table.remove(spec.driveStrategies, i)
        end

        spec.driveStrategies = {}
    end
    local cpDriveStrategy
    if CpAIFieldWorker.getCanStartFindingBales(self) then
        CpUtil.infoVehicle(self, 'Bale collect/wrap job, install CP drive strategy for it')
        cpDriveStrategy = AIDriveStrategyFindBales.new()
    elseif AIUtil.getImplementOrVehicleWithSpecialization(self, Combine) then
        CpUtil.infoVehicle(self, 'Found a combine, install CP combine drive strategy for it')
        cpDriveStrategy = AIDriveStrategyCombineCourse.new()
        self.spec_cpAIFieldWorker.combineDriveStrategy = cpDriveStrategy
    elseif AIUtil.hasImplementWithSpecialization(self, Plow) then
        CpUtil.infoVehicle(self, 'Found a plow, install CP plow drive strategy for it')
        cpDriveStrategy = AIDriveStrategyPlowCourse.new()
    else
        CpUtil.infoVehicle(self, 'Installing default CP fieldwork drive strategy')
        cpDriveStrategy = AIDriveStrategyFieldWorkCourse.new()
    end
    cpDriveStrategy:setAIVehicle(self)
    table.insert(spec.driveStrategies, cpDriveStrategy)
    --- TODO: Correctly implement this strategy.
	local driveStrategyCollision = AIDriveStrategyCollision.new(cpDriveStrategy)
    driveStrategyCollision:setAIVehicle(self)
    table.insert(spec.driveStrategies, driveStrategyCollision)
end

--- Makes sure the cp driver doesn't stop automatically, if a fill type is empty.
function CpAIFieldWorker:stopCurrentAIJob(superFunc,message,force,...)
    if self:getIsCpActive() and not force then 
        if message:isa(AIMessageErrorOutOfMoney) then 
         --   return 
        elseif message:isa(AIMessageErrorOutOfFill) then 
            return
        end
    end
    return superFunc(self,message,...)
end

--- Stops the driver for now as it is either empty or filled.
function CpAIFieldWorker:onCpEmpty()
    self:stopCurrentAIJob(AIMessageErrorOutOfFill.new(),true)
end

--- Stops the driver for now as it is either empty or filled.
function CpAIFieldWorker:onCpFull()
    self:stopCurrentAIJob(AIMessageErrorOutOfFill.new(),true)
end
------------------------------------------------------------------------------------------------------------------------
--- Interface for other mods, like AutoDrive
------------------------------------------------------------------------------------------------------------------------
--- Is a cp helper active ?
--- TODO: add other possible jobs here.
function CpAIFieldWorker:getIsCpActive()
    return self.spec_cpAIFieldWorker.isActive
end

--- Is a cp fieldwork helper active ?
function CpAIFieldWorker:getIsCpFieldWorkActive()
    return self:getIsAIActive() and self:getJob() and self:getJob():isa(AIJobFieldWorkCp)
end

--- To find out if a harvester is waiting to be unloaded, either because it is full or ended the fieldwork course
--- with some grain in the tank.
---@return boolean true when the harvester is waiting to be unloaded
function CpAIFieldWorker:getIsCpHarvesterWaitingForUnload()
    return self.spec_cpAIFieldWorker.combineDriveStrategy and
            self.spec_cpAIFieldWorker.combineDriveStrategy:isWaitingForUnload()
end

--- Maneuvering means turning or working on a pocket or pulling back due to the pipe in fruit
---@return boolean true when the harvester is maneuvering so that an unloader should stay away.
function CpAIFieldWorker:getIsCpHarvesterManeuvering()
    return self.spec_cpAIFieldWorker.combineDriveStrategy and
            self.spec_cpAIFieldWorker.combineDriveStrategy:isManeuvering()
end

--- To find out if a harvester is waiting to be unloaded in a pocket. Harvesters may cut a pocket on the opposite
--- side of the pipe to make room for an unloader if:
--- * working on the first headland (so the unloader can get under the pipe while staying on the headland)
--- * cutting the first row in the middle of the field
---@return boolean true when the harvester is waiting to be unloaded in a pocket
function CpAIFieldWorker:getIsCpHarvesterWaitingForUnloadInPocket()
    return self.spec_cpAIFieldWorker.combineDriveStrategy and
            self.spec_cpAIFieldWorker.combineDriveStrategy:isWaitingInPocket()
end

--- To find out if a harvester is waiting to be unloaded after it pulled back to the side. This
--- is similar to a pocket but in this case there is no fruit on the opposite side of the pipe,
--- so the harvester just moves to the side and backwards without cutting a pocket.
---@return boolean
function CpAIFieldWorker:getIsCpHarvesterWaitingForUnloadAfterPulledBack()
    return self.spec_cpAIFieldWorker.combineDriveStrategy and
            self.spec_cpAIFieldWorker.combineDriveStrategy:isWaitingForUnloadAfterPulledBack()
end

--- Starts the drive at the first waypoint of the course.
function CpAIFieldWorker:startCpAtFirstWp()
    local setting = self.spec_cpAIFieldWorker.cpJob:getCpJobParameters().startAt
    local backup = setting:getValue()
    setting:setValue(CpJobParameters.START_AT_FIRST_POINT)
    self:cpStartStopDriver()
    setting:setValue(backup)
end
