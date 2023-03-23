--[[
    Vehicle specific settings
]]--

---@class CpVehicleSettings
CpVehicleSettings = {}

CpVehicleSettings.MOD_NAME = g_currentModName
CpVehicleSettings.KEY = "."..CpVehicleSettings.MOD_NAME..".cpVehicleSettings"
CpVehicleSettings.SETTINGS_KEY = ".settings"
CpVehicleSettings.USER_KEY = ".users"
function CpVehicleSettings.initSpecialization()
	local schema = Vehicle.xmlSchemaSavegame
    --- Old xml schema for settings
    CpSettingsUtil.registerXmlSchema(schema, 
        "vehicles.vehicle(?)" .. CpVehicleSettings.KEY .. "(?)")
   
    --- New xml schema for settings
    CpSettingsUtil.registerXmlSchema(schema, 
        "vehicles.vehicle(?)" .. CpVehicleSettings.KEY .. CpVehicleSettings.SETTINGS_KEY .. "(?)")
   
    --- MP vehicle user settings

    schema:register(XMLValueType.STRING,"vehicles.vehicle(?)" .. CpVehicleSettings.KEY .. CpVehicleSettings.USER_KEY .. "(?)#userId", "User id")
    CpSettingsUtil.registerXmlSchema(schema, 
        "vehicles.vehicle(?)" .. CpVehicleSettings.KEY .. CpVehicleSettings.USER_KEY .. "(?)")
end


function CpVehicleSettings.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(AIFieldWorker, specializations) 
end

function CpVehicleSettings.registerEvents(vehicleType)
    SpecializationUtil.registerEvent(vehicleType, 'onCpUserSettingChanged')
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
    SpecializationUtil.registerEventListener(vehicleType, "onStateChange", CpVehicleSettings)
    SpecializationUtil.registerEventListener(vehicleType, "onCpUserSettingChanged", CpVehicleSettings)
end

function CpVehicleSettings.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, 'getCpSettingsTable', CpVehicleSettings.getSettingsTable)
    SpecializationUtil.registerFunction(vehicleType, 'getCpSettings', CpVehicleSettings.getSettings)
    SpecializationUtil.registerFunction(vehicleType, 'cpSaveUserSettingValue', CpVehicleSettings.cpSaveUserSettingValue)
    SpecializationUtil.registerFunction(vehicleType, 'getCpSavedUserSettingValue', CpVehicleSettings.getCpSavedUserSettingValue)
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
    CpSettingsUtil.cloneSettingsTable(spec, CpVehicleSettings.settings, self, CpVehicleSettings)
    
    spec.userSettings = {}
    CpVehicleSettings.loadSettings(self, savegame)
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

    CpVehicleSettings.setAutomaticWorkWidthAndOffset(self)
    CpVehicleSettings.setAutomaticBunkerSiloWorkWidth(self)

    CpVehicleSettings.setFromVehicleConfiguration(self, object, spec.raiseImplementLate, 'raiseLate')
    CpVehicleSettings.setFromVehicleConfiguration(self, object, spec.lowerImplementEarly, 'lowerEarly')
    CpVehicleSettings.setFromVehicleConfiguration(self, object, spec.bunkerSiloWorkWidth, 'workingWidth')
    CpVehicleSettings.validateSettings(self)
end

function CpVehicleSettings:onPreDetachImplement(implement)
    --- Only apply these values, if were are not loading from a savegame.
    local spec = self.spec_cpVehicleSettings
    if spec.wasLoaded then 
        return
    end

    CpVehicleSettings.setAutomaticWorkWidthAndOffset(self, implement.object)
    CpVehicleSettings.setAutomaticBunkerSiloWorkWidth(self, implement.object)
    
    CpVehicleSettings.resetToDefault(self, implement.object, spec.raiseImplementLate, 'raiseLate', false)
    CpVehicleSettings.resetToDefault(self, implement.object, spec.lowerImplementEarly, 'lowerEarly', false)
    CpVehicleSettings.validateSettings(self)
end

