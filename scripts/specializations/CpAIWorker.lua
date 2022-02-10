--- Base cp ai specialization.
local modName = CpAIWorker and CpAIWorker.MOD_NAME -- for reload

---@class CpAIWorker
CpAIWorker = {}

CpAIWorker.MOD_NAME = g_currentModName or modName
CpAIWorker.NAME = ".cpAIWorker"
CpAIWorker.SPEC_NAME = CpAIWorker.MOD_NAME .. CpAIWorker.NAME
CpAIWorker.KEY = "."..CpAIWorker.MOD_NAME..CpAIWorker.NAME .. "."

function CpAIWorker.initSpecialization()
    local schema = Vehicle.xmlSchemaSavegame
end

function CpAIWorker.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(AIFieldWorker, specializations) 
end

function CpAIWorker.register(typeManager,typeName,specializations)
	if CpAIWorker.prerequisitesPresent(specializations) then
		typeManager:addSpecialization(typeName, CpAIWorker.SPEC_NAME)
	end
end

function CpAIWorker.registerEvents(vehicleType)
    SpecializationUtil.registerEvent(vehicleType, "onCpFinished")
	SpecializationUtil.registerEvent(vehicleType, "onCpEmpty")
    SpecializationUtil.registerEvent(vehicleType, "onCpFull")
end

function CpAIWorker.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", CpAIWorker)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", CpAIWorker)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdateTick", CpAIWorker)
end

function CpAIWorker.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "getIsCpActive", CpAIWorker.getIsCpActive)
	SpecializationUtil.registerFunction(vehicleType, "getCpStartableJob", CpAIWorker.getCpStartableJob)
	SpecializationUtil.registerFunction(vehicleType, "getCpStartText", CpAIWorker.getCpStartText)
    SpecializationUtil.registerFunction(vehicleType, "cpStartStopDriver", CpAIWorker.startStopDriver)
    SpecializationUtil.registerFunction(vehicleType, "getCanStartCp", CpAIWorker.getCanStartCp)
end

function CpAIWorker.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, 'stopCurrentAIJob', CpAIWorker.stopCurrentAIJob)

end
------------------------------------------------------------------------------------------------------------------------
--- Event listeners
---------------------------------------------------------------------------------------------------------------------------
function CpAIWorker:onLoad(savegame)
	--- Register the spec: spec_CpAIWorker
    self.spec_cpAIWorker = self["spec_" .. CpAIWorker.SPEC_NAME]
    local spec = self.spec_cpAIWorker
   
end

--- Registers the start stop action event.
function CpAIWorker:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
	if self.isClient then
		local spec = self.spec_cpAIWorker

		self:clearActionEventsTable(spec.actionEvents)

        if self.spec_aiJobVehicle.supportsAIJobs and self:getIsActiveForInput(true, true) then
			local _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.CP_START_STOP, self, CpAIWorker.startStopDriver, false, true, false, true, nil)
            g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_HIGH)
            CpAIWorker.updateActionEvents(self)
		end
	end
end

--- Updates the start stop action event visibility and text.
function CpAIWorker:updateActionEvents()
    local spec = self.spec_cpAIWorker
    local giantsSpec = self.spec_aiJobVehicle
	local actionEvent = spec.actionEvents[InputAction.CP_START_STOP]

	if actionEvent ~= nil and self.isActiveForInputIgnoreSelectionIgnoreAI then
		if self:getShowAIToggleActionEvent() then
            if self:getIsAIActive() then 
                g_inputBinding:setActionEventText(actionEvent.actionEventId, "CP: "..giantsSpec.texts.dismissEmployee)
            else
                local text = string.format("CP: %s\n(%s)",giantsSpec.texts.hireEmployee,self:getCpStartText())
			    g_inputBinding:setActionEventText(actionEvent.actionEventId,text)
            end

			g_inputBinding:setActionEventActive(actionEvent.actionEventId, true)
		else
			g_inputBinding:setActionEventActive(actionEvent.actionEventId, false)
		end
	end
end

function CpAIWorker:onUpdateTick(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
	CpAIWorker.updateActionEvents(self)
end


--- Post cp helper release handling.
--- Is used for the communication to external mods with events.
function CpAIWorker:stopCurrentAIJob(superFunc,message,...)
    local wasCpActive = self:getIsCpActive()
    if wasCpActive then
        -- TODO: this isn't needed if we do not return a 0 < maxSpeed < 0.5, should either be exactly 0 or greater than 0.5
        local maxSpeed = self.spec_cpAIWorker.driveStrategy and self.spec_cpAIWorker.driveStrategy:getMaxSpeed()
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
                --- Folds implements at the end if the setting is active.
                self:prepareForAIDriving()
            end
        end
    end
end

--- Directly starts a cp job or stops a currently active job.
function CpAIWorker:startStopDriver()
    CpUtil.infoVehicle(self,"Start/stop cp helper")
    local spec = self.spec_cpAIWorker
    if self:getIsAIActive() then
		self:stopCurrentAIJob(AIMessageSuccessStoppedByUser.new())
        CpUtil.infoVehicle(self,"Stopped current helper.")
	else
        self:updateAIFieldWorkerImplementData()
		local job = self:getCpStartableJob()
        if self:getCanStartCp() and job then

            job = self:getCpStartableJob()

            job:applyCurrentState(self, g_currentMission, g_currentMission.player.farmId, true)
            job:setValues()
         --   local success = spec.cpJob:validate(false)
         --   if success then
            if true then
                g_client:getServerConnection():sendEvent(AIJobStartRequestEvent.new(job, self:getOwnerFarmId()))
                CpUtil.infoVehicle(self,"Cp helper started.")
            else
                CpUtil.infoVehicle(self,"Job parameters not valid.")
            end
        else
            CpUtil.infoVehicle(self,"Could not start CP helper, it needs a course when not collecting bales.")
        end
	end
end

--- Is a cp worker active ? 
--- Every cp job should be an instance of type CpAIJob.
function CpAIWorker:getIsCpActive()
    return self:getIsAIActive() and self:getJob() and self:getJob():isa(CpAIJob)
end

--- Is a cp job ready to be started?
function CpAIWorker:getCanStartCp()
    return false
end

--- Gets the job to be started by the hud or the keybinding.
function CpAIWorker:getCpStartableJob()
	
end

--- Gets the additional action event start text, 
--- for example the starting point.
function CpAIWorker:getCpStartText()
	return ""
end

