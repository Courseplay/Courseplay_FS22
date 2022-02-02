--- This spec is only for overwriting giants function of the AIFieldWorker.
local modName = CpAIFieldWorker and CpAIFieldWorker.MOD_NAME -- for reload

---@class CpAIFieldWorker
CpAIFieldWorker = {}

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
    SpecializationUtil.registerEventListener(vehicleType, "onCpFinished", CpAIFieldWorker)

    SpecializationUtil.registerEventListener(vehicleType, "onPostDetachImplement", CpAIFieldWorker)
    SpecializationUtil.registerEventListener(vehicleType, "onPostAttachImplement", CpAIFieldWorker)
    SpecializationUtil.registerEventListener(vehicleType, 'onCpCourseChange', CpAIFieldWorker)
end

function CpAIFieldWorker.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "getIsCpActive", CpAIFieldWorker.getIsCpActive)
    SpecializationUtil.registerFunction(vehicleType, "getIsCpFieldWorkActive", CpAIFieldWorker.getIsCpFieldWorkActive)
    SpecializationUtil.registerFunction(vehicleType, "getCpFieldWorkProgress", CpAIFieldWorker.getCpFieldWorkProgress)
    SpecializationUtil.registerFunction(vehicleType, "getIsCpHarvesterWaitingForUnload",
            CpAIFieldWorker.getIsCpHarvesterWaitingForUnload)
    SpecializationUtil.registerFunction(vehicleType, "getIsCpHarvesterWaitingForUnloadInPocket",
            CpAIFieldWorker.getIsCpHarvesterWaitingForUnloadInPocket)
    SpecializationUtil.registerFunction(vehicleType, "getIsCpHarvesterWaitingForUnloadAfterPulledBack",
            CpAIFieldWorker.getIsCpHarvesterWaitingForUnloadAfterPulledBack)
    SpecializationUtil.registerFunction(vehicleType, "getIsCpHarvesterManeuvering", CpAIFieldWorker.getIsCpHarvesterManeuvering)
    SpecializationUtil.registerFunction(vehicleType, "holdCpHarvesterTemporarily", CpAIFieldWorker.holdCpHarvesterTemporarily)
    SpecializationUtil.registerFunction(vehicleType, "cpStartFieldWorker", CpAIFieldWorker.startFieldWorker)
    SpecializationUtil.registerFunction(vehicleType, "cpStartStopDriver", CpAIFieldWorker.startStopDriver)
    SpecializationUtil.registerFunction(vehicleType, "getCanStartCpFieldWork", CpAIFieldWorker.getCanStartCpFieldWork)
    SpecializationUtil.registerFunction(vehicleType, "getCanStartCpBaleFinder", CpAIFieldWorker.getCanStartCpBaleFinder)

    SpecializationUtil.registerFunction(vehicleType, "startCpAtFirstWp", CpAIFieldWorker.startCpAtFirstWp)
    SpecializationUtil.registerFunction(vehicleType, "startCpAtLastWp", CpAIFieldWorker.startCpAtLastWp)
    SpecializationUtil.registerFunction(vehicleType, "getCpDriveStrategy", CpAIFieldWorker.getCpDriveStrategy)
    SpecializationUtil.registerFunction(vehicleType, "getCpStartingPointSetting", CpAIFieldWorker.getCpStartingPointSetting)
    SpecializationUtil.registerFunction(vehicleType, "getCpLaneOffsetSetting", CpAIFieldWorker.getCpLaneOffsetSetting)
end

function CpAIFieldWorker.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, 'stopCurrentAIJob', CpAIFieldWorker.stopCurrentAIJob)
   -- SpecializationUtil.registerOverwrittenFunction(vehicleType, 'updateAIFieldWorkerDriveStrategies', CpAIFieldWorker.updateAIFieldWorkerDriveStrategies)
