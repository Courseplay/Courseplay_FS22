    --- Base cp ai specialization.
local modName = CpAIWorker and CpAIWorker.MOD_NAME -- for reload

---@class CpAIWorker
CpAIWorker = {}

CpAIWorker.MOD_NAME = g_currentModName or modName
CpAIWorker.NAME = ".cpAIWorker"
CpAIWorker.SPEC_NAME = CpAIWorker.MOD_NAME .. CpAIWorker.NAME
CpAIWorker.KEY = "."..CpAIWorker.MOD_NAME..CpAIWorker.NAME .. "."
CpAIWorker.LAST_JOB_KEY = "vehicles.vehicle(?).aiJobVehicle.lastJob"

function CpAIWorker.initSpecialization()
    local schema = Vehicle.xmlSchemaSavegame
    --- Registers the last job key.
    CpJobParameters.registerXmlSchema(schema, CpAIWorker.LAST_JOB_KEY)
end

function CpAIWorker.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(AIFieldWorker, specializations)
end

function CpAIWorker.register(typeManager, typeName, specializations)
	if CpAIWorker.prerequisitesPresent(specializations) then
		typeManager:addSpecialization(typeName, CpAIWorker.SPEC_NAME)
	end
end

function CpAIWorker.registerEvents(vehicleType)
    SpecializationUtil.registerEvent(vehicleType, "onCpFinished")
	SpecializationUtil.registerEvent(vehicleType, "onCpEmpty")
    SpecializationUtil.registerEvent(vehicleType, "onCpFull")
    SpecializationUtil.registerEvent(vehicleType, "onCpFuelEmpty")
    SpecializationUtil.registerEvent(vehicleType, "onCpBroken")
    --- internal AD Events.
    SpecializationUtil.registerEvent(vehicleType, "onCpADStartedByPlayer")
    SpecializationUtil.registerEvent(vehicleType, "onCpADRestarted")
end

function CpAIWorker.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", CpAIWorker)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", CpAIWorker)
    SpecializationUtil.registerEventListener(vehicleType, "onLoadFinished", CpAIWorker)
    SpecializationUtil.registerEventListener(vehicleType, "onPreDetachImplement", CpAIWorker)
    SpecializationUtil.registerEventListener(vehicleType, "onPostAttachImplement", CpAIWorker)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdate", CpAIWorker)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdateTick", CpAIWorker)
    --- Autodrive events
    SpecializationUtil.registerEventListener(vehicleType, "onStopAutoDrive", CpAIWorker)
    SpecializationUtil.registerEventListener(vehicleType, "onStartAutoDrive", CpAIWorker)
end

function CpAIWorker.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "getIsCpActive", CpAIWorker.getIsCpActive)
	SpecializationUtil.registerFunction(vehicleType, "getCpStartableJob", CpAIWorker.getCpStartableJob)
	SpecializationUtil.registerFunction(vehicleType, "getCpStartText", CpAIWorker.getCpStartText)
    SpecializationUtil.registerFunction(vehicleType, "cpStartStopDriver", CpAIWorker.startStopDriver)
    SpecializationUtil.registerFunction(vehicleType, "getCanStartCp", CpAIWorker.getCanStartCp)
    SpecializationUtil.registerFunction(vehicleType, "startCpDriveTo", CpAIWorker.startCpDriveTo)
    SpecializationUtil.registerFunction(vehicleType, "stopCpDriveTo", CpAIWorker.stopCpDriveTo)
    SpecializationUtil.registerFunction(vehicleType, "freezeCp", CpAIWorker.freezeCp)
    SpecializationUtil.registerFunction(vehicleType, "unfreezeCp", CpAIWorker.unfreezeCp)
end

function CpAIWorker.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, 'stopCurrentAIJob', CpAIWorker.stopCurrentAIJob)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, 'getCanMotorRun', CpAIWorker.getCanMotorRun)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, 'stopFieldWorker', CpAIWorker.stopFieldWorker)
end
------------------------------------------------------------------------------------------------------------------------
--- Event listeners
---------------------------------------------------------------------------------------------------------------------------
function CpAIWorker:onLoad(savegame)
	--- Register the spec: spec_CpAIWorker
    self.spec_cpAIWorker = self["spec_" .. CpAIWorker.SPEC_NAME]
    local spec = self.spec_cpAIWorker
    --- Flag to make sure the motor isn't being turned on again by giants code, when we want it turned off.
    spec.motorDisabled = false
