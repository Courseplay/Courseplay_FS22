--- Boolean setting
---@class AIParameterBooleanSetting : AIParameterSettingList
AIParameterBooleanSetting = CpObject(AIParameterSettingList)
AIParameterBooleanSetting.DEFAULT_ACTIVATED_TEXT = "CP_activated"
AIParameterBooleanSetting.DEFAULT_DEACTIVATED_TEXT = "CP_deactivated"

function AIParameterBooleanSetting:init(data, vehicle, class)
	data.values = {false,true}
	data.texts = next(data.texts) ~= nil and data.texts or {
		g_i18n:getText(AIParameterBooleanSetting.DEFAULT_DEACTIVATED_TEXT),
		g_i18n:getText(AIParameterBooleanSetting.DEFAULT_ACTIVATED_TEXT),
	}
	AIParameterSettingList.init(self, data, vehicle, class)
end

function AIParameterBooleanSetting:clone(...)
	return AIParameterBooleanSetting(self.data, ...)
end

--- Gets the closest ix relative to the setup ix.
---@param ix number
---@return number
function AIParameterBooleanSetting:getClosestIxFromSetup(ix)
	return ix
end

--- Gets the closest setup ix relative to the current ix.
---@return number
function AIParameterBooleanSetting:getClosestSetupIx()
	return self.current
end

function AIParameterBooleanSetting:loadFromXMLFile(xmlFile, key)
	local rawValue = xmlFile:getString(key .. "#currentValue")
	if rawValue ~= nil then 
		self:setValue(rawValue == "true" or false)
	else 
		self:loadFromXMLFileLegacy(xmlFile, key)
	end
end

function AIParameterBooleanSetting:__tostring()
	return string.format("AIParameterBooleanSetting(name=%s, value=%s, text=%s)", self.name, tostring(self:getValue()), self:getString())
end