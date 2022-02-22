--- TODO: implement saving/loading

CpGlobalSettings = CpObject()
CpGlobalSettings.KEY = "GlobalSettings.GlobalSetting"

function CpGlobalSettings:init()
	self:loadSettingsSetup()
    g_messageCenter:subscribe(MessageType.SETTING_CHANGED[GameSettings.SETTING.USE_MILES], self.onUnitChanged, self)
    g_messageCenter:subscribe(MessageType.SETTING_CHANGED[GameSettings.SETTING.USE_ACRE], self.onUnitChanged, self)
end

function CpGlobalSettings:registerXmlSchema(schema,baseKey)
	schema:register(XMLValueType.INT,baseKey..CpGlobalSettings.KEY.."(?)#value","Setting value")
    schema:register(XMLValueType.STRING,baseKey..CpGlobalSettings.KEY.."(?)#name","Setting name")
end

--- Loads settings setup form an xmlFile.
function CpGlobalSettings:loadSettingsSetup()
    local filePath = Utils.getFilename("config/GlobalSettingsSetup.xml", g_Courseplay.BASE_DIRECTORY)
    CpSettingsUtil.loadSettingsFromSetup(self,filePath)
end

function CpGlobalSettings:loadFromXMLFile(xmlFile,baseKey)
    xmlFile:iterate(baseKey..CpGlobalSettings.KEY, function (ix, key)
		local name = xmlFile:getValue(key.."#name")
        local setting = self[name]
        if setting then
            setting:loadFromXMLFile(xmlFile, key)
            CpUtil.debugFormat(CpUtil.DBG_HUD,"Loaded setting: %s, value:%s, key: %s",setting:getName(),setting:getValue(),key)
        end
    end)
end

function CpGlobalSettings:saveToXMLFile(xmlFile,baseKey)
    local ix = 0
    for i,setting in ipairs(self.settings) do 
        if not setting:getIsUserSetting() then
            local key = string.format("%s%s(%d)",baseKey,CpGlobalSettings.KEY,ix)
            setting:saveToXMLFile(xmlFile, key)
            xmlFile:setValue(key.."#name",setting:getName())
            CpUtil.debugFormat(CpUtil.DBG_HUD,"Saved setting: %s, value:%s, key: %s",setting:getName(),setting:getValue(),key)
            ix = ix + 1
        end
    end
end

function CpGlobalSettings:saveUserSettingsToXmlFile(xmlFile,baseKey)
    local ix = 0
    for i,setting in ipairs(self.settings) do 
        if setting:getIsUserSetting() then
            local key = string.format("%s%s(%d)",baseKey,CpGlobalSettings.KEY,ix)         
            setting:saveToXMLFile(xmlFile, key)
            xmlFile:setValue(key.."#name",setting:getName())
            CpUtil.debugFormat(CpUtil.DBG_HUD,"Saved setting: %s, value:%s, key: %s",setting:getName(),setting:getValue(),key)
            ix = ix + 1
        end
    end
end

function CpGlobalSettings:getSettings()
    return self
end

function CpGlobalSettings:getSettingsTable()
    return self.settings
end

function CpGlobalSettings:getSettingSetup()
	return self.settingsBySubTitle,self.pageTitle
end

--- Callback raised by a setting.
---@param callbackStr string function to be executed.
---@param setting AIParameterSettingList setting that raised the callback.
function CpGlobalSettings:raiseCallback(callbackStr, setting, ...)
    if self[callbackStr] then 
        self[callbackStr](self, setting, ...)
    end
end

function CpGlobalSettings:raiseDirtyFlag(setting)
    GlobalSettingsEvent.sendEvent(setting)
end 

function CpGlobalSettings:onHudSelectionChanged()
    local vehicle = g_currentMission.controlledVehicle
    if vehicle then 
        self:debug("reset action events for %s",vehicle:getName())
    --    g_inputBinding:setShowMouseCursor(false)
        CpGuiUtil.setCameraRotation(vehicle, true, vehicle.spec_cpHud.savedCameraRotatableInfo)
        vehicle:requestActionEventUpdate()
    end
end

function CpGlobalSettings:onActionEventTextVisibilityChanged()
    local vehicle = g_currentMission.controlledVehicle
    if vehicle then 
        vehicle:requestActionEventUpdate()
    end
    CpDebug:updateActionEventTextVisibility()
end

function CpGlobalSettings:onUnitChanged()
    for i,setting in ipairs(self.settings) do 
        setting:validateTexts()
    end
end

function CpGlobalSettings:debug(str,...)
    CpUtil.debugFormat(CpDebug.DBG_HUD,"Global settings: "..str,...)    
end