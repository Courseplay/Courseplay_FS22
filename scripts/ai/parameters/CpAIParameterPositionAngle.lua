---@class CpAIParameterPositionAngle : AIParameterPositionAngle
CpAIParameterPositionAngle = {
	--- These are the different ai map hotspots, that can be set in the ai menu.
	POSITION_TYPES = {
		DRIVE_TO = 0,	--- with angle
		FIELD_OR_SILO = 1, --- without angle
		UNLOAD = 2 --- with angle
	}
}
local CpAIParameterPositionAngle_mt = Class(CpAIParameterPositionAngle, AIParameterPositionAngle)

---@param data table
---@param vehicle table
---@param class table
---@return CpAIParameterPositionAngle
function CpAIParameterPositionAngle.new(data, vehicle, class, customMt)
	local self = AIParameterPositionAngle.new(math.rad(0), customMt or CpAIParameterPositionAngle_mt)
	self.angle = 0
	self.x = 0
	self.z = 0
	self.positionType = self.POSITION_TYPES[data.positionParameterType]
	self.data = data
	self.vehicle = vehicle
	self.klass = class
	self.name = data.name
	self.title = data.title
	self.tooltip = data.tooltip
	self.isDisabled = false
	self.isVisible = true

	self.setupDone = true
	return self
end

function CpAIParameterPositionAngle:clone(...)
	return CpAIParameterPositionAngle.new(self.data,...)
end

function CpAIParameterPositionAngle:copy(setting)
	self.x = setting.x 
	self.z = setting.z
	self.angle = setting.angle
end

--- Applies the current position and angle to the map hotspot.
function CpAIParameterPositionAngle:applyToMapHotspot(mapHotspot)
	local x, z = self:getPosition()
	local angle = self:getAngle() + math.pi

	mapHotspot:setWorldPosition(x, z)
	if self.type == AIParameterType.POSITION_ANGLE then
		mapHotspot:setWorldRotation(angle)
	end
end

function CpAIParameterPositionAngle:refresh()
	
end

function CpAIParameterPositionAngle:setDefault()
	
end

function CpAIParameterPositionAngle:setValue(x, z, angle)
	self.x = x 
	self.z = z
	if angle ~= nil then 
		self.angle = angle
	end
end

function CpAIParameterPositionAngle:getValue()
	return self.x, self.z, self.angle
end

function CpAIParameterPositionAngle:getTitle()
	return self.title	
end

function CpAIParameterPositionAngle:getTooltip()
	return self.tooltip	
end

function CpAIParameterPositionAngle:getName()
	return self.name	
end

function CpAIParameterPositionAngle:getPositionType()
	return self.positionType
end

function CpAIParameterPositionAngle:setGenericGuiElementValues(guiElement)
	if guiElement.labelElement and guiElement.labelElement.setText then
		guiElement:setLabel(self:getTitle())
	end
	local toolTipElement = guiElement.elements[6]
	if toolTipElement then
		toolTipElement:setText(self:getTooltip())
	end
end


function CpAIParameterPositionAngle:setGuiElement(guiElement, titleGuiElement)
	self.guiElement = guiElement
	
end

function CpAIParameterPositionAngle:resetGuiElement()
	self.guiElement = nil
end

function CpAIParameterPositionAngle:hasCallback(callbackStr)
	if self.klass ~= nil and callbackStr then
		if self.klass[callbackStr] ~= nil then 
			return true
		end
	end
end

function CpAIParameterPositionAngle:getCallback(callbackStr, ...)
	if self:hasCallback(callbackStr) then
		if self.vehicle ~= nil then 
			return self.klass[callbackStr](self.vehicle, self, ...)
		else
			return self.klass[callbackStr](self.klass, self, ...)
		end
	end
end


function CpAIParameterPositionAngle:getIsDisabled()
	if self:hasCallback(self.data.isDisabledFunc) then 
		return self:getCallback(self.data.isDisabledFunc)
	end
	return self.isDisabled
end

function CpAIParameterPositionAngle:getCanBeChanged()
	return not self:getIsDisabled()
end

function CpAIParameterPositionAngle:getIsVisible()
	if self.data.isExpertModeOnly and not g_Courseplay.globalSettings.expertModeActive:getValue() then 
		return false
	end
	if self:hasCallback(self.data.isVisibleFunc) then 
		return self:getCallback(self.data.isVisibleFunc)
	end
	return self.isVisible
