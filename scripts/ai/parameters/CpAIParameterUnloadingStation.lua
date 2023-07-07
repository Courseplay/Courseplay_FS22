--- Parameter to selected an unloading station.
---@class CpAIParameterUnloadingStation : AIParameterSettingList
CpAIParameterUnloadingStation = CpObject(AIParameterSettingList)

function CpAIParameterUnloadingStation:init(data, vehicle, class)
	AIParameterSettingList.init(self, data, vehicle, class)
	self.guiParameterType = AIParameterType.UNLOADING_STATION
	return self
end

function CpAIParameterUnloadingStation:clone(...)
	return CpAIParameterUnloadingStation(self.data,...)
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

--- Applies the current position to the map hotspot.
function CpAIParameterUnloadingStation:applyToMapHotspot(mapHotspot)
	if not self:getIsVisible() then 
		return false
	end
	local unloadingStation = self:getUnloadingStation()
	if unloadingStation ~= nil then
		local placeable = unloadingStation.owningPlaceable
		if placeable ~= nil and placeable.getHotspot ~= nil then
			local hotspot = placeable:getHotspot(1)
			if hotspot ~= nil then
				local x, z = hotspot:getWorldPosition()
				mapHotspot:setWorldPosition(x, z)
				return true
			end
		end
	end
	return false
end


function CpAIParameterUnloadingStation:__tostring()
	return string.format("CpAIParameterUnloadingStation(name=%s, value=%s, text=%s)", self.name, tostring(self:getValue()), self:getString())
end