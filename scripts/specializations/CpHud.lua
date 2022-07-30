--- Cp ai driver spec

---@class CpHud
CpHud = {}

CpHud.MOD_NAME = g_currentModName

CpHud.NAME = ".cpHud"
CpHud.SPEC_NAME = CpHud.MOD_NAME .. CpHud.NAME
CpHud.KEY = "."..CpHud.MOD_NAME..CpHud.NAME .. "."
CpHud.isHudActive = false
CpHud.workWidthDisplayDelayMs = 5000 -- 5 seconds

function CpHud.initSpecialization()
    local schema = Vehicle.xmlSchemaSavegame
end

function CpHud.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(CpAIFieldWorker, specializations) 
end

function CpHud.register(typeManager,typeName,specializations)
	if CpHud.prerequisitesPresent(specializations) then
		typeManager:addSpecialization(typeName, CpHud.SPEC_NAME)
	end
end

function CpHud.registerEvents(vehicleType)
    SpecializationUtil.registerEvent(vehicleType, 'cpShowWorkWidth')
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
    SpecializationUtil.registerEventListener(vehicleType, "cpUpdateMouseAction", CpHud)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteUpdateStream", CpHud)
    SpecializationUtil.registerEventListener(vehicleType, "onReadUpdateStream", CpHud)
end

function CpHud.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, 'cpInit', CpHud.cpInit)
    SpecializationUtil.registerFunction(vehicleType, 'getCpStatus', CpHud.getCpStatus)
    SpecializationUtil.registerFunction(vehicleType, 'getIsMouseOverCpHud', CpHud.getIsMouseOverCpHud)
	SpecializationUtil.registerFunction(vehicleType, 'resetCpHud', CpHud.resetCpHud)
	SpecializationUtil.registerFunction(vehicleType, 'closeCpHud', CpHud.closeCpHud)
	SpecializationUtil.registerFunction(vehicleType, 'getCpHud', CpHud.getCpHud)
end

function CpHud.registerOverwrittenFunctions(vehicleType)
   if vehicleType.functions["enterVehicleRaycastClickToSwitch"] ~= nil then 
        SpecializationUtil.registerOverwrittenFunction(vehicleType, "enterVehicleRaycastClickToSwitch", CpHud.enterVehicleRaycastClickToSwitch)
   end
  
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
    spec.openCloseText = g_i18n:getText("input_CP_OPEN_CLOSE_HUD")
    
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
   
end

function CpHud:onEnterVehicle(isControlling)
    -- if the mouse cursor is shown when we enter the vehicle, disable camera rotations
    if isControlling then
        CpGuiUtil.setCameraRotation(self, not g_inputBinding:getShowMouseCursor(),
                self.spec_cpHud.savedCameraRotatableInfo)
        local spec = self.spec_cpHud
        spec.hud:openClose(CpHud.isHudActive)
    end
end

function CpHud:onLeaveVehicle(wasEntered)
    -- turn off mouse when leaving the vehicle
    if wasEntered then
   	    self:resetCpHud()
    end
end

--- Enriches the status data for the hud here.
function CpHud:onUpdate(dt)
    local spec = self.spec_cpHud
    local strategy
    if self:getIsCpActive() then 
        strategy = self:getCpDriveStrategy()
        if strategy then
            strategy:updateCpStatus(spec.status, dt)
        end
        spec.status:setActive(true)
    else 
        spec.status:reset()
    end
end

function CpHud:onDraw()
    local spec = self.spec_cpHud
    spec.hud:draw(spec.status)
	if spec.hud:getIsOpen() then 
		if spec.lastShownWorkWidthTimeStamp + CpHud.workWidthDisplayDelayMs > g_time then 
			WorkWidthUtil.showWorkWidth(self,
										self:getCourseGeneratorSettings().workWidth:getValue(),
											self:getCpSettings().toolOffsetX:getValue(),
											0)
		end
	end
end

function CpHud:cpShowWorkWidth()
	local spec = self.spec_cpHud
	if spec then
		spec.lastShownWorkWidthTimeStamp = g_time
	end
end

function CpHud:cpUpdateMouseAction()
    self:requestActionEventUpdate()
end

function CpHud:cpInit()
    self.spec_cpHud.hud = CpBaseHud(self)
end