end

function CpAIWorker:onLoadFinished()
    
end

function CpAIWorker:onPreDetachImplement(implement)
    local spec = self.spec_cpAIWorker
end

function CpAIWorker:onPostAttachImplement(object)
    local spec = self.spec_cpAIWorker

end

--- Registers the start stop action event.
function CpAIWorker:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
	if self.isClient then
		local spec = self.spec_cpAIWorker

		self:clearActionEventsTable(spec.actionEvents)

        if self.spec_aiJobVehicle.supportsAIJobs and self:getIsActiveForInput(true, true) then

            local function addActionEvent(vehicle, event, callback, text)
                local actionEventsVisible = g_Courseplay.globalSettings.showActionEventHelp:getValue()
                local _, actionEventId = vehicle:addActionEvent(spec.actionEvents, event, vehicle, callback, false, true, false, true, nil)
                g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_HIGH)
                g_inputBinding:setActionEventTextVisibility(actionEventId, actionEventsVisible)
                if text ~=nil then 
                    g_inputBinding:setActionEventText(actionEventId, text)
                end
            end

            addActionEvent(self, InputAction.CP_START_STOP, CpAIWorker.startStopDriver)
            addActionEvent(self, InputAction.CP_CHANGE_STARTING_POINT, CpAIWorker.changeStartingPoint)

            addActionEvent(self, InputAction.CP_OPEN_VEHICLE_SETTINGS, CpGuiUtil.openVehicleSettingsGui,
                    g_i18n:getText("input_CP_OPEN_VEHICLE_SETTINGS"))
            addActionEvent(self, InputAction.CP_OPEN_GLOBAL_SETTINGS, CpGuiUtil.openGlobalSettingsGui,
                    g_i18n:getText("input_CP_OPEN_GLOBAL_SETTINGS"))
            addActionEvent(self, InputAction.CP_OPEN_COURSEGENERATOR_SETTINGS, CpGuiUtil.openCourseGeneratorGui,
                    g_i18n:getText("input_CP_OPEN_COURSEGENERATOR_SETTINGS"))
            addActionEvent(self, InputAction.CP_OPEN_COURSEMANAGER, CpGuiUtil.openCourseManagerGui,
                    g_i18n:getText("input_CP_OPEN_COURSEMANAGER"))

            CpAIWorker.updateActionEvents(self)
		end
	end
end

--- Updates the start stop action event visibility and text.
function CpAIWorker:updateActionEvents()
    local spec = self.spec_cpAIWorker
    local giantsSpec = self.spec_aiJobVehicle
	if self.isActiveForInputIgnoreSelectionIgnoreAI and giantsSpec.supportsAIJobs then
        local actionEvent = spec.actionEvents[InputAction.CP_START_STOP]

        if self:getShowAIToggleActionEvent() then
            if self:getIsAIActive() then
                g_inputBinding:setActionEventText(actionEvent.actionEventId, "CP: "..giantsSpec.texts.dismissEmployee)
            else
                local text = string.format("CP: %s\n(%s)", giantsSpec.texts.hireEmployee, self:getCpStartText())
			    g_inputBinding:setActionEventText(actionEvent.actionEventId, text)
            end

			g_inputBinding:setActionEventActive(actionEvent.actionEventId, g_Courseplay.globalSettings.showActionEventHelp:getValue())
		else
			g_inputBinding:setActionEventActive(actionEvent.actionEventId, false)
		end
        actionEvent = spec.actionEvents[InputAction.CP_CHANGE_STARTING_POINT]
        local startingPointSetting = self:getCpStartingPointSetting()
        g_inputBinding:setActionEventText(actionEvent.actionEventId, string.format("%s %s", startingPointSetting:getTitle(), startingPointSetting:getString()))
        g_inputBinding:setActionEventActive(actionEvent.actionEventId, self:getCanStartCpFieldWork())
    end
end

