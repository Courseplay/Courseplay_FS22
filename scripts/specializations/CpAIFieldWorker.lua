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

function CpAIFieldWorker.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", CpAIFieldWorker)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", CpAIFieldWorker)
    SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", CpAIFieldWorker)
--    SpecializationUtil.registerEventListener(vehicleType, "getStartAIJobText", CpAIFieldWorker)
    SpecializationUtil.registerEventListener(vehicleType, "onEnterVehicle", CpAIFieldWorker)
    SpecializationUtil.registerEventListener(vehicleType, "onLeaveVehicle", CpAIFieldWorker)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdateTick", CpAIFieldWorker)
end

function CpAIFieldWorker.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "cpStartStopDriver", CpAIFieldWorker.startStopDriver)
    SpecializationUtil.registerFunction(vehicleType, "getCanStartCpFieldWork", CpAIFieldWorker.getCanStartCpFieldWork)
end

function CpAIFieldWorker.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, 'getStartableAIJob', CpAIFieldWorker.getStartableAIJob)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, 'updateAIFieldWorkerDriveStrategies', CpAIFieldWorker.updateAIFieldWorkerDriveStrategies)
end
------------------------------------------------------------------------------------------------------------------------
--- Event listeners
---------------------------------------------------------------------------------------------------------------------------
function CpAIFieldWorker:onLoad(savegame)
	--- Register the spec: spec_CpAIFieldWorker
    self.spec_cpAIFieldWorker = self["spec_" .. CpAIFieldWorker.SPEC_NAME]
    local spec = self.spec_cpAIFieldWorker
    spec.cpJob = g_currentMission.aiJobTypeManager:createJob(AIJobType.FIELDWORK_CP)
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
		if self:getShowAIToggleActionEvent() and not self:getIsAIActive() then

			g_inputBinding:setActionEventText(actionEvent.actionEventId, "CP: "..giantsSpec.texts.hireEmployee)
	

			g_inputBinding:setActionEventActive(actionEvent.actionEventId, true)
		else
			g_inputBinding:setActionEventActive(actionEvent.actionEventId, false)
		end
	end
end

