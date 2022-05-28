--- This specialization is used for visual changing of settings values in a vehicle.

---@class CpGamePadHud
CpGamePadHud = {}

CpGamePadHud.MOD_NAME = g_currentModName
CpGamePadHud.NAME = ".cpGamePadHud"
CpGamePadHud.SPEC_NAME = CpGamePadHud.MOD_NAME .. CpGamePadHud.NAME
CpGamePadHud.XML_KEY = "Settings.Setting"
CpGamePadHud.XML_KEY_TITLE = "Settings#title"
CpGamePadHud.GUI_NAME = "CpGamePadHudDialog"

CpGamePadHud.SETTING_TYPES = {
	vehicleSettings = CpVehicleSettings,
	courseGeneratorSettings = CpCourseGeneratorSettings,
	jobParameters = CpJobParameters,
	baleFinderJobParameters = CpBaleFinderJobParameters,
	globalSettings = CpGlobalSettings
}

function CpGamePadHud.initSpecialization()
	CpGamePadHud.xmlSchema = XMLSchema.new("CpGamePadHudSchema")
	local schema = CpGamePadHud.xmlSchema
	schema:register(XMLValueType.STRING,CpGamePadHud.XML_KEY_TITLE,"Title of the display.")
	schema:register(XMLValueType.STRING,CpGamePadHud.XML_KEY.."(?)#name","Setting name to bind.")
	schema:register(XMLValueType.STRING,CpGamePadHud.XML_KEY.."(?)#type","Setting parent.")
end

function CpGamePadHud.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(AIFieldWorker, specializations) 
end

function CpGamePadHud.register(typeManager,typeName,specializations)
	if CpGamePadHud.prerequisitesPresent(specializations) then
		typeManager:addSpecialization(typeName, CpGamePadHud.SPEC_NAME)
	end
end

--- Creates gui elements for the mini gui.
function CpGamePadHud.loadFromXMLFile(filePath)
	local xmlFile = XMLFile.load("CpGamePadHudXml",filePath,CpGamePadHud.xmlSchema)
	if xmlFile then 
		CpGamePadHud.title = xmlFile:getValue(CpGamePadHud.XML_KEY_TITLE)
		CpGamePadHud.settingsData = {}
		CpGamePadHud.prefabSettingsData = {}
		xmlFile:iterate(CpGamePadHud.XML_KEY, function (ix, key)
			local settingName = xmlFile:getValue(key .. "#name")
			local settingType = xmlFile:getValue(key .. "#type")
			local settingData = {
				settingName = settingName,
				settingType = settingType
			}
			table.insert(CpGamePadHud.settingsData,settingData)

			local prefabSetting = CpGamePadHud.SETTING_TYPES[settingType][settingName]

			table.insert(CpGamePadHud.prefabSettingsData,prefabSetting)
        end)
        xmlFile:delete()
	end
	--- Enables a few background hud elements, while the vehicle setting display is visible.
	local function getIsOverlayGuiVisible(gui,superFunc)
		return gui.currentGuiName == CpGamePadHud.GUI_NAME or superFunc(gui) 
	end
	Gui.getIsOverlayGuiVisible = Utils.overwrittenFunction(Gui.getIsOverlayGuiVisible,getIsOverlayGuiVisible)

end

function CpGamePadHud.registerEventListeners(vehicleType)	
	SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", CpGamePadHud)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", CpGamePadHud)
	SpecializationUtil.registerEventListener(vehicleType, "onLoadFinished", CpGamePadHud)
--    SpecializationUtil.registerEventListener(vehicleType, "onEnterVehicle", CpGamePadHud)
--    SpecializationUtil.registerEventListener(vehicleType, "onLeaveVehicle", CpGamePadHud)

end

function CpGamePadHud.registerFunctions(vehicleType)
 
end

function CpGamePadHud.registerOverwrittenFunctions(vehicleType)
   
end
------------------------------------------------------------------------------------------------------------------------
--- Event listeners
---------------------------------------------------------------------------------------------------------------------------
function CpGamePadHud:onLoad(savegame)
	--- Register the spec: spec_cpGamePadHud
    self.spec_cpGamePadHud = self["spec_" .. CpGamePadHud.SPEC_NAME]
    local spec = self.spec_cpGamePadHud
	spec.text = g_i18n:getText("input_CP_OPEN_CLOSE_VEHICLE_SETTING_DISPLAY")
	spec.hudText = g_i18n:getText("input_CP_OPEN_CLOSE_HUD")
end

function CpGamePadHud:onLoadFinished()
	if not CpGamePadHud.initialized then 
		local filePath = Utils.getFilename('config/GamePadHud.xml', Courseplay.BASE_DIRECTORY)
		CpGamePadHud.loadFromXMLFile(filePath)
		--- Setup of the mini gui.
		CpGamePadHud.screen = CpGamePadHudScreen.new(CpGamePadHud.prefabSettingsData)
		g_gui:loadGui(Utils.getFilename("config/gui/ControllerGuiScreen.xml",Courseplay.BASE_DIRECTORY), CpGamePadHud.GUI_NAME, CpGamePadHud.screen)
		CpGamePadHud.initialized = true
	end
	CpGamePadHud.linkSettings(self)
end

function CpGamePadHud:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
	if self.isClient then
		local spec = self.spec_cpGamePadHud
		self:clearActionEventsTable(spec.actionEvents)
		--- Key bind gets switch between opening hud or controller friendly gui.
		if not g_Courseplay.globalSettings.controllerHudSelected:getValue() then 
			if self.isActiveForInputIgnoreSelectionIgnoreAI then
				local _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.CP_OPEN_CLOSE_VEHICLE_SETTING_DISPLAY, self, CpHud.openClose, false, true, false, true, nil)
				g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_HIGH)
				g_inputBinding:setActionEventText(actionEventId, spec.hudText)
				g_inputBinding:setActionEventTextVisibility(actionEventId, g_Courseplay.globalSettings.showActionEventHelp:getValue())
			end
		else
			if self.isActiveForInputIgnoreSelectionIgnoreAI then
				local _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.CP_OPEN_CLOSE_VEHICLE_SETTING_DISPLAY, self, CpGamePadHud.actionEventOpenCloseDisplay, false, true, false, true, nil)
				g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_HIGH)
				g_inputBinding:setActionEventText(actionEventId, spec.text)
				g_inputBinding:setActionEventTextVisibility(actionEventId, g_Courseplay.globalSettings.showActionEventHelp:getValue())
			end
		end
	end
end

--- Gets called by the active mini gui, as vehicle:onDraw() is otherwise not displayed.
function CpGamePadHud:onDraw()
	local spec = self.spec_cpGamePadHud
	WorkWidthUtil.showWorkWidth(self,spec.workWidth:getValue(),spec.toolOffsetX:getValue(),0)
end


function CpGamePadHud:linkSettings()
	local spec = self.spec_cpGamePadHud
	spec.settings = {}
	for ix,data in ipairs(CpGamePadHud.settingsData) do 
		local func = CpGamePadHud.SETTING_TYPES[data.settingType].getSettings
		local settings = func(self)
		local setting = settings[data.settingName]
		table.insert(spec.settings,setting)
		spec[data.settingName] = setting
	end
end

function CpGamePadHud:actionEventOpenCloseDisplay()
	local spec = self.spec_cpGamePadHud
	CpGamePadHud.screen:setData(self,spec.settings) 
	g_gui:showGui(CpGamePadHud.GUI_NAME)
end
