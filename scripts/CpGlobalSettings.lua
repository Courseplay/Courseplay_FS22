--- TODO: implement saving/loading

CpGlobalSettings = CpObject()
CpGlobalSettings.KEY = "GlobalSettings.GlobalSetting(?)"

function CpGlobalSettings:init()
	self:loadSettingsSetup()
end

function CpGlobalSettings:registerSchema(schema,baseKey)
	schema:register(XMLValueType.INT,baseKey..CpGlobalSettings.KEY,"Setting value")
end

--- Loads settings setup form an xmlFile.
function CpGlobalSettings:loadSettingsSetup()
    local filePath = Utils.getFilename("config/GlobalSettingsSetup.xml", g_Courseplay.BASE_DIRECTORY)
    CpSettingsUtil.loadSettingsFromSetup(self,filePath)
    if self.globalNames then 
        for name,value in pairs(self.globalNames) do 
            self[name] = value
        end
    end
end

function CpGlobalSettings:loadFromXMLFile(xmlFile,baseKey)

end

function CpGlobalSettings:saveToXMLFile(xmlFile,baseKey)
	
end

function CpGlobalSettings:getSetting(name)
    return self.settingsByName[name]
end

function CpGlobalSettings:getSettingValue(name)
    return self.settingsByName[name]:getValue()
end

function CpGlobalSettings:setSettingValue(name,value)
    return self.settingsByName[name]:setValue(value)
end

function CpGlobalSettings:getSettings()
    return self.settings
end

function CpGlobalSettings:getSettingSetup()
	return self.settingsBySubTitle
end