function CpAIWorker:onUpdateTick(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
	CpAIWorker.updateActionEvents(self)
end


--- Used to enable/disable release of the helper
--- and handles post release functionality with for example auto drive.
--- TODO: This function is a mess and desperately needs a better solution!
function CpAIWorker:stopCurrentAIJob(superFunc, message, ...)
    if message then
        CpUtil.debugVehicle(CpDebug.DBG_FIELDWORK, self, "stop message: %s", message:getMessage())
    else
        CpUtil.infoVehicle(self, "no stop message was given.")
        return superFunc(self, message, ...)
    end
    local releaseMessage, hasFinished, event = g_infoTextManager:getInfoTextDataByAIMessage(message)

    CpUtil.debugVehicle(CpDebug.DBG_FIELDWORK, self, "finished: %s, event: %s",
                                                    tostring(hasFinished), tostring(event))

    local wasCpActive = self:getIsCpActive()
    if wasCpActive then
        local driveStrategy = self:getCpDriveStrategy()
        if driveStrategy then
            -- TODO: this isn't needed if we do not return a 0 < maxSpeed < 0.5, should either be exactly 0 or greater than 0.5
            local maxSpeed = driveStrategy and driveStrategy:getMaxSpeed()
            if self.spec_aiFieldWorker.didNotMoveTimer and self.spec_aiFieldWorker.didNotMoveTimer < 0 and
            message:isa(AIMessageErrorBlockedByObject) and maxSpeed and maxSpeed < 1 then
                -- disable the Giants timeout which dismisses the AI worker if it does not move for 5 seconds
                -- since we often stop for instance in convoy mode when waiting for another vehicle to turn
                -- (when we do this, we set our maxSpeed to 0). So we also check our maxSpeed, this way the Giants timer will
                -- fire if we are blocked (thus have a maxSpeed > 0 but not moving)
                CpUtil.debugVehicle(CpDebug.DBG_FIELDWORK, self, 'Overriding the Giants did not move timer.')
                return
            end
            driveStrategy:onFinished()
        end
    end
    self:resetCpAllActiveInfoTexts()
    --- Only add the info text, if it's available and nobody is in the vehicle.
    if not self:getIsControlled() and releaseMessage then
        self:setCpInfoTextActive(releaseMessage)
    end
    superFunc(self, message,...)
    if wasCpActive then
        if event then
            SpecializationUtil.raiseEvent(self, event)
        end
        if hasFinished and self:getCpSettings().foldImplementAtEnd:getValue() then
            --- Folds implements at the end if the setting is active.
            self:prepareForAIDriving()
        end

    end
end


-----------------------------------------------
--- Action input events
-----------------------------------------------

function CpAIWorker:changeStartingPoint()
    --- Input event
end

--- Directly starts a cp job or stops a currently active job.
function CpAIWorker:startStopDriver()
    CpUtil.debugVehicle(CpDebug.DBG_FIELDWORK, self, "Start/stop cp helper")
    if self:getIsAIActive() then
		self:stopCurrentAIJob(AIMessageSuccessStoppedByUser.new())
        CpUtil.debugVehicle(CpDebug.DBG_FIELDWORK, self, "Stopped current helper.")
	else
        self:updateAIFieldWorkerImplementData()
		local job = self:getCpStartableJob()
        if self:getCanStartCp() and job then

            job:applyCurrentState(self, g_currentMission, g_currentMission.player.farmId, true, job:getCanGenerateFieldWorkCourse())
            job:setValues()
            local success, message = job:validate(false)
            if success then
                g_client:getServerConnection():sendEvent(AIJobStartRequestEvent.new(job, self:getOwnerFarmId()))
                CpUtil.debugVehicle(CpDebug.DBG_FIELDWORK, self, "Cp helper started.")
            else
                CpUtil.debugVehicle(CpDebug.DBG_FIELDWORK, self, "Could not start CP helper: %s", tostring(message))
                if message then
                    g_currentMission:showBlinkingWarning("CP: "..message, 5000)
                end
            end
        else
            CpUtil.debugVehicle(CpDebug.DBG_FIELDWORK, self, "Could not start CP helper, it needs a course when not collecting bales.")
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

--- Makes sure giants isn't turning the motor back on, when we have turned it off.
function CpAIWorker:getCanMotorRun(superFunc, ...)
    if self:getIsCpActive() and self.spec_cpAIWorker.motorDisabled then
        return false
    end
    return superFunc(self, ...)
end

function CpAIWorker:startCpDriveTo(task, jobParameters)
    self.driveToTask = task
    ---@type AIDriveStrategyDriveToFieldWorkStart
    self.driveToFieldWorkStartStrategy = AIDriveStrategyDriveToFieldWorkStart.new()
    -- this also starts the strategy
    self.driveToFieldWorkStartStrategy:setAIVehicle(self, jobParameters)
end

function CpAIWorker:stopCpDriveTo()
    self.driveToFieldWorkStartStrategy:delete()
    self.driveToFieldWorkStartStrategy = nil
end

function CpAIWorker:onUpdate(dt)
    if self.driveToFieldWorkStartStrategy and self.isServer then
        if self.driveToFieldWorkStartStrategy:isWorkStartReached() then
            CpUtil.debugVehicle(CpDebug.DBG_FIELDWORK, self, 'Work start location reached')
            self.driveToTask:onTargetReached(self.driveToFieldWorkStartStrategy:getStartPosition())
        else
            self.driveToFieldWorkStartStrategy:update(dt)
            if g_updateLoopIndex % 4 == 0 then
                local tX, tZ, moveForwards, maxSpeed = self.driveToFieldWorkStartStrategy:getDriveData(dt)

                -- same as AIFieldWorker:updateAIFieldWorker(), do the actual driving
                local tY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, tX, 0, tZ)
                local pX, _, pZ = worldToLocal(self:getAISteeringNode(), tX, tY, tZ)

                if not moveForwards and self.spec_articulatedAxis ~= nil and
                        self.spec_articulatedAxis.aiRevereserNode ~= nil then
                    pX, _, pZ = worldToLocal(self.spec_articulatedAxis.aiRevereserNode, tX, tY, tZ)
                end

                if not moveForwards and self:getAIReverserNode() ~= nil then
                    pX, _, pZ = worldToLocal(self:getAIReverserNode(), tX, tY, tZ)
                end

                local acceleration = 1
                local isAllowedToDrive = maxSpeed ~= 0

                AIVehicleUtil.driveToPoint(self, dt, acceleration, isAllowedToDrive, moveForwards, pX, pZ, maxSpeed)
            end
        end
    end