end
------------------------------------------------------------------------------------------------------------------------
--- Event listeners
---------------------------------------------------------------------------------------------------------------------------
function CpAIFieldWorker:onLoad(savegame)
	--- Register the spec: spec_CpAIFieldWorker
    self.spec_cpAIFieldWorker = self["spec_" .. CpAIFieldWorker.SPEC_NAME]
    local spec = self.spec_cpAIFieldWorker
    --- This job is for starting the driving with a key bind or the mini gui.
    spec.cpJob = g_currentMission.aiJobTypeManager:createJob(AIJobType.FIELDWORK_CP)
    spec.cpJob:getCpJobParameters().startAt:setValue(CpJobParameters.START_AT_NEAREST_POINT)
    spec.cpJob:setVehicle(self)
    --- Theses jobs are used for external mod, for example AutoDrive.
    spec.cpJobStartAtFirstWp = g_currentMission.aiJobTypeManager:createJob(AIJobType.FIELDWORK_CP)
    spec.cpJobStartAtFirstWp:getCpJobParameters().startAt:setValue(CpJobParameters.START_AT_FIRST_POINT)
    spec.cpJobStartAtLastWp = g_currentMission.aiJobTypeManager:createJob(AIJobType.FIELDWORK_CP)
    spec.cpJobStartAtLastWp:getCpJobParameters().startAt:setValue(CpJobParameters.START_AT_LAST_POINT)
end

function CpAIFieldWorker:onPostLoad(savegame)
    
end

function CpAIFieldWorker:saveToXMLFile(xmlFile, baseKey, usedModNames)
   
end

function CpAIFieldWorker:onEnterVehicle(isControlling)
    
end

function CpAIFieldWorker:onLeaveVehicle(isControlling)
   
end

function CpAIFieldWorker:onCpCourseChange()
    local spec = self.spec_cpAIFieldWorker
    spec.cpJob:getCpJobParameters():validateSettings()
end

function CpAIFieldWorker:onPostDetachImplement()
    local spec = self.spec_cpAIFieldWorker
    spec.cpJob:getCpJobParameters():validateSettings()
end

function CpAIFieldWorker:onPostAttachImplement()
    local spec = self.spec_cpAIFieldWorker
    spec.cpJob:getCpJobParameters():validateSettings()
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
                local staringPoint = spec.cpJob:getCpJobParameters().startAt:getString()
                local text = string.format("CP: %s\n(%s)",giantsSpec.texts.hireEmployee,staringPoint)
			    g_inputBinding:setActionEventText(actionEvent.actionEventId,text)
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

function CpAIFieldWorker:getCpStartingPointSetting()
    local spec = self.spec_cpAIFieldWorker
    return spec.cpJob:getCpJobParameters().startAt
end

function CpAIFieldWorker:getCpLaneOffsetSetting()
    local spec = self.spec_cpAIFieldWorker
    return spec.cpJob:getCpJobParameters().laneOffset
end

------------------------------------------------------------------------------------------------------------------------
--- Interface for other mods, like AutoDrive
------------------------------------------------------------------------------------------------------------------------
--- Is a cp helper active ?
--- TODO: add other possible jobs here.
function CpAIFieldWorker:getIsCpActive()
    return self:getIsAIActive() and self:getIsCpFieldWorkActive()
end

--- Is a cp fieldwork helper active ?
function CpAIFieldWorker:getIsCpFieldWorkActive()
    return self:getIsAIActive() and self:getJob() and self:getJob():isa(AIJobFieldWorkCp)
end

function CpAIFieldWorker:getCpFieldWorkProgress()
    if self.spec_cpAIFieldWorker.driveStrategy then
        return self.spec_cpAIFieldWorker.driveStrategy:getProgress()
    end
end

function CpAIFieldWorker:getCpDriveStrategy()
    return self.spec_cpAIFieldWorker.driveStrategy
end

