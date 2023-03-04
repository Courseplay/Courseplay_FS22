--- Speed setting, currently no extra functionality over AIParameterSettingList, but may add in the future.
---@class AIParameterSpeedSetting : AIParameterSettingList
AIParameterSpeedSetting = CpObject(AIParameterSettingList)

function AIParameterSpeedSetting:init(data, vehicle, class)
	AIParameterSettingList.init(self, data,vehicle,class)
end

function AIParameterSpeedSetting:clone(...)
	return AIParameterSpeedSetting(self.data, ...)
end