end

--- Freeze (set speed to 0) of the CP driver, but keep everything up and running, showing all debug
--- drawings, etc. This is for troubleshooting only
function CpAIWorker:freezeCp()
    self:getCpDriveStrategy():freeze()
end

--- Unfreeze, continue work normally.
function CpAIWorker:unfreezeCp()
    self:getCpDriveStrategy():unfreeze()
end

function CpAIWorker:stopFieldWorker(superFunc, ...)
    --- Reset the flag.
    self.spec_cpAIWorker.motorDisabled = false
    superFunc(self, ...)    
end

--- Auto drive stop
function CpAIWorker:onStopAutoDrive(isPassingToCP, isStartingAIVE)
    if g_server then 
        CpUtil.infoVehicle(self, "isPassingToCP: %s, isStartingAIVE: %s", tostring(isPassingToCP), tostring(isStartingAIVE))
        if self.ad.restartCP then 
            --- Is restarted for refilling or unloading.
            CpUtil.infoVehicle(self, "Was refilled/unloaded by AD.")
        else 
            --- Is sent to a field.
            CpUtil.infoVehicle(self, "Was sent to field by AD.")
        end
    end
end

--- Auto drive start
function CpAIWorker:onStartAutoDrive()
    if g_server then 
        if self.ad.restartCP then 
            --- Use last job parameters.
            --- Only the start point needs to be forced back!
            SpecializationUtil.raiseEvent(self, "onCpADRestarted")
        elseif g_currentMission.controlledVehicle == self then 
            --- Apply hud variables
            SpecializationUtil.raiseEvent(self, "onCpADStartedByPlayer")
        end
    elseif g_currentMission.controlledVehicle == self then 
        --- Apply hud variables
        SpecializationUtil.raiseEvent(self, "onCpADStartedByPlayer")
        CpJobStartAtLastWpSyncRequestEvent.sendEvent(self)
    end
end