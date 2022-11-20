--- Boolean setting
---@class AIParameterBooleanSetting : AIParameterSettingList
AIParameterBooleanSetting = {}
AIParameterBooleanSetting.DEFAULT_ACTIVATED_TEXT = "CP_activated"
AIParameterBooleanSetting.DEFAULT_DEACTIVATED_TEXT = "CP_deactivated"

local AIParameterBooleanSetting_mt = Class(AIParameterBooleanSetting, AIParameterSettingList)

function AIParameterBooleanSetting.new(data,vehicle,class,customMt)
	data.values = {false,true}
	data.texts = next(data.texts) ~= nil and data.texts or {
		g_i18n:getText(AIParameterBooleanSetting.DEFAULT_DEACTIVATED_TEXT),
		g_i18n:getText(AIParameterBooleanSetting.DEFAULT_ACTIVATED_TEXT),
	}
	local self = AIParameterSettingList.new(data,vehicle,class,customMt or AIParameterBooleanSetting_mt)

	return self
end

function AIParameterBooleanSetting:clone(...)
	return AIParameterBooleanSetting.new(self.data,...)
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