function CpAIFieldWorker:onUpdateTick(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
	CpAIFieldWorker.updateActionEvents(self)
end


--- Directly starts a cp driver or stops a currently active job.
function CpAIFieldWorker:startStopDriver()
    CpUtil.infoVehicle(self,"Start/stop cp helper")
    local spec = self.spec_cpAIFieldWorker
    if self:getIsAIActive() then
		self:stopCurrentAIJob(AIMessageSuccessStoppedByUser.new())
        CpUtil.infoVehicle(self,"Stopped current helper.")
	else
        if self:hasCpCourse() then 
            self:updateAIFieldWorkerImplementData()
            if self:getCanStartCpFieldWork() then
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
                CpUtil.infoVehicle(self,"Could not start cp helper.")
            end
        else
            CpUtil.infoVehicle(self,"No course to start cp helper.")
        end
	end 
end


function CpAIFieldWorker:getCanStartCpFieldWork()
    -- built in helper can't handle it, but we may be able to ...
    if AIUtil.hasImplementWithSpecialization(self, Baler) then
        return true
    end
    -- built in helper can't handle forage harvesters.
    if AIUtil.hasImplementWithSpecialization(self, Cutter) then
        return true
    end
    return self:getCanStartFieldWork()
end

--- Makes sure the "H" key for helper starting, starts the cp job and not the giants default job.
function CpAIFieldWorker:getStartableAIJob(superFunc,...)
    local lastJob = self:getLastJob()
    if lastJob and lastJob:isa(AIJobFieldWorkCp) then
        self:updateAIFieldWorkerImplementData()
        if self:getCanStartFieldWork() then
            local spec = self.spec_cpAIFieldWorker
            local fieldJob = spec.cpJob
            fieldJob:applyCurrentState(self, g_currentMission, g_currentMission.player.farmId, true)
            fieldJob:setValues()
            local success = fieldJob:validate(false)
            if success then
                return fieldJob
            end
        end
    end
    return superFunc(self,...)
end

-- We replace the Giants AIDriveStrategyStraight with our AIDriveStrategyFieldWorkCourse  to take care of
-- field work.
function CpAIFieldWorker:updateAIFieldWorkerDriveStrategies(superFunc, ...)
    local job = self:getJob()
    if not job:isa(AIJobFieldWorkCp) then
        CpUtil.infoVehicle(self, 'Never use the default field work key binding for cp. Continue with default configurations.')
        return superFunc(self, ...)
    else
        CpUtil.infoVehicle(self, 'This is a CP field work job, start the CP AI driver, setting up drive strategies...')
    end
    superFunc(self, ...)

    --- TODO: figure out a good way to handle the insertion or selection of the drive strategies.

    if #self.spec_aiFieldWorker.driveStrategies == 0 then
        CpUtil.infoVehicle(self, 'The built-in AI helper is not able to handle these implements, see if Courseplay can.')
        if AIUtil.hasImplementWithSpecialization(self, Baler) then
            CpUtil.infoVehicle(self, 'Found a baler, install CP drive strategy for it')
            local cpDriveStrategy = AIDriveStrategyFieldWorkCourse.new()
            table.insert(self.spec_aiFieldWorker.driveStrategies, cpDriveStrategy)
            cpDriveStrategy:setAIVehicle(self)
            return
        end
        if AIUtil.hasImplementWithSpecialization(self, Cutter) then
            CpUtil.infoVehicle(self, 'Found a forage cutter, install CP combine drive strategy for it')
            local cpDriveStrategy = AIDriveStrategyCombineCourse.new()
            table.insert(self.spec_aiFieldWorker.driveStrategies, cpDriveStrategy)
            cpDriveStrategy:setAIVehicle(self)
            return
        end
    end
    -- TODO: messing around with AIFieldWorker spec internals is not the best idea, should rather implement
    -- our own specialization
    local strategiesToRemove = {}
    for i, strategy in ipairs(self.spec_aiFieldWorker.driveStrategies) do
        if strategy:isa(AIDriveStrategyStraight) then
            self.spec_aiFieldWorker.driveStrategies[i]:delete()
            local cpDriveStrategy
            if AIUtil.getImplementOrVehicleWithSpecialization(self, Combine) then
                cpDriveStrategy = AIDriveStrategyCombineCourse.new()
                CpUtil.infoVehicle(self, 'Replacing fieldwork helper drive strategy with AIDriveStrategyCombineCourse')
            elseif AIUtil.getImplementWithSpecialization(self, Plow) then
                cpDriveStrategy = AIDriveStrategyPlowCourse.new()
                CpUtil.infoVehicle(self, 'Replacing fieldwork helper drive strategy with AIDriveStrategyPlowCourse')
            else
                cpDriveStrategy = AIDriveStrategyFieldWorkCourse.new()
                CpUtil.infoVehicle(self, 'Replacing fieldwork helper drive strategy with AIDriveStrategyFieldWorkCourse')
            end
            cpDriveStrategy:setAIVehicle(self)
            self.spec_aiFieldWorker.driveStrategies[i] = cpDriveStrategy
        elseif strategy:isa(AIDriveStrategyCombine) then
            self.spec_aiFieldWorker.driveStrategies[i]:delete()
            CpUtil.infoVehicle(self, 'Removing fieldwork helper Giants combine drive strategy (%d)', i)
            table.insert(strategiesToRemove, i)
        elseif FS22_AIVehicleExtension and FS22_AIVehicleExtension.AIDriveStrategyMogli and
                strategy:isa(FS22_AIVehicleExtension.AIDriveStrategyMogli) then
            self.spec_aiFieldWorker.driveStrategies[i]:delete()
            CpUtil.infoVehicle(self, 'Removing AIVehicleExtension drive strategy (%d)', i)
            table.insert(strategiesToRemove, i)
        elseif FS22_AIVehicleExtension and FS22_AIVehicleExtension.AIDriveStrategyCombine131 and
                strategy:isa(FS22_AIVehicleExtension.AIDriveStrategyCombine131) then
            self.spec_aiFieldWorker.driveStrategies[i]:delete()
            CpUtil.infoVehicle(self, 'Removing AIVehicleExtension combine drive strategy (%d)', i)
            table.insert(strategiesToRemove, i)
        end
    end
    for _, ix in ipairs(strategiesToRemove) do
        CpUtil.debugVehicle(CpDebug.DBG_FIELDWORK, self, 'Removing strategy %d', ix)
        table.remove(self.spec_aiFieldWorker.driveStrategies, ix)
    end
end