--- To find out if a harvester is waiting to be unloaded, either because it is full or ended the fieldwork course
--- with some grain in the tank.
---@return boolean true when the harvester is waiting to be unloaded
function CpAIFieldWorker:getIsCpHarvesterWaitingForUnload()
    return self.spec_cpAIFieldWorker.combineDriveStrategy and
            self.spec_cpAIFieldWorker.combineDriveStrategy:isWaitingForUnload()
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

--- Maneuvering means turning or working on a pocket or pulling back due to the pipe in fruit
---@return boolean true when the harvester is maneuvering so that an unloader should stay away.
function CpAIFieldWorker:getIsCpHarvesterManeuvering()
    return self.spec_cpAIFieldWorker.combineDriveStrategy and
            self.spec_cpAIFieldWorker.combineDriveStrategy:isManeuvering()
end

--- Hold the harvester (set its speed to 0) for a period of periodMs milliseconds.
--- Calling this again will restart the timer with the new value. Calling with 0 will end the temporary hold
--- immediately.
---@param periodMs number
function CpAIFieldWorker:holdCpHarvesterTemporarily(periodMs)
    return self.spec_cpAIFieldWorker.combineDriveStrategy and
            self.spec_cpAIFieldWorker.combineDriveStrategy:hold(periodMs)
end

--- Starts the cp driver at the first waypoint.
function CpAIFieldWorker:startCpAtFirstWp()
    local spec = self.spec_cpAIFieldWorker
    self:updateAIFieldWorkerImplementData()
    if (self:hasCpCourse() and self:getCanStartCpFieldWork()) or self:getCanStartCpBaleFinder(spec.cpJobStartAtFirstWp:getCpJobParameters()) then
        spec.cpJobStartAtFirstWp:applyCurrentState(self, g_currentMission, g_currentMission.player.farmId, true)
        spec.cpJobStartAtFirstWp:setValues()
        g_client:getServerConnection():sendEvent(AIJobStartRequestEvent.new(spec.cpJobStartAtFirstWp, self:getOwnerFarmId()))
    end
end

--- Starts the cp driver at the last driven waypoint.
function CpAIFieldWorker:startCpAtLastWp()
    local spec = self.spec_cpAIFieldWorker
    self:updateAIFieldWorkerImplementData()
    if (self:hasCpCourse() and self:getCanStartCpFieldWork()) or self:getCanStartCpBaleFinder(spec.cpJobStartAtLastWp:getCpJobParameters()) then
        spec.cpJobStartAtLastWp:applyCurrentState(self, g_currentMission, g_currentMission.player.farmId, true)
        spec.cpJobStartAtLastWp:setValues()
        g_client:getServerConnection():sendEvent(AIJobStartRequestEvent.new(spec.cpJobStartAtLastWp, self:getOwnerFarmId()))
    end
end

--- Event listener called, when an implement is full.
function CpAIFieldWorker:onCpFull()
  
end

--- Event listener called, when an implement is empty.
function CpAIFieldWorker:onCpEmpty()
  
end

--- Event listener called, when the cp job is finished.
function CpAIFieldWorker:onCpFinished()
 
end

--- Post cp helper release handling.
--- Is used for the communication to external mods with events.
function CpAIFieldWorker:stopCurrentAIJob(superFunc,message,...)
    local wasCpActive = self:getIsCpActive()
    if wasCpActive then
        local maxSpeed = self.spec_cpAIFieldWorker.driveStrategy and self.spec_cpAIFieldWorker.driveStrategy:getMaxSpeed()
        if self.spec_aiFieldWorker.didNotMoveTimer and self.spec_aiFieldWorker.didNotMoveTimer < 0 and
         message:isa(AIMessageErrorBlockedByObject) and maxSpeed and maxSpeed < 1 then
            -- disable the Giants timeout which dismisses the AI worker if it does not move for 5 seconds
            -- since we often stop for instance in convoy mode when waiting for another vehicle to turn
            -- (when we do this, we set our maxSpeed to 0). So we also check our maxSpeed, this way the Giants timer will
            -- fire if we are blocked (thus have a maxSpeed > 0 but not moving)
            CpUtil.debugVehicle(CpDebug.DBG_FIELDWORK, self, 'Overriding the Giants did not move timer.')
            return
        end
    end
    superFunc(self,message,...)
    if wasCpActive then 
        if message then
            local foldAtEndAllowed
            if message:isa(AIMessageErrorOutOfFill) then 
                SpecializationUtil.raiseEvent(self,"onCpEmpty")
                foldAtEndAllowed = true
            elseif message:isa(AIMessageErrorIsFull) then 
                SpecializationUtil.raiseEvent(self,"onCpFull")
                foldAtEndAllowed = true
            elseif message:isa(AIMessageSuccessFinishedJob) then 
                SpecializationUtil.raiseEvent(self,"onCpFinished")
                foldAtEndAllowed = true
            end
            if foldAtEndAllowed and self:getCpSettings().foldImplementAtEnd:getValue() then
                --- Folds implements at the end if the setting is set
                self:prepareForAIDriving()
            end
        end
    end
