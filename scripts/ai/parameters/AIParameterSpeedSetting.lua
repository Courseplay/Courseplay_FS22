--- Speed setting
---@class AIParameterSpeedSetting : AIParameterSettingList
AIParameterSpeedSetting = {}

local AIParameterSpeedSetting_mt = Class(AIParameterSpeedSetting, AIParameterSettingList)

function AIParameterSpeedSetting.new(data,vehicle,class,customMt)
	data.max = AIParameterSpeedSetting.getMaxSpeed(vehicle,data.max)
	local self = AIParameterSettingList.new(data,vehicle,class,customMt or AIParameterSpeedSetting_mt)

	return self
end

function AIParameterSpeedSetting.getMaxSpeed(vehicle,default)
	return vehicle and math.max(vehicle:getCruiseControlMaxSpeed(),default) or default
end

function AIParameterSpeedSetting:clone(...)
	return AIParameterSpeedSetting.new(self.data,...)
end
