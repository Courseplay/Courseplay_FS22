--- Cp ai driver spec

---@class CpHud
CpHud = {}

CpHud.MOD_NAME = g_currentModName

CpHud.NAME = ".cpHud"
CpHud.SPEC_NAME = CpHud.MOD_NAME .. CpHud.NAME
CpHud.KEY = "." .. CpHud.MOD_NAME .. CpHud.NAME
CpHud.SETTINGS_KEY = ".settings"
CpHud.isHudActive = false
CpHud.workWidthDisplayDelayMs = 5000 -- 5 seconds
CpHud.hudSettings = {}

function CpHud.initSpecialization()
    local schema = Vehicle.xmlSchemaSavegame
    CpSettingsUtil.registerXmlSchema(schema, 
        "vehicles.vehicle(?)" .. CpHud.KEY .. CpHud.SETTINGS_KEY .. "(?)")
    local filePath = Utils.getFilename("config/HudSettingsSetup.xml", g_Courseplay.BASE_DIRECTORY)
    CpSettingsUtil.loadSettingsFromSetup(CpHud.hudSettings, filePath)
end

function CpHud.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(CpAIWorker, specializations) 
end

function CpHud.register(typeManager,typeName,specializations)
	if CpHud.prerequisitesPresent(specializations) then
		typeManager:addSpecialization(typeName, CpHud.SPEC_NAME)
	end
end

function CpHud.registerEvents(vehicleType)
    SpecializationUtil.registerEvent(vehicleType, 'cpShowWorkWidth')
    SpecializationUtil.registerEvent(vehicleType, 'cpShowBaleCollectorOffset')
    SpecializationUtil.registerEvent(vehicleType, 'cpUpdateMouseAction')
end

function CpHud.registerEventListeners(vehicleType)	
	SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", CpHud)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", CpHud)
    SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", CpHud)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdate", CpHud)
    SpecializationUtil.registerEventListener(vehicleType, "onEnterVehicle", CpHud)
    SpecializationUtil.registerEventListener(vehicleType, "onLeaveVehicle", CpHud)
    SpecializationUtil.registerEventListener(vehicleType, "onDraw", CpHud)
	SpecializationUtil.registerEventListener(vehicleType, "cpShowWorkWidth", CpHud)
    SpecializationUtil.registerEventListener(vehicleType, "cpShowBaleCollectorOffset", CpHud)
    SpecializationUtil.registerEventListener(vehicleType, "cpUpdateMouseAction", CpHud)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteUpdateStream", CpHud)
    SpecializationUtil.registerEventListener(vehicleType, "onReadUpdateStream", CpHud)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", CpHud)
    SpecializationUtil.registerEventListener(vehicleType, "onReadStream", CpHud)
    SpecializationUtil.registerEventListener(vehicleType, "onStateChange", CpHud)
end

function CpHud.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, 'cpInit', CpHud.cpInit)
    SpecializationUtil.registerFunction(vehicleType, 'getCpStatus', CpHud.getCpStatus)
    SpecializationUtil.registerFunction(vehicleType, 'getIsMouseOverCpHud', CpHud.getIsMouseOverCpHud)
	SpecializationUtil.registerFunction(vehicleType, 'resetCpHud', CpHud.resetCpHud)
	SpecializationUtil.registerFunction(vehicleType, 'closeCpHud', CpHud.closeCpHud)
	SpecializationUtil.registerFunction(vehicleType, 'getCpHud', CpHud.getCpHud)
    SpecializationUtil.registerFunction(vehicleType, 'getCpHudSettings', CpHud.getCpHudSettings)

    SpecializationUtil.registerFunction(vehicleType, 'showCpBunkerSiloWorkWidth', CpHud.showCpBunkerSiloWorkWidth)
    SpecializationUtil.registerFunction(vehicleType, 'showCpCombineUnloaderWorkWidth', CpHud.showCpCombineUnloaderWorkWidth)
    SpecializationUtil.registerFunction(vehicleType, 'showCpCourseWorkWidth', CpHud.showCpCourseWorkWidth)
    SpecializationUtil.registerFunction(vehicleType, "cpGetHudSelectedJobSetting", CpHud.cpGetHudSelectedJobSetting)

    SpecializationUtil.registerFunction(vehicleType, "cpIsHudFieldWorkJobSelected", CpHud.cpIsHudFieldWorkJobSelected)
    SpecializationUtil.registerFunction(vehicleType, "cpIsHudBaleFinderJobSelected", CpHud.cpIsHudBaleFinderJobSelected)
    SpecializationUtil.registerFunction(vehicleType, "cpIsHudBunkerSiloJobSelected", CpHud.cpIsHudBunkerSiloJobSelected)
    SpecializationUtil.registerFunction(vehicleType, "cpIsHudSiloLoaderJobSelected", CpHud.cpIsHudSiloLoaderJobSelected)
    SpecializationUtil.registerFunction(vehicleType, "cpIsHudUnloaderJobSelected", CpHud.cpIsHudUnloaderJobSelected)
    SpecializationUtil.registerFunction(vehicleType, "cpIsHudStreetJobSelected", CpHud.cpIsHudStreetJobSelected)
