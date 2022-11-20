
---@class CpAIParameterUnloadingStation : AIParameterSettingList
CpAIParameterUnloadingStation = {}
local CpAIParameterUnloadingStation_mt = Class(CpAIParameterUnloadingStation, AIParameterSettingList)

function CpAIParameterUnloadingStation.new(data, vehicle, class, customMt)
	local self = AIParameterSettingList.new(data, vehicle, class, customMt or CpAIParameterUnloadingStation_mt)
	self.type = AIParameterType.UNLOADING_STATION
	return self
end

function CpAIParameterUnloadingStation:clone(...)
	return CpAIParameterUnloadingStation.new(self.data,...)
end

--- Gets the current selected unloading station.
--- Is also used to display the unloading station on the map.
function CpAIParameterUnloadingStation:getUnloadingStation()
	if self.values[self.current] >=0 then 
		return NetworkUtil.getObject(self.values[self.current])
	end
end

--- Checks if the selected unloading station is valid.
function CpAIParameterUnloadingStation:validateUnloadingStation(fillTypeIndex, farmId)
	local unloadingStation = self:getUnloadingStation()
	if unloadingStation == nil then
		return false, g_i18n:getText("ai_validationErrorNoUnloadingStation")
	end

	if fillTypeIndex ~= nil then
		if not unloadingStation:getIsFillTypeAISupported(fillTypeIndex) then
			return false, g_i18n:getText("ai_validationErrorFillTypeNotSupportedByUnloadingStation")
		end

		if unloadingStation:getFreeCapacity(fillTypeIndex, farmId) <= 0 then
			return false, g_i18n:getText("ai_validationErrorUnloadingStationIsFull")
		end
	end

	return true, nil
	
end