end

function CpAIParameterPositionAngle:debug(str, ...)
	local name = string.format("%s: ", self.name)
	if self.vehicle == nil then
		CpUtil.debugFormat(CpUtil.DBG_HUD, name..str, ...)
	else 
		CpUtil.debugVehicle(CpUtil.DBG_HUD, self.vehicle, name..str, ...)
	end
end

---@class CpAIParameterPosition : AIParameterPosition
CpAIParameterPosition = {}
local CpAIParameterPosition_mt = Class(CpAIParameterPosition, AIParameterPosition)
function CpAIParameterPosition.new(data, vehicle, class, customMt)
	local self = AIParameterPosition.new(customMt or CpAIParameterPosition_mt)
	self.x = 0
	self.z = 0
	self.positionType = CpAIParameterPositionAngle.POSITION_TYPES[data.positionParameterType]
	self.data = data
	self.vehicle = vehicle
	self.klass = class
	self.name = data.name
	self.title = data.title
	self.tooltip = data.tooltip
	self.isDisabled = false
	self.isVisible = true

	self.setupDone = true
	return self
end

function CpAIParameterPosition:clone(...)
	return CpAIParameterPosition.new(self.data,...)
end

function CpAIParameterPosition:copy(setting)
	self.x = setting.x 
	self.z = setting.z
end

--- Applies the current position to the map hotspot.
function CpAIParameterPosition:applyToMapHotspot(mapHotspot)
	local x, z = self:getPosition()
	mapHotspot:setWorldPosition(x, z)
end

function CpAIParameterPosition:refresh()
	
end

function CpAIParameterPosition:setDefault()
	
end

function CpAIParameterPosition:setValue(x, z)
	self.x = x 
	self.z = z
end

function CpAIParameterPosition:getValue()
	return self.x, self.z
end

function CpAIParameterPosition:getTitle()
	return self.title	
end

function CpAIParameterPosition:getTooltip()
	return self.tooltip	
end

function CpAIParameterPosition:getName()
	return self.name	
end

function CpAIParameterPosition:getPositionType()
	return self.positionType
end

function CpAIParameterPosition:setGenericGuiElementValues(guiElement)
	if guiElement.labelElement and guiElement.labelElement.setText then
		guiElement:setLabel(self:getTitle())
	end
	local toolTipElement = guiElement.elements[6]
	if toolTipElement then
		toolTipElement:setText(self:getTooltip())
	end
end


function CpAIParameterPosition:setGuiElement(guiElement, titleGuiElement)
	self.guiElement = guiElement
	
end

function CpAIParameterPosition:resetGuiElement()
	self.guiElement = nil
end

function CpAIParameterPosition:hasCallback(callbackStr)
	if self.klass ~= nil and callbackStr then
		if self.klass[callbackStr] ~= nil then 
			return true
		end
	end
end

function CpAIParameterPosition:getCallback(callbackStr, ...)
	if self:hasCallback(callbackStr) then
		if self.vehicle ~= nil then 
			return self.klass[callbackStr](self.vehicle, self, ...)
		else
			return self.klass[callbackStr](self.klass, self, ...)
		end
	end
end

function CpAIParameterPosition:getIsDisabled()
	if self:hasCallback(self.data.isDisabledFunc) then 
		return self:getCallback(self.data.isDisabledFunc)
	end
	return self.isDisabled
end

function CpAIParameterPosition:getCanBeChanged()
	return not self:getIsDisabled()
end

function CpAIParameterPosition:getIsVisible()
	if self.data.isExpertModeOnly and not g_Courseplay.globalSettings.expertModeActive:getValue() then 
		return false
	end
	if self:hasCallback(self.data.isVisibleFunc) then 
		return self:getCallback(self.data.isVisibleFunc)
	end
	return self.isVisible
end

function CpAIParameterPosition:debug(str, ...)
	local name = string.format("%s: ", self.name)
	if self.vehicle == nil then
		CpUtil.debugFormat(CpUtil.DBG_HUD, name..str, ...)
	else 
		CpUtil.debugVehicle(CpUtil.DBG_HUD, self.vehicle, name..str, ...)
	end
end