end

function CpHud.registerOverwrittenFunctions(vehicleType)
   if vehicleType.functions["enterVehicleRaycastClickToSwitch"] ~= nil then 
        SpecializationUtil.registerOverwrittenFunction(vehicleType, "enterVehicleRaycastClickToSwitch", CpHud.enterVehicleRaycastClickToSwitch)
   end
   SpecializationUtil.registerOverwrittenFunction(vehicleType, 'getCpStartText', CpHud.getCpStartText)
end

--- Disables the click to switch action, while the mouse is over the cp hud.
function CpHud:enterVehicleRaycastClickToSwitch(superFunc, x, y)
    local spec = self.spec_cpHud
    if not spec.hud:isMouseOverArea(x, y) then 
        CpUtil.debugVehicle(CpDebug.DBG_HUD, self, 'Entering for cts is allowed.')
        superFunc(self, x, y)
    else 
        CpUtil.debugVehicle(CpDebug.DBG_HUD, self, 'Entering for cts is not allowed.')
    end
end

function CpHud:getIsMouseOverCpHud()
    local spec = self.spec_cpHud
    return spec.hud:getIsOpen() and spec.hud:getIsHovered()
end

function CpHud:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)    
    if self.isClient then
        local spec = self.spec_cpHud
        self:clearActionEventsTable(spec.actionEvents)

        if g_Courseplay.globalSettings.controllerHudSelected:getValue() then 
            return 
        end

        if self.isActiveForInputIgnoreSelectionIgnoreAI then
            --- Toggle mouse cursor action event
            --- Parameters: 
            --- (actionEventsTable, inputAction, target,
            ---  callback, triggerUp, triggerDown, triggerAlways, startActive,
            ---  callbackState, customIconName, ignoreCollisions, reportAnyDeviceCollision)
            if self:getCpSettings().openHudWithMouse:getValue() then
                local _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.CP_TOGGLE_MOUSE, self,
                        CpHud.actionEventMouse, false, true, false, true,nil,nil,true)
                g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)
                g_inputBinding:setActionEventText(actionEventId, spec.openCloseText)
                g_inputBinding:setActionEventTextVisibility(actionEventId, g_Courseplay.globalSettings.showActionEventHelp:getValue())
            end
        end
    end
end

function CpHud:actionEventMouse(isMouseEvent)
    if self ~= g_currentMission.controlledVehicle then 
        ---Player has entered a child vehicle, so don't open the hud.
        return
    end

    --- Disables closing of the hud with the mouse button, while auto drive is in editor mode.
    if isMouseEvent and g_Courseplay.autoDrive and g_Courseplay.autoDrive.isEditorModeEnabled() then 
        return
    end
    local spec = self.spec_cpHud
    local showMouseCursor = not g_inputBinding:getShowMouseCursor()
    if not spec.hud:getIsOpen() then
        showMouseCursor = true
    end
    CpUtil.debugVehicle(CpDebug.DBG_HUD, self, 'show mouse cursor %s', showMouseCursor)
    g_inputBinding:setShowMouseCursor(showMouseCursor)
    ---While mouse cursor is active, disable the camera rotations
    CpGuiUtil.setCameraRotation(self, not showMouseCursor, self.spec_cpHud.savedCameraRotatableInfo)
	if showMouseCursor then
		spec.hud:openClose(true)
		CpHud.isHudActive = true
	end
end

function CpHud:resetCpHud()
    --- Prevents turning the mouse button off, if auto drive editor is enabled.
    if g_Courseplay.autoDrive and g_Courseplay.autoDrive.isEditorModeEnabled() then 
        return
    end
	g_inputBinding:setShowMouseCursor(false)
	CpGuiUtil.setCameraRotation(self, true, self.spec_cpHud.savedCameraRotatableInfo)
    local spec = self.spec_cpHud
--    spec.hud:openClose(false)
end

function CpHud:closeCpHud()
	self:resetCpHud()
	local spec = self.spec_cpHud
    spec.hud:openClose(false)
	CpHud.isHudActive = false
end

function CpHud:getCpHud()
	local spec = self.spec_cpHud
	return spec.hud
end

