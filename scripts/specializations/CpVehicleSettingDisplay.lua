--- Cp ai driver spec

---@class CpVehicleSettingDisplay
CpVehicleSettingDisplay = {}

CpVehicleSettingDisplay.MOD_NAME = g_currentModName
CpVehicleSettingDisplay.NAME = ".cpVehicleSettingDisplay"
CpVehicleSettingDisplay.SPEC_NAME = CpVehicleSettingDisplay.MOD_NAME .. CpVehicleSettingDisplay.NAME
--CpVehicleSettingDisplay.KEY = "."..CpVehicleSettingDisplay.MOD_NAME..".cpVehicleSettingDisplay."
CpVehicleSettingDisplay.XML_KEY = "Settings.Setting"
CpVehicleSettingDisplay.XML_KEY_TITLE = "Settings#title"

CpVehicleSettingDisplay.SETTING_TYPES = {
	vehicleSettings = CpVehicleSettings,
	courseGeneratorSettings = CpCourseGeneratorSettings
}

function CpVehicleSettingDisplay.initSpecialization()
	CpVehicleSettingDisplay.xmlSchema = XMLSchema.new("CpVehicleSettingDisplaySchema")
	local schema = CpVehicleSettingDisplay.xmlSchema
	schema:register(XMLValueType.STRING,CpVehicleSettingDisplay.XML_KEY_TITLE,"Title of the display.")
	schema:register(XMLValueType.STRING,CpVehicleSettingDisplay.XML_KEY.."(?)#name","Setting name to bind.")
	schema:register(XMLValueType.STRING,CpVehicleSettingDisplay.XML_KEY.."(?)#type","Setting parent.")
end

function CpVehicleSettingDisplay.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(AIFieldWorker, specializations) 
end

function CpVehicleSettingDisplay.register(typeManager,typeName,specializations)
	if CpVehicleSettingDisplay.prerequisitesPresent(specializations) then
		typeManager:addSpecialization(typeName, CpVehicleSettingDisplay.SPEC_NAME)
	end
end

function CpVehicleSettingDisplay.loadFromXMLFile(filePath)
	local xmlFile = XMLFile.load("CpVehicleSettingDisplayXml",filePath,CpVehicleSettingDisplay.xmlSchema)
	if xmlFile then 
		CpVehicleSettingDisplay.title = xmlFile:getValue(CpVehicleSettingDisplay.XML_KEY_TITLE)
		CpVehicleSettingDisplay.settingsData = {}
		CpVehicleSettingDisplay.prefabSettingsData = {}
		xmlFile:iterate(CpVehicleSettingDisplay.XML_KEY, function (ix, key)
			local settingName = xmlFile:getValue(key .. "#name")
			local settingType = xmlFile:getValue(key .. "#type")
			local settingData = {
				settingName = settingName,
				settingType = settingType
			}
			table.insert(CpVehicleSettingDisplay.settingsData,settingData)

			local prefabSetting = CpVehicleSettingDisplay.SETTING_TYPES[settingType][settingName]

			table.insert(CpVehicleSettingDisplay.prefabSettingsData,prefabSetting)
        end)
        xmlFile:delete()
	end
end

function CpVehicleSettingDisplay.registerEventListeners(vehicleType)	
	SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", CpVehicleSettingDisplay)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", CpVehicleSettingDisplay)
	SpecializationUtil.registerEventListener(vehicleType, "onLoadFinished", CpVehicleSettingDisplay)
--	SpecializationUtil.registerEventListener(vehicleType, "onDraw", CpVehicleSettingDisplay)
--    SpecializationUtil.registerEventListener(vehicleType, "onEnterVehicle", CpVehicleSettingDisplay)
--    SpecializationUtil.registerEventListener(vehicleType, "onLeaveVehicle", CpVehicleSettingDisplay)

end

function CpVehicleSettingDisplay.registerFunctions(vehicleType)
 
end

function CpVehicleSettingDisplay.registerOverwrittenFunctions(vehicleType)
   
end
------------------------------------------------------------------------------------------------------------------------
--- Event listeners
---------------------------------------------------------------------------------------------------------------------------
function CpVehicleSettingDisplay:onLoad(savegame)
	--- Register the spec: spec_CpVehicleSettingDisplay
    self.spec_cpVehicleSettingDisplay = self["spec_" .. CpVehicleSettingDisplay.SPEC_NAME]
    local spec = self.spec_cpVehicleSettingDisplay
	spec.text = g_i18n:getText("input_CP_OPEN_CLOSE_VEHICLE_SETTING_DISPLAY")
end

function CpVehicleSettingDisplay:onLoadFinished()
	if not CpVehicleSettingDisplay.initialized then 
		local filePath = Utils.getFilename('config/VehicleSettingDisplaySetup.xml', Courseplay.BASE_DIRECTORY)
		CpVehicleSettingDisplay.loadFromXMLFile(filePath)
		CpVehicleSettingDisplay.dialog = VehicleSettingDisplayDialog.new(CpVehicleSettingDisplay.prefabSettingsData)
		g_gui:loadGui(Utils.getFilename("config/gui/BlankScreenElement.xml",Courseplay.BASE_DIRECTORY), "CpVehicleSettingDisplayDialog", CpVehicleSettingDisplay.dialog)
		CpVehicleSettingDisplay.initialized = true
	end

	CpVehicleSettingDisplay.linkSettings(self)
end

function CpVehicleSettingDisplay:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
	if self.isClient then
		local spec = self.spec_cpVehicleSettingDisplay

		self:clearActionEventsTable(spec.actionEvents)

		if isActiveForInputIgnoreSelection then
			local _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.CP_OPEN_CLOSE_VEHICLE_SETTING_DISPLAY, self, CpVehicleSettingDisplay.actionEventOpenCloseDisplay, false, true, false, true, nil)
            g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_HIGH)
            g_inputBinding:setActionEventText(actionEventId, spec.text)
		end
	end
end

function CpVehicleSettingDisplay:onDraw()
	local spec = self.spec_cpVehicleSettingDisplay
	WorkWidthUtil.showWorkWidth(self,spec.workWidth:getValue(),spec.toolOffsetX:getValue(),spec.toolOffsetZ:getValue())
end


function CpVehicleSettingDisplay:linkSettings()
	local spec = self.spec_cpVehicleSettingDisplay
	spec.settings = {}
	for ix,data in ipairs(CpVehicleSettingDisplay.settingsData) do 
		local func = CpVehicleSettingDisplay.SETTING_TYPES[data.settingType].getSettings
		local settings = func(self)
		local setting = settings[data.settingName]
		table.insert(spec.settings,setting)
		spec[data.settingName] = setting
	end
end

function CpVehicleSettingDisplay:actionEventOpenCloseDisplay()
	local spec = self.spec_cpVehicleSettingDisplay
	CpVehicleSettingDisplay.dialog:setData(self,spec.settings) 
	g_gui:showGui("CpVehicleSettingDisplayDialog")
end
