--[[
    Vehicle specific settings
]]--

---@class CpVehicleSettings
CpVehicleSettings = {}

CpVehicleSettings.MOD_NAME = g_currentModName
CpVehicleSettings.KEY = "."..CpVehicleSettings.MOD_NAME..".cpVehicleSettings"
function CpVehicleSettings.initSpecialization()
	local schema = Vehicle.xmlSchemaSavegame
    schema:register(XMLValueType.INT,"vehicles.vehicle(?)"..CpVehicleSettings.KEY.."(?)#value","Setting value")
    schema:register(XMLValueType.STRING,"vehicles.vehicle(?)"..CpVehicleSettings.KEY.."(?)#name","Setting name")
end


function CpVehicleSettings.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(AIFieldWorker, specializations) 
end

function CpVehicleSettings.registerEventListeners(vehicleType)	
--	SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", CpVehicleSettings)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", CpVehicleSettings)
    SpecializationUtil.registerEventListener(vehicleType, "onLoadFinished", CpVehicleSettings)
    SpecializationUtil.registerEventListener(vehicleType, "onPreDetachImplement", CpVehicleSettings)
    SpecializationUtil.registerEventListener(vehicleType, "onPostAttachImplement", CpVehicleSettings)
    SpecializationUtil.registerEventListener(vehicleType, "onCpUnitChanged", CpVehicleSettings)
    SpecializationUtil.registerEventListener(vehicleType, "onReadStream", CpVehicleSettings)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", CpVehicleSettings)
end

function CpVehicleSettings.registerFunctions(vehicleType)

    SpecializationUtil.registerFunction(vehicleType, 'getCpSettingsTable', CpVehicleSettings.getSettingsTable)
    SpecializationUtil.registerFunction(vehicleType, 'getCpSettings', CpVehicleSettings.getSettings)
end

--- Gets all settings.
---@return table
function CpVehicleSettings:getSettings()
    local spec = self.spec_cpVehicleSettings
    return spec
end

function CpVehicleSettings:getSettingsTable()
    local spec = self.spec_cpVehicleSettings
    return spec.settings
end

function CpVehicleSettings:onLoad(savegame)
	--- Register the spec: spec_CpVehicleSettings
    local specName = CpVehicleSettings.MOD_NAME .. ".cpVehicleSettings"
    self.spec_cpVehicleSettings = self["spec_" .. specName]
    local spec = self.spec_cpVehicleSettings

    --- Clones the generic settings to create different settings containers for each vehicle. 
    CpSettingsUtil.cloneSettingsTable(spec,CpVehicleSettings.settings,self,CpVehicleSettings)
    
    CpVehicleSettings.loadSettings(self,savegame)
    
end

function CpVehicleSettings:onLoadFinished()
    local spec = self.spec_cpVehicleSettings
    spec.wasLoaded = nil
end

--- TODO: These are only applied on a implement an not on a single vehicle.
--- This means self driving vehicle are not getting these vehicle configuration values.
function CpVehicleSettings:onPostAttachImplement(object)
    --- Only apply these values, if were are not loading from a savegame.
    local spec = self.spec_cpVehicleSettings
    if spec.wasLoaded then 
        return
    end
    CpVehicleSettings.setFromVehicleConfiguration(self, object, spec.raiseImplementLate, 'raiseLate')
    CpVehicleSettings.setFromVehicleConfiguration(self, object, spec.lowerImplementEarly, 'lowerEarly')
    CpVehicleSettings.setFromVehicleConfiguration(self, object, spec.toolOffsetX, 'toolOffsetX')
    CpVehicleSettings.validateSettings(self)
end

function CpVehicleSettings:onPreDetachImplement(implement)
    --- Only apply these values, if were are not loading from a savegame.
    local spec = self.spec_cpVehicleSettings
    if spec.wasLoaded then 
        return
    end
    CpVehicleSettings.resetToDefault(self, implement.object, spec.raiseImplementLate, 'raiseLate', false)
    CpVehicleSettings.resetToDefault(self, implement.object, spec.lowerImplementEarly, 'lowerEarly', false)
    CpVehicleSettings.resetToDefault(self, implement.object, spec.toolOffsetX, 'toolOffsetX', 0)
    CpVehicleSettings.validateSettings(self)
end

function CpVehicleSettings:onReadStream(streamId)
    local spec = self.spec_cpVehicleSettings
    for i,setting in ipairs(spec.settings) do 
        setting:readStream(streamId)
    end
end

function CpVehicleSettings:onWriteStream(streamId)
    local spec = self.spec_cpVehicleSettings
    for i,setting in ipairs(spec.settings) do 
        setting:writeStream(streamId)
    end
end

function CpVehicleSettings.loadSettingsSetup()
    local filePath = Utils.getFilename("config/VehicleSettingsSetup.xml", g_Courseplay.BASE_DIRECTORY)
    CpSettingsUtil.loadSettingsFromSetup(CpVehicleSettings,filePath)
end
CpVehicleSettings.loadSettingsSetup()

function CpVehicleSettings.getSettingSetup()
    return CpVehicleSettings.settingsBySubTitle,CpVehicleSettings.pageTitle
end

function CpVehicleSettings:loadSettings(savegame)
    if savegame == nil or savegame.resetVehicles then return end
    local spec = self.spec_cpVehicleSettings
	savegame.xmlFile:iterate(savegame.key..CpVehicleSettings.KEY, function (ix, key)
        local name = savegame.xmlFile:getValue(key.."#name")
        local setting = spec[name]
        if setting then
            setting:loadFromXMLFile(savegame.xmlFile, key)
            CpUtil.debugVehicle(CpUtil.DBG_HUD,self,"Loaded setting: %s, value:%s, key: %s",setting:getName(),setting:getValue(),key)
        end
        spec.wasLoaded = true
	end)
end

function CpVehicleSettings:saveToXMLFile(xmlFile, key, usedModNames)
    local spec = self.spec_cpVehicleSettings
    for i,setting in ipairs(spec.settings) do 
        local key = string.format("%s(%d)",key,i-1)
        setting:saveToXMLFile(xmlFile, key, usedModNames)
        xmlFile:setValue(key.."#name",setting:getName())
        CpUtil.debugVehicle(CpUtil.DBG_HUD,self,"Saved setting: %s, value:%s, key: %s",setting:getName(),setting:getValue(),key)
    end
end

--- Callback raised by a setting and executed as an vehicle event.
---@param callbackStr string event to be raised
---@param setting AIParameterSettingList setting that raised the callback.
function CpVehicleSettings:raiseCallback(callbackStr, setting, ...)
    SpecializationUtil.raiseEvent(self, callbackStr, setting, ...)
end

function CpVehicleSettings:raiseDirtyFlag(setting)
    VehicleSettingsEvent.sendEvent(self,setting)
end 

function CpVehicleSettings:validateSettings()
    local spec = self.spec_cpVehicleSettings
    for _, setting in ipairs(spec.settings) do
        setting:refresh()
    end
end

function CpVehicleSettings:onCpUnitChanged()
    local spec = self.spec_cpVehicleSettings
    for _, setting in ipairs(spec.settings) do
        setting:validateTexts()
    end
end

-- TODO: these may also be implemented as part of the AIParameterSettingList class, but as long as this is the
-- only place we need them it is better here
--- Check if there is a vehicle specific value configured for this setting. If yes, apply it.
---@param object table vehicle or implement object
---@param setting AIParameterSettingList setting
---@param vehicleConfigurationName string name of the setting in the vehicle configuration XML
function CpVehicleSettings:setFromVehicleConfiguration(object, setting, vehicleConfigurationName)
    local value = g_vehicleConfigurations:get(object, vehicleConfigurationName)
    if value then
        CpUtil.debugVehicle(CpDebug.DBG_IMPLEMENTS, self, '%s: setting configured %s to %s',
                CpUtil.getName(object), vehicleConfigurationName, tostring(value))
        if type(value) == 'number' then
            setting:setFloatValue(value)
        else
            setting:setValue(value)
        end
    end
end

--- Reset a setting to a default value, if there is a vehicle specific configuration exists for it.
--- This is to undo (sort of) what setFromVehicleConfiguration() does
---@param object table vehicle or implement object
---@param setting AIParameterSettingList setting
---@param vehicleConfigurationName string name of the setting in the vehicle configuration XML
---@param defaultValue any default value to reset the setting to
function CpVehicleSettings:resetToDefault(object, setting, vehicleConfigurationName, defaultValue)
    local value = g_vehicleConfigurations:get(object, vehicleConfigurationName)
    if value then
        CpUtil.debugVehicle(CpDebug.DBG_IMPLEMENTS, self, '%s: resetting to default %s to %s',
                CpUtil.getName(object), vehicleConfigurationName, tostring(defaultValue))
        if type(defaultValue) == 'number' then
            setting:setFloatValue(defaultValue)
        else
            setting:setValue(defaultValue)
        end
    end
end

------------------------------------------------------------------------------------------------------------------------
--- Callbacks for the settings to manipulate the gui elements.
------------------------------------------------------------------------------------------------------------------------

--- Are the combine settings needed.
function CpVehicleSettings:areCombineSettingsVisible()
    local implement = AIUtil.getImplementOrVehicleWithSpecialization(self,Combine)
    return implement and not ImplementUtil.isChopper(implement)
end

--- Are the sowing machine settings needed.
function CpVehicleSettings:areSowingMachineSettingsVisible()
    return AIUtil.getImplementOrVehicleWithSpecialization(self,SowingMachine)
            or AIUtil.getImplementOrVehicleWithSpecialization(self,FertilizingCultivator)
end

--- Disables tool offset, as the plow drive strategy automatically handles the tool offset.
function CpVehicleSettings:isToolOffsetDisabled()
    return AIUtil.getImplementOrVehicleWithSpecialization(self,Plow)
end