end

--- Directly starts a cp driver or stops a currently active job.
function CpAIFieldWorker:startStopDriver()
    CpUtil.infoVehicle(self,"Start/stop cp helper")
    local spec = self.spec_cpAIFieldWorker
    if self:getIsAIActive() then
		self:stopCurrentAIJob(AIMessageSuccessStoppedByUser.new())
        CpUtil.infoVehicle(self,"Stopped current helper.")
	else
        self:updateAIFieldWorkerImplementData()
        if (self:hasCpCourse() and self:getCanStartCpFieldWork()) or self:getCanStartCpBaleFinder(spec.cpJob:getCpJobParameters()) then
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

--- Is the bale finder with out a course possible and correctly setup.
function CpAIFieldWorker:getCanStartCpBaleFinder(jobParameters)
    if (AIUtil.hasImplementWithSpecialization(self, BaleWrapper) or
            AIUtil.hasImplementWithSpecialization(self, BaleLoader)) and
            jobParameters.startAt:getValue() == CpJobParameters.START_FINDING_BALES then
        return true
    else
        return false
    end
end

function CpAIFieldWorker:getCanStartCpFieldWork()
    -- built in helper can't handle it, but we may be able to ...
    if AIUtil.hasImplementWithSpecialization(self, Baler) or
            AIUtil.hasImplementWithSpecialization(self, BaleWrapper) or
            AIUtil.hasImplementWithSpecialization(self, BaleLoader) or
            AIUtil.hasImplementWithSpecialization(self, ForageWagon) or
            -- built in helper can't handle forage harvesters.
            AIUtil.hasImplementWithSpecialization(self, Cutter) then
        return true
    end
    return self:getCanStartFieldWork()
end

--- Custom version of AIFieldWorker:startFieldWorker()
function CpAIFieldWorker:startFieldWorker(jobParameters)
    --- Calls the giants startFieldWorker function.
    self:startFieldWorker()
    if self.isServer then 
        --- Replaces drive strategies.
        CpAIFieldWorker.replaceAIFieldWorkerDriveStrategies(self,jobParameters)
    end
end

-- We replace the Giants AIDriveStrategyStraight with our AIDriveStrategyFieldWorkCourse  to take care of
-- field work.
function CpAIFieldWorker:replaceAIFieldWorkerDriveStrategies(jobParameters)
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
    if self:getCanStartCpBaleFinder(jobParameters) then
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
    cpDriveStrategy:setAIVehicle(self,jobParameters)
    self.spec_cpAIFieldWorker.driveStrategy = cpDriveStrategy
    --- TODO: Correctly implement this strategy.
	local driveStrategyCollision = AIDriveStrategyCollision.new(cpDriveStrategy)
    driveStrategyCollision:setAIVehicle(self)
    table.insert(spec.driveStrategies, driveStrategyCollision)
    --- Only the last driving strategy can stop the helper, while it is running.
    table.insert(spec.driveStrategies, cpDriveStrategy)
end
