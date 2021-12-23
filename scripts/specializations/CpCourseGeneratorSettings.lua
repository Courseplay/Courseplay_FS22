--[[
    CourseGenerator settings
]]--

---@class CpCourseGeneratorSettings
CpCourseGeneratorSettings = {}

CpCourseGeneratorSettings.MOD_NAME = g_currentModName
CpCourseGeneratorSettings.KEY = "."..CpCourseGeneratorSettings.MOD_NAME..".cpCourseGeneratorSettings"
function CpCourseGeneratorSettings.initSpecialization()
	local schema = Vehicle.xmlSchemaSavegame
    schema:register(XMLValueType.INT,"vehicles.vehicle(?)"..CpCourseGeneratorSettings.KEY.."(?)#value","Setting value")
    schema:register(XMLValueType.STRING,"vehicles.vehicle(?)"..CpCourseGeneratorSettings.KEY.."(?)#name","Setting name")
end


function CpCourseGeneratorSettings.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(AIFieldWorker, specializations) 
end

function CpCourseGeneratorSettings.registerEventListeners(vehicleType)	
--	SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", CpCourseGeneratorSettings)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", CpCourseGeneratorSettings)
    SpecializationUtil.registerEventListener(vehicleType, "onPreDetach", CpCourseGeneratorSettings)
    SpecializationUtil.registerEventListener(vehicleType, "onPostAttach", CpCourseGeneratorSettings)
end
function CpCourseGeneratorSettings.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, 'getCourseGeneratorSettings', CpCourseGeneratorSettings.getSettings)
    SpecializationUtil.registerFunction(vehicleType, 'getCourseGeneratorSettingsTable', CpCourseGeneratorSettings.getSettingsTable)
end

--- Gets all settings.
---@return table
function CpCourseGeneratorSettings:getSettings()
    local spec = self.spec_cpCourseGeneratorSettings
    return spec
end

--- Gets all settings.
---@return table
function CpCourseGeneratorSettings:getSettingsTable()
    local spec = self.spec_cpCourseGeneratorSettings
    return spec.settings
end

function CpCourseGeneratorSettings:onLoad(savegame)
	--- Register the spec: spec_cpCourseGeneratorSettings
    local specName = CpCourseGeneratorSettings.MOD_NAME .. ".cpCourseGeneratorSettings"
    self.spec_cpCourseGeneratorSettings = self["spec_" .. specName]
    local spec = self.spec_cpCourseGeneratorSettings

    --- Clones the generic settings to create different settings containers for each vehicle. 
    CpSettingsUtil.cloneSettingsTable(spec,CpCourseGeneratorSettings.settings,self,CpCourseGeneratorSettings)

    CpCourseGeneratorSettings.loadSettings(self,savegame)
end

function CpCourseGeneratorSettings:onPostAttach()
    local spec = self.spec_cpCourseGeneratorSettings
    spec.workWidth:setFloatValue(WorkWidthUtil.getAutomaticWorkWidth(self))
end

function CpCourseGeneratorSettings:onPreDetach()
    local spec = self.spec_cpCourseGeneratorSettings
    spec.workWidth:setFloatValue(WorkWidthUtil.getAutomaticWorkWidth(self))
end

--- Loads the generic settings setup from an xmlFile.
function CpCourseGeneratorSettings.loadSettingsSetup()
    local filePath = Utils.getFilename("config/CourseGeneratorSettingsSetup.xml", g_Courseplay.BASE_DIRECTORY)
    CpSettingsUtil.loadSettingsFromSetup(CpCourseGeneratorSettings,filePath)
end
CpCourseGeneratorSettings.loadSettingsSetup()

function CpCourseGeneratorSettings.getSettingSetup()
    return CpCourseGeneratorSettings.settingsBySubTitle,CpCourseGeneratorSettings.pageTitle
end

function CpCourseGeneratorSettings:loadSettings(savegame)
    if savegame == nil or savegame.resetVehicles then return end
    local spec = self.spec_cpCourseGeneratorSettings
	savegame.xmlFile:iterate(savegame.key..CpCourseGeneratorSettings.KEY, function (ix, key)
		local name = savegame.xmlFile:getValue(key.."#name")
        local setting = spec[name]
        if setting then
            setting:loadFromXMLFile(savegame.xmlFile, key)
            CpUtil.debugVehicle(CpUtil.DBG_HUD,self,"Loaded setting: %s, value:%s, key: %s",setting:getName(),setting:getValue(),key)
        end
    end)
end

function CpCourseGeneratorSettings:saveToXMLFile(xmlFile, key, usedModNames)
    local spec = self.spec_cpCourseGeneratorSettings
    for i,setting in ipairs(spec.settings) do 
        local key = string.format("%s(%d)",key,i-1)
        setting:saveToXMLFile(xmlFile, key, usedModNames)
        xmlFile:setValue(key.."#name",setting:getName())
        CpUtil.debugVehicle(CpUtil.DBG_HUD,self,"Saved setting: %s, value:%s, key: %s",setting:getName(),setting:getValue(),key)
    end
end

--- Callback raised by a setting and executed as an vehicle event.
function CpCourseGeneratorSettings:raiseCallback(callbackStr)
    SpecializationUtil.raiseEvent(self,callbackStr)
end