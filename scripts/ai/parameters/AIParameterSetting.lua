--- Basic setting that implements the basic interface functionalities.
---@class AIParameterSetting : AIParameterSettingInterface
AIParameterSetting = CpObject(AIParameterSettingInterface)

function AIParameterSetting:init(name)	
	AIParameterSettingInterface.init(self)
	self.data = nil
	self.vehicle = nil
	self.class = nil

	self.name = name
	self.title = ""
	self.tooltip = ""

	self.isValid = true

	self.guiParameterType = nil
end

--- Initialize the setting from config data supplied in CpSettingsUtil
---@param data any
---@param vehicle any
---@param class any
function AIParameterSetting:initFromData(data, vehicle, class)
	self.data = data
	self.vehicle = vehicle
	self.class = class

	self.name = data.name
	self.title = data.title
	self.tooltip = data.tooltip

	self.name = data.name
	self.title = data.title
	self.tooltip = data.tooltip
end

function AIParameterSetting:getName()
	return self.name
end

function AIParameterSetting:getTooltip()
	return self.tooltip
end

function AIParameterSetting:getTitle()
	return self.title
end

function AIParameterSetting:getType()
	return self.guiParameterType	
end

function AIParameterSetting:getString()
	return ""	
end

function AIParameterSetting:getIsValid()
	return self.isValid
end

function AIParameterSetting:setIsValid(isValid)
	self.isValid = isValid
end

function AIParameterSetting:getIsDisabled()
	if self:hasCallback(self.data.isDisabledFunc) then 
		return self:getCallback(self.data.isDisabledFunc)
	end
	return false
end

function AIParameterSetting:getCanBeChanged()
	return not self:getIsDisabled()
end

--- Is the setting visible based on the expert mode setting if necessary and
--- checks if any callbacks are correct.
function AIParameterSetting:getIsVisible()
	if self:getIsExpertModeSetting() and not g_Courseplay.globalSettings.expertModeActive:getValue() then 
		return false
	end
	if self:hasCallback(self.data.isVisibleFunc) then 
		return self:getCallback(self.data.isVisibleFunc)
	end
	return true
end

--- Is the setting specific for a player and is not synchronized?
function AIParameterSetting:getIsUserSetting()
	return self.data.isUserSetting
end

--- Is the setting disabled, when the expert mode is deactivated?
function AIParameterSetting:getIsExpertModeSetting()
	return self.data.isExpertModeOnly
end

--- Raises an event and sends the callback string to the Settings controller class.
function AIParameterSetting:raiseCallback(callbackStr, ...)
	if self.class ~= nil and self.class.raiseCallback and callbackStr then
		self:debug("raised Callback %s", callbackStr)
		--- If the setting is bound to a setting, then call the specialization function with self as vehicle.
		if self.vehicle ~= nil then 
			self.class.raiseCallback(self.vehicle, callbackStr, self, ...)
		else
			self.class:raiseCallback(callbackStr, self, ...)
		end
	end
end

--- If the class has a given callback to call.
function AIParameterSetting:hasCallback(callbackStr)
	if self.class ~= nil and callbackStr then
		if self.class[callbackStr] ~= nil then 
			return true
		end
	end
end

--- Gets the result from a class callback.
function AIParameterSetting:getCallback(callbackStr, ...)
	if self:hasCallback(callbackStr) then
		if self.vehicle ~= nil then 
			return self.class[callbackStr](self.vehicle, self, ...)
		else
			return self.class[callbackStr](self.class, self, ...)
		end
	end
end

--- Make sure the setting value gets synchronized by the class.
function AIParameterSetting:raiseDirtyFlag()
	if not self:getIsUserSetting() then
		if self.class and self.class.raiseDirtyFlag then
			if self.vehicle ~= nil then 
				self.class.raiseDirtyFlag(self.vehicle, self)
			else
				self.class:raiseDirtyFlag(self)
			end
		end
	end
end

function AIParameterSetting:debug(str, ...)
	local name = string.format("%s: ", self.name)
	if self.vehicle == nil then
		CpUtil.debugFormat(CpUtil.DBG_HUD, name..str, ...)
	else 
		CpUtil.debugVehicle(CpUtil.DBG_HUD, self.vehicle, name..str, ...)
	end
end

function AIParameterSetting:getDebugString()
	return tostring(self)
end