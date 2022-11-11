--[[
    CourseGenerator settings
]]--

---@class CpCourseGeneratorSettings
CpCourseGeneratorSettings = {}

CpCourseGeneratorSettings.MOD_NAME = g_currentModName
CpCourseGeneratorSettings.KEY = "."..CpCourseGeneratorSettings.MOD_NAME..".cpCourseGeneratorSettings"
CpCourseGeneratorSettings.SETTINGS_KEY = ".settings"
CpCourseGeneratorSettings.VINE_SETTINGS_KEY = ".vineSettings"
function CpCourseGeneratorSettings.initSpecialization()
	local schema = Vehicle.xmlSchemaSavegame
    --- Old save format
    CpSettingsUtil.registerXmlSchema(schema, 
        "vehicles.vehicle(?)"..CpCourseGeneratorSettings.KEY.."(?)")
    
    --- Normal course generator settings.
    CpSettingsUtil.registerXmlSchema(schema, 
        "vehicles.vehicle(?)"..CpCourseGeneratorSettings.KEY..CpCourseGeneratorSettings.SETTINGS_KEY.."(?)")
    
    --- Vine course generator settings.
    CpSettingsUtil.registerXmlSchema(schema, 
        "vehicles.vehicle(?)"..CpCourseGeneratorSettings.KEY..CpCourseGeneratorSettings.VINE_SETTINGS_KEY.."(?)")
end


function CpCourseGeneratorSettings.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(AIFieldWorker, specializations) 
end

function CpCourseGeneratorSettings.registerEvents(vehicleType)
 --   SpecializationUtil.registerEvent(vehicleType,"cpUpdateGui")
end

function CpCourseGeneratorSettings.registerEventListeners(vehicleType)	
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", CpCourseGeneratorSettings)
    SpecializationUtil.registerEventListener(vehicleType, "onLoadFinished",CpCourseGeneratorSettings)
    SpecializationUtil.registerEventListener(vehicleType, "onCpUnitChanged", CpCourseGeneratorSettings)
end
function CpCourseGeneratorSettings.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, 'getCourseGeneratorSettings', CpCourseGeneratorSettings.getSettings)
    SpecializationUtil.registerFunction(vehicleType, 'getCourseGeneratorSettingsTable', CpCourseGeneratorSettings.getSettingsTable)
    SpecializationUtil.registerFunction(vehicleType, 'getCpVineSettings', CpCourseGeneratorSettings.getCpVineSettings)
    SpecializationUtil.registerFunction(vehicleType, 'getCpVineSettingsTable', CpCourseGeneratorSettings.getCpVineSettingsTable)
    SpecializationUtil.registerFunction(vehicleType, 'validateCourseGeneratorSettings', CpCourseGeneratorSettings.validateSettings)
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

--- Gets all vine settings.
---@return table
function CpCourseGeneratorSettings:getCpVineSettings()
    local spec = self.spec_cpCourseGeneratorSettings
    return spec.vineSettings
end

--- Gets all settings.
---@return table
function CpCourseGeneratorSettings:getCpVineSettingsTable()
    local spec = self.spec_cpCourseGeneratorSettings
    return spec.vineSettings.settings
end

function CpCourseGeneratorSettings:onLoad(savegame)
	--- Register the spec: spec_cpCourseGeneratorSettings
    local specName = CpCourseGeneratorSettings.MOD_NAME .. ".cpCourseGeneratorSettings"
    self.spec_cpCourseGeneratorSettings = self["spec_" .. specName]
    local spec = self.spec_cpCourseGeneratorSettings
    spec.gui = g_currentMission.inGameMenu.pageAI
    --- Clones the generic settings to create different settings containers for each vehicle. 
    CpSettingsUtil.cloneSettingsTable(spec,CpCourseGeneratorSettings.settings,self,CpCourseGeneratorSettings)

    spec.vineSettings = {}
    --- Clones the generic settings to create different settings containers for each vehicle. 
    CpSettingsUtil.cloneSettingsTable(spec.vineSettings,CpCourseGeneratorSettings.vineSettings.settings,self,CpCourseGeneratorSettings)

    CpCourseGeneratorSettings.loadSettings(self,savegame)
end

--- Apply auto work width after everything is loaded and no settings are saved in the save game. 
function CpCourseGeneratorSettings:onLoadFinished(savegame)
    local spec = self.spec_cpCourseGeneratorSettings
    if not spec.wasLoaded then
        CpCourseGeneratorSettings.setAutomaticWorkWidthAndOffset(self)
    end
end

--- Makes sure the automatic work width gets recalculated after the variable work width was changed by the user.
function CpCourseGeneratorSettings.onVariableWorkWidthSectionChanged(object)
    --- Object could be an implement, so make sure we use the root vehicle.
    local self = object.rootVehicle
    if self:getIsSynchronized() and self.spec_cpCourseGeneratorSettings then
        CpCourseGeneratorSettings.setAutomaticWorkWidthAndOffset(self)
    end
end
VariableWorkWidth.updateSections = Utils.appendedFunction(VariableWorkWidth.updateSections,CpCourseGeneratorSettings.onVariableWorkWidthSectionChanged)

function CpCourseGeneratorSettings:setAutomaticWorkWidthAndOffset()
    local spec = self.spec_cpCourseGeneratorSettings
    local width, offset, _, _ = WorkWidthUtil.getAutomaticWorkWidthAndOffset(self)
    spec.workWidth:setFloatValue(width)
    self:getCpSettings().toolOffsetX:setFloatValue(offset)
end

--- Loads the generic settings setup from an xmlFile.
function CpCourseGeneratorSettings.loadSettingsSetup()
    local filePath = Utils.getFilename("config/CourseGeneratorSettingsSetup.xml", g_Courseplay.BASE_DIRECTORY)
    CpSettingsUtil.loadSettingsFromSetup(CpCourseGeneratorSettings,filePath)
    CpCourseGeneratorSettings.vineSettings = {}
    local filePath = Utils.getFilename("config/VineCourseGeneratorSettingsSetup.xml", g_Courseplay.BASE_DIRECTORY)
    CpSettingsUtil.loadSettingsFromSetup(CpCourseGeneratorSettings.vineSettings,filePath)
end
CpCourseGeneratorSettings.loadSettingsSetup()

function CpCourseGeneratorSettings.getSettingSetup(vehicle)
    return CpCourseGeneratorSettings.settingsBySubTitle, 
            vehicle and string.format(CpCourseGeneratorSettings.pageTitle, vehicle:getName()) 
            or CpCourseGeneratorSettings.pageTitle
end

function CpCourseGeneratorSettings.getVineSettingSetup(vehicle)
    return CpCourseGeneratorSettings.vineSettings.settingsBySubTitle, 
            vehicle and string.format(CpCourseGeneratorSettings.vineSettings.pageTitle, vehicle:getName()) 
            or CpCourseGeneratorSettings.vineSettings.pageTitle
end

function CpCourseGeneratorSettings:loadSettings(savegame)
    if savegame == nil or savegame.resetVehicles then return end
    local spec = self.spec_cpCourseGeneratorSettings
    --- Old save format
	savegame.xmlFile:iterate(savegame.key..CpCourseGeneratorSettings.KEY, function (ix, key)
		local name = savegame.xmlFile:getValue(key.."#name")
        local setting = spec[name] or spec.vineSettings[name]
        if setting then
            setting:loadFromXMLFile(savegame.xmlFile, key)
            CpUtil.debugVehicle(CpUtil.DBG_HUD,self,"Loaded setting: %s, value:%s, key: %s",setting:getName(),setting:getValue(),key)
        end
        spec.wasLoaded = true
    end)

    --- Loads the normal course generator settings.
    CpSettingsUtil.loadFromXmlFile(spec, savegame.xmlFile, 
                        savegame.key .. CpCourseGeneratorSettings.KEY ..  CpCourseGeneratorSettings.SETTINGS_KEY, self)

    --- Loads the vine course generator settings.
    CpSettingsUtil.loadFromXmlFile(spec.vineSettings, savegame.xmlFile, 
                        savegame.key .. CpCourseGeneratorSettings.KEY .. CpCourseGeneratorSettings.VINE_SETTINGS_KEY, self)
end

function CpCourseGeneratorSettings:saveToXMLFile(xmlFile, baseKey, usedModNames)
    local spec = self.spec_cpCourseGeneratorSettings

    --- Saves the normal course generator settings.
    CpSettingsUtil.saveToXmlFile(spec.settings, xmlFile, 
    baseKey .. CpCourseGeneratorSettings.SETTINGS_KEY, self, nil)

    --- Saves the vine course generator settings.
    CpSettingsUtil.saveToXmlFile(spec.vineSettings.settings, xmlFile, 
    baseKey .. CpCourseGeneratorSettings.VINE_SETTINGS_KEY, self, nil)

end

--- Callback raised by a setting and executed as an vehicle event.
---@param callbackStr string event to be raised
---@param setting AIParameterSettingList setting that raised the callback.
function CpCourseGeneratorSettings:raiseCallback(callbackStr, setting, ...)
    SpecializationUtil.raiseEvent(self, callbackStr, setting, ...)
end

function CpCourseGeneratorSettings:validateSettings()
    local spec = self.spec_cpCourseGeneratorSettings
    for i,setting in ipairs(spec.settings) do 
        setting:refresh()
    end
    for i,setting in ipairs(spec.vineSettings.settings) do 
        setting:refresh()
    end
end

function CpCourseGeneratorSettings:onCpUnitChanged()
    local spec = self.spec_cpCourseGeneratorSettings
    for i,setting in ipairs(spec.settings) do 
        setting:validateTexts()
    end
    for i,setting in ipairs(spec.vineSettings.settings) do 
        setting:validateTexts()
    end
end

------------------------------------------------------------------------------------------------------------------------
--- Callbacks for the settings to manipulate the gui elements.
------------------------------------------------------------------------------------------------------------------------
function CpCourseGeneratorSettings:hasHeadlandsSelected()
    local spec = self.spec_cpCourseGeneratorSettings
    return spec.numberOfHeadlands:getValue()>0
end

--- Only show the work width, if the bale finder can't be started.
function CpCourseGeneratorSettings:isWorkWidthSettingVisible()
    return not self:getCanStartCpBaleFinder()
end

--- Updates the layout on change, as gui elements might change their visibility.
function CpCourseGeneratorSettings:updateGui()
    local spec = self.spec_cpCourseGeneratorSettings
    CpInGameMenuAIFrameExtended.updateCourseGeneratorSettings(spec.gui, true)
    CpCourseGeneratorSettings.onCpUnitChanged(self)
end
