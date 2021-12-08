--- Boolean setting
---@class AIParameterBooleanSetting : AIParameterSettingList
AIParameterBooleanSetting = {}
AIParameterBooleanSetting.DEFAULT_ACTIVATED_TEXT = "COURSEPLAY_ACTIVATED"
AIParameterBooleanSetting.DEFAULT_DEACTIVATED_TEXT = "COURSEPLAY_DEACTIVATED"

local AIParameterBooleanSetting_mt = Class(AIParameterBooleanSetting, AIParameterSettingList)

function AIParameterBooleanSetting.new(data,customMt)
	data.values = {false,true}
	data.texts = next(data.texts) ~= nil and data.texts or {
		g_i18n:getText(AIParameterBooleanSetting.DEFAULT_DEACTIVATED_TEXT),
		g_i18n:getText(AIParameterBooleanSetting.DEFAULT_ACTIVATED_TEXT),
	}
	local self = AIParameterSettingList.new(data,customMt or AIParameterBooleanSetting_mt)

	return self
end