function CpHud:openClose()
	local spec = self.spec_cpHud
	if spec.hud:getIsOpen() then 
		self:resetCpHud()
		spec.hud:openClose(false)
		CpHud.isHudActive = false
	else 
		CpHud.actionEventMouse(self)
	end
end

------------------------------------------------------------------------------------------------------------------------
--- Event listeners
---------------------------------------------------------------------------------------------------------------------------
function CpHud:onLoad(savegame)
	--- Register the spec: spec_cpHud
	self.spec_cpHud = self["spec_" .. CpHud.SPEC_NAME]
    local spec = self.spec_cpHud
    spec.status = CpStatus(false, self)
	spec.lastShownWorkWidthTimeStamp = g_time
    spec.lastShownBaleCollectorOffsetTimeStamp = g_time
    spec.openCloseText = g_i18n:getText("input_CP_OPEN_CLOSE_HUD")
    spec.hudSettings = {}
    --- Clones the generic settings to create different settings containers for each vehicle. 
    CpSettingsUtil.cloneSettingsTable(spec.hudSettings, CpHud.hudSettings.settings, self, CpHud)
    if savegame == nil or savegame.resetVehicles then return end
    CpSettingsUtil.loadFromXmlFile(spec.hudSettings, savegame.xmlFile, 
                        savegame.key .. CpHud.KEY .. CpHud.SETTINGS_KEY, self)
end

function CpHud:onReadStream(streamId, connection)
    local spec = self.spec_cpHud
    for _, setting in ipairs(spec.hudSettings.settings) do
        setting:readStream(streamId, connection)
    end
end

function CpHud:onWriteStream(streamId, connection)
    local spec = self.spec_cpHud
    for _, setting in ipairs(spec.hudSettings.settings) do
        setting:writeStream(streamId, connection)
    end
end

function CpHud:onWriteUpdateStream(streamId, connection, dirtyMask)
    local spec = self.spec_cpHud
	spec.status:onWriteUpdateStream(streamId, connection, dirtyMask)
end

function CpHud:onReadUpdateStream(streamId, timestamp, connection)
    local spec = self.spec_cpHud
	spec.status:onReadUpdateStream(streamId, timestamp, connection)
end

function CpHud:getCpStatus()
    local spec = self.spec_cpHud
    return spec.status
end

function CpHud:onPostLoad(savegame)
    local spec = self.spec_cpHud
    spec.hud = CpBaseHud(self)
end

function CpHud:saveToXMLFile(xmlFile, baseKey, usedModNames)
   --- Saves the settings.
    local spec = self.spec_cpHud
    CpSettingsUtil.saveToXmlFile(spec.hudSettings.settings, xmlFile, 
        baseKey .. CpHud.SETTINGS_KEY, self, nil)
end

function CpHud:onEnterVehicle(isControlling)
    -- if the mouse cursor is shown when we enter the vehicle, disable camera rotations
    if isControlling and self == g_currentMission.controlledVehicle then
        CpGuiUtil.setCameraRotation(self, not g_inputBinding:getShowMouseCursor(),
                self.spec_cpHud.savedCameraRotatableInfo)
        local spec = self.spec_cpHud
        spec.hud:openClose(CpHud.isHudActive)

        -- if not spec.firstTimeEntered then
        --     --- Attach/Detach only happens after the synchronizing is done.
        --     --- For some reason the detection of the inital attach/detach event
        --     --- is not corresponding to Vehicle:getIsSynchronized() function,
        --     --- so we only do it after the first time entering the vehicle. 
        --     for _, setting in ipairs(spec.hudSettings.settings) do
        --         setting:refresh()
        --         setting:resetToLoadedValue()
        --     end
        -- end
        -- spec.firstTimeEntered = true
    end
end

function CpHud:onLeaveVehicle(wasEntered)
    -- turn off mouse when leaving the vehicle
    if wasEntered then
   	    self:resetCpHud()
    end
end

function CpHud:onStateChange(state, data)
    local spec = self.spec_cpHud
    if state == Vehicle.STATE_CHANGE_ATTACH or state == Vehicle.STATE_CHANGE_DETACH then
        spec.needsRefresh = true
    end
end

--- Enriches the status data for the hud here.
function CpHud:onUpdate(dt)
    local spec = self.spec_cpHud
    local strategy = self:getCpDriveStrategy()
    spec.status:update(dt, self:getIsCpActive(), strategy)
    if spec.needsRefresh then 
        for _, setting in ipairs(spec.hudSettings.settings) do
            setting:refresh()
        end
        spec.needsRefresh = false
    end
end

function CpHud:onDraw()
    if not self:getIsEntered() then 
        return
    end
    local spec = self.spec_cpHud
    spec.hud:draw(spec.status)
	if spec.hud:getIsOpen() then 
		if spec.lastShownWorkWidthTimeStamp + CpHud.workWidthDisplayDelayMs > g_time then 
            if spec.hud:isBunkerSiloLayoutActive() or spec.hud:isSiloLoaderLayoutActive() then 
                CpHud.showCpBunkerSiloWorkWidth(self)
            elseif spec.hud:isCombineUnloaderLayoutActive() then
                CpHud.showCpCombineUnloaderWorkWidth(self)
            else
                CpHud.showCpCourseWorkWidth(self)
            end
		end
        if spec.lastShownBaleCollectorOffsetTimeStamp + CpHud.workWidthDisplayDelayMs > g_time then 
            ImplementUtil.showBaleCollectorOffset(self, self:getCpSettings().baleCollectorOffset:getValue())
        end
	end
end

function CpHud:showCpBunkerSiloWorkWidth()
	WorkWidthUtil.showWorkWidth(self, self:getCpSettings().bunkerSiloWorkWidth:getValue(), 0, 0)
end

function CpHud:showCpCombineUnloaderWorkWidth()
	WorkWidthUtil.showWorkWidth(self,
										self:getCourseGeneratorSettings().workWidth:getValue(),
											self:getCpSettings().combineOffsetX:getValue(),
											self:getCpSettings().combineOffsetZ:getValue())
end

function CpHud:showCpCourseWorkWidth()
	WorkWidthUtil.showWorkWidth(self,
										self:getCourseGeneratorSettings().workWidth:getValue(),
											self:getCpSettings().toolOffsetX:getValue(),
											0)
end

function CpHud:cpShowWorkWidth()
	local spec = self.spec_cpHud
	if spec then
		spec.lastShownWorkWidthTimeStamp = g_time
	end
end

function CpHud:cpShowBaleCollectorOffset()
	local spec = self.spec_cpHud
	if spec then
		spec.lastShownBaleCollectorOffsetTimeStamp = g_time
	end
end

function CpHud:cpUpdateMouseAction()
    self:requestActionEventUpdate()
end

function CpHud:cpInit()
    self.spec_cpHud.hud = CpBaseHud(self)
end

--------------------------------------
--- Hud Settings
--------------------------------------

function CpHud:raiseDirtyFlag(setting)
    HudSettingsEvent.sendEvent(self, setting)
end 

function CpHud:getCpHudSettings()
    local spec = self.spec_cpHud
    return spec.hudSettings
end

function CpHud:isFieldWorkModeDisabled()
    return not self:getCanStartCpFieldWork()
end

function CpHud:isBaleFinderModeDisabled()
    return not self:getCanStartCpBaleFinder()
end

function CpHud:isSiloLoadingModeDisabled()
    return not self:getCanStartCpSiloLoaderWorker()
end

function CpHud:isBunkerSiloModeDisabled()
    return not self:getCanStartCpBunkerSiloWorker()
end

function CpHud:isUnloaderModeDisabled()
    return not self:getCanStartCpCombineUnloader()
end

function CpHud:isStreetModeDisabled()
    return false
end

function CpHud:cpIsHudFieldWorkJobSelected()
    local spec = self.spec_cpHud
    local value = spec.hudSettings.selectedJob:getValue()
    return value == CpHud.hudSettings.FIELDWORK_SELECTED
end

function CpHud:cpIsHudBaleFinderJobSelected()
    local spec = self.spec_cpHud
    local value = spec.hudSettings.selectedJob:getValue()
    return value == CpHud.hudSettings.BALE_FINDER_SELECTED
end

function CpHud:cpIsHudBunkerSiloJobSelected()
    local spec = self.spec_cpHud
    local value = spec.hudSettings.selectedJob:getValue()
    return value == CpHud.hudSettings.BUNKER_SILO_SELECTED
end

function CpHud:cpIsHudSiloLoaderJobSelected()
    local spec = self.spec_cpHud
    local value = spec.hudSettings.selectedJob:getValue()
    return value == CpHud.hudSettings.SILO_LOADER_SELECTED
end

function CpHud:cpIsHudUnloaderJobSelected()
    local spec = self.spec_cpHud
    local value = spec.hudSettings.selectedJob:getValue()
    return value == CpHud.hudSettings.COMBINE_UNLOADER_SELECTED
end

function CpHud:cpIsHudStreetJobSelected()
    local spec = self.spec_cpHud
    local value = spec.hudSettings.selectedJob:getValue()
    return value == CpHud.hudSettings.STREET_DRIVER_SELECTED
end

function CpHud:cpGetHudSelectedJobSetting()
    local spec = self.spec_cpHud
    return spec.hudSettings.selectedJob
end

function CpHud:getCpStartText()
    local spec = self.spec_cpHud
    return spec.hudSettings.selectedJob:getString() or "---"
end