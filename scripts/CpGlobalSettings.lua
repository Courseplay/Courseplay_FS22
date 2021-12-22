--- TODO: implement saving/loading

CpGlobalSettings = CpObject()
CpGlobalSettings.KEY = "GlobalSettings.GlobalSetting"

function CpGlobalSettings:init()
	self:loadSettingsSetup()
end

function CpGlobalSettings:registerSchema(schema,baseKey)
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
    for i,setting in ipairs(self.settings) do 
        local key = string.format("%s%s(%d)",baseKey,CpGlobalSettings.KEY,i-1)
        setting:saveToXMLFile(xmlFile, key)
        xmlFile:setValue(key.."#name",setting:getName())
        CpUtil.debugFormat(CpUtil.DBG_HUD,"Saved setting: %s, value:%s, key: %s",setting:getName(),setting:getValue(),key)
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

function CpGlobalSettings:raiseCallback(callbackStr,...)
    if self[callbackStr] then 
        self[callbackStr](self,...)
    end
end

function CpGlobalSettings:raiseDirtyFlag(setting)
    GlobalSettingEvent.sendEvent(self.settingsToIndex[setting])
end