--- Changes the sprayer work width on fill type change, as it might depend on the loaded fill type.
--- For example Lime and Fertilizer might have a different work width.
function CpVehicleSettings:onStateChange(state, data)
    if state == Vehicle.STATE_CHANGE_FILLTYPE_CHANGE and self:getIsSynchronized() then
        local _, hasSprayer = AIUtil.getAllChildVehiclesWithSpecialization(self, Sprayer, nil)
        if hasSprayer then 
            local width, offset = WorkWidthUtil.getAutomaticWorkWidthAndOffset(self, nil, nil)
            local oldWidth = self:getCourseGeneratorSettings().workWidth:getValue()
            if not MathUtil.equalEpsilon(width, oldWidth, 1)  then 
                CpUtil.debugVehicle(CpDebug.DBG_IMPLEMENTS, self, "Changed work width, as the fill type changed.")
                self:getCourseGeneratorSettings().workWidth:setFloatValue(width)
            end
        end
    end
end

function CpVehicleSettings:setAutomaticWorkWidthAndOffset(ignoreObject)
    local spec = self.spec_cpVehicleSettings
    local width, offset = WorkWidthUtil.getAutomaticWorkWidthAndOffset(self, nil, ignoreObject)
    self:getCourseGeneratorSettings().workWidth:setFloatValue(width)
    spec.toolOffsetX:setFloatValue(offset)
end

function CpVehicleSettings:onReadStream(streamId, connection)
    local spec = self.spec_cpVehicleSettings
    for i, setting in ipairs(spec.settings) do 
        setting:readStream(streamId, connection)
    end
end

function CpVehicleSettings:onWriteStream(streamId, connection)
    local spec = self.spec_cpVehicleSettings
    for i, setting in ipairs(spec.settings) do 
        setting:writeStream(streamId, connection)
    end
end

function CpVehicleSettings:cpSaveUserSettingValue(userId, name, value)
    local spec = self.spec_cpVehicleSettings
    if spec.userSettings[userId] == nil then 
        spec.userSettings[userId] = {}
    end
    spec.userSettings[userId][name] = value
end

function CpVehicleSettings:getCpSavedUserSettingValue(setting, connection)
    local spec = self.spec_cpVehicleSettings
    local uniqueUserId = g_currentMission.userManager:getUniqueUserIdByConnection(connection)
    if spec.userSettings[uniqueUserId] then 
        return spec.userSettings[uniqueUserId][setting:getName()]
    end
end

function CpVehicleSettings.loadSettingsSetup()
    local filePath = Utils.getFilename("config/VehicleSettingsSetup.xml", g_Courseplay.BASE_DIRECTORY)
    CpSettingsUtil.loadSettingsFromSetup(CpVehicleSettings, filePath)
end
CpVehicleSettings.loadSettingsSetup()

function CpVehicleSettings.getSettingSetup()
    return CpVehicleSettings.settingsBySubTitle, CpVehicleSettings.pageTitle
end

function CpVehicleSettings:loadSettings(savegame)
    if savegame == nil or savegame.resetVehicles then return end
    local spec = self.spec_cpVehicleSettings

    --- Loads the old save format
    CpSettingsUtil.loadFromXmlFile(spec, savegame.xmlFile, 
                        savegame.key .. CpVehicleSettings.KEY, self)

    --- Loads the new save format
    CpSettingsUtil.loadFromXmlFile(spec, savegame.xmlFile, 
                        savegame.key .. CpVehicleSettings.KEY .. CpVehicleSettings.SETTINGS_KEY, self)

    --- Loads the user settings for multiplayer.
    savegame.xmlFile:iterate(savegame.key..CpVehicleSettings.KEY..CpVehicleSettings.USER_KEY, function (ix, key)
        local name = savegame.xmlFile:getValue(key.."#name")
        local value =  tonumber(savegame.xmlFile:getValue(key.."#currentValue"))
        local userId = savegame.xmlFile:getValue(key.."#userId")
        if userId then
            if spec.userSettings[userId] == nil then 
                spec.userSettings[userId] = {}
            end
            spec.userSettings[userId][name] = value
        end
	end)

end

function CpVehicleSettings:saveToXMLFile(xmlFile, baseKey, usedModNames)
    local spec = self.spec_cpVehicleSettings
    --- Saves the settings.
    CpSettingsUtil.saveToXmlFile(spec.settings, xmlFile, 
        baseKey .. CpVehicleSettings.SETTINGS_KEY, self, nil)
    --- Saves the user settings for multiplayer.
    local ix = 0
    for userId, settings in pairs(spec.userSettings) do 
        for name, value in pairs(settings) do 
            local key = string.format("%s(%d)", baseKey.. CpVehicleSettings.USER_KEY, ix)
            xmlFile:setValue(key.."#name", name)
            xmlFile:setValue(key.."#currentValue", tostring(value))
            xmlFile:setValue(key.."#userId", userId)
            ix = ix + 1
        end
    end
end

--- Callback raised by a setting and executed as an vehicle event.
---@param callbackStr string event to be raised
---@param setting AIParameterSettingList setting that raised the callback.
function CpVehicleSettings:raiseCallback(callbackStr, setting, ...)
    SpecializationUtil.raiseEvent(self, callbackStr, setting, ...)
end

function CpVehicleSettings:raiseDirtyFlag(setting)
    VehicleSettingsEvent.sendEvent(self, setting)
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
    local implement = AIUtil.getImplementOrVehicleWithSpecialization(self, Combine)
    return implement and not ImplementUtil.isChopper(implement)
end

--- Are the sowing machine settings needed.
function CpVehicleSettings:areSowingMachineSettingsVisible()
    
    return CpVehicleSettings.isRidgeMarkerSettingVisible(self) or 
            CpVehicleSettings.isSowingMachineFertilizerSettingVisible(self) or 
            CpVehicleSettings.isOptionalSowingMachineSettingVisible(self)
end

--- Disables tool offset, as the plow drive strategy automatically handles the tool offset.
function CpVehicleSettings:isToolOffsetDisabled()
    return AIUtil.hasChildVehicleWithSpecialization(self, Plow)
end

--- Only shows the setting if a valid tool with ridge markers is attached.
function CpVehicleSettings:isRidgeMarkerSettingVisible()
    local vehicles, found = AIUtil.getAllChildVehiclesWithSpecialization(self, RidgeMarker)
    return found and vehicles[1].spec_ridgeMarker.numRigdeMarkers > 0
end

function CpVehicleSettings:isOptionalSowingMachineSettingVisible()
    local vehicles, found = AIUtil.getAllChildVehiclesWithSpecialization(self, SowingMachine)
    return found and not vehicles[1]:getAIRequiresTurnOn()
end

function CpVehicleSettings:isSowingMachineFertilizerSettingVisible()
    return AIUtil.hasChildVehicleWithSpecialization(self, FertilizingSowingMachine) or 
             AIUtil.hasChildVehicleWithSpecialization(self, FertilizingCultivator)
end

--- Only show the multi tool settings, with a multi tool course loaded.
function CpVehicleSettings:hasMultiToolCourse()
    local course = self:getFieldWorkCourse()
    return course and course:getMultiTools() > 1
end

--- Only show this setting, when an implement with additive tank was found.
function CpVehicleSettings:isAdditiveFillUnitSettingVisible()
    local combines, _ = AIUtil.getAllChildVehiclesWithSpecialization(self, Combine)
    local forageWagons, _ = AIUtil.getAllChildVehiclesWithSpecialization(self, ForageWagon)
    local balers, _ = AIUtil.getAllChildVehiclesWithSpecialization(self, Baler)
    local hasAdditiveTank
    if #combines > 0 then 
        hasAdditiveTank = combines[1].spec_combine.additives.available
    end
    if #forageWagons > 0 then 
        hasAdditiveTank = hasAdditiveTank or forageWagons[1].spec_forageWagon.additives.available
    end
    if #balers > 0 then 
        hasAdditiveTank = hasAdditiveTank or balers[1].spec_baler.additives.available
    end
    return hasAdditiveTank
end

function CpVehicleSettings:areCourseSettingsVisible()
    return not self:getCanStartCpCombineUnloader()
end

function CpVehicleSettings:areBunkerSiloSettingsVisible()
    return self:getCanStartCpBunkerSiloWorker()
end

function CpVehicleSettings:areCombineUnloaderSettingsVisible()
    return self:getCanStartCpCombineUnloader()
end

function CpVehicleSettings:setAutomaticBunkerSiloWorkWidth(ignoreObject)
    local spec = self.spec_cpVehicleSettings
    local width = WorkWidthUtil.getAutomaticWorkWidthAndOffset(self, nil, ignoreObject)
    spec.bunkerSiloWorkWidth:setFloatValue(width)
end

--- Saves the user value changed on the server.
function CpVehicleSettings:onCpUserSettingChanged(setting)
    if not self.isServer then 
        VehicleUserSettingsEvent.sendEvent(self, setting)
    end
end