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
end
function CpCourseGeneratorSettings.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, 'getCourseGeneratorSetting', CpCourseGeneratorSettings.getSetting)
    SpecializationUtil.registerFunction(vehicleType, 'getCourseGeneratorSettingValue', CpCourseGeneratorSettings.getSettingValue)
    SpecializationUtil.registerFunction(vehicleType, 'setCourseGeneratorSettingValue', CpCourseGeneratorSettings.setSettingValue)
    SpecializationUtil.registerFunction(vehicleType, 'setCourseGeneratorSettingFloatValue', CpCourseGeneratorSettings.setSettingFloatValue)
    SpecializationUtil.registerFunction(vehicleType, 'getCourseGeneratorSettings', CpCourseGeneratorSettings.getSettings)
end

--- Gets a single setting by it's name.
---@param name string
---@return AIParameterSettingList
function CpCourseGeneratorSettings:getSetting(name)
    local spec = self.spec_cpCourseGeneratorSettings
    return spec.settingsByName[name]
end

--- Gets a single setting value by it's name.
---@param name string
---@return any
function CpCourseGeneratorSettings:getSettingValue(name)
    local spec = self.spec_cpCourseGeneratorSettings
    return spec.settingsByName[name]:getValue()
end

--- Sets a single setting value by it's name.
---@param name string
---@param value any
function CpCourseGeneratorSettings:setSettingValue(name,value)
    local spec = self.spec_cpCourseGeneratorSettings
    return spec.settingsByName[name]:setValue(value)
end

--- Sets a single setting float value by it's name.
---@param name string
---@param value any
function CpCourseGeneratorSettings:setSettingFloatValue(name,value)
   
    local spec = self.spec_cpCourseGeneratorSettings
    return spec.settingsByName[name]:setFloatValue(value)
end

--- Gets all settings.
---@return table
function CpCourseGeneratorSettings:getSettings()
    local spec = self.spec_cpCourseGeneratorSettings
    return spec.settings
end

function CpCourseGeneratorSettings:onLoad(savegame)
	--- Register the spec: spec_cpCourseGeneratorSettings
    local specName = CpCourseGeneratorSettings.MOD_NAME .. ".cpCourseGeneratorSettings"
    self.spec_cpCourseGeneratorSettings = self["spec_" .. specName]
    local spec = self.spec_cpCourseGeneratorSettings

    --- Clones the generic settings to create different settings containers for each vehicle. 
    spec.settings,spec.settingsByName = CpSettingsUtil.cloneSettingsTable(CpCourseGeneratorSettings.settings,self,CpCourseGeneratorSettings)

    CpCourseGeneratorSettings.loadSettings(self,savegame)
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
        local setting = spec.settingsByName[name]
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