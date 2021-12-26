--- Speed setting, currently no extra functionality over AIParameterSettingList, but may add in the future.
---@class AIParameterSpeedSetting : AIParameterSettingList
AIParameterSpeedSetting = {}

local AIParameterSpeedSetting_mt = Class(AIParameterSpeedSetting, AIParameterSettingList)

function AIParameterSpeedSetting.new(data,vehicle,class,customMt)
	local self = AIParameterSettingList.new(data,vehicle,class,customMt or AIParameterSpeedSetting_mt)
	return self
end
