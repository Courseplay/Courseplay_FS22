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