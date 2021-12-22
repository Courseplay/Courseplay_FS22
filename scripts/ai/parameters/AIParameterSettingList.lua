--- Selection list with values and texts.
---@class AIParameterSettingList : AIParameter
AIParameterSettingList = {}
local AIParameterSettingList_mt = Class(AIParameterSettingList, AIParameter)

function AIParameterSettingList.new(data,vehicle,class,customMt)
	local self = AIParameter.new(customMt or AIParameterSettingList_mt)
	self.type = AIParameterType.SELECTOR
	self.vehicle = vehicle
	self.class = class
	self.name = data.name
	if next(data.values) ~=nil then 
		self.values = data.values
		self.texts = data.texts
	else 
		self.values = {}
		self.texts = {}
		AIParameterSettingList.generateValues(self,self.values,self.texts,data.min,data.max,data.incremental,data.textStr,data.unit)
	end
	self.title = data.title 
	self.tooltip = data.tooltip

	-- index of the current value/text
	self.current =  1
	-- index of the previous value/text
	self.previous = 1

	if self.texts == nil or next(self.texts) == nil then 
		self.texts = {}
		AIParameterSettingList.enrichTexts(self,data.unit)
	end

	if data.default ~=nil then
		AIParameterSettingList.setFloatValue(self,data.default)
		self:debug("set to default %s",data.default)
	end

	self.callbacks = data.callbacks

	self.data = data

	self.guiElementId = data.uniqueID

	self.guiElement = nil

	self.isDisabled = false
	self.setupDone = true
	return self
end

function AIParameterSettingList.getSpeedText(value)
	return string.format("%1d %s",g_i18n:getSpeed(value),g_i18n:getSpeedMeasuringUnit())
end

function AIParameterSettingList.getDistanceText(value)
	return string.format("%.1f %s",g_i18n:getDistance(value),g_i18n:getText("CP_unit_meter"))
end

function AIParameterSettingList.getAreaText(value)
	return g_i18n:formatArea(value, 1, true)
end

AIParameterSettingList.UNITS = {
	AIParameterSettingList.getSpeedText, --- km/h
	AIParameterSettingList.getDistanceText, --- m
	AIParameterSettingList.getAreaText, --- ha/arcs
	function () return "%"	end			--- percent
}


--- Generates numeric values and texts from min to max with incremental of inc or 1.
---@param values table
---@param texts table
---@param min number
---@param max number
---@param inc number
---@param textStr string
---@param unit number
function AIParameterSettingList:generateValues(values,texts,min,max,inc,textStr,unit)
	inc = inc or 1
	for i=min,max,inc do 
		table.insert(values,i)
		local value = MathUtil.round(i,2)
		local text = unit and AIParameterSettingList.UNITS[unit] and AIParameterSettingList.UNITS[unit](value) or tostring(value)
		local text = textStr and string.format(textStr,value) or text
		table.insert(texts,text)
	end
end

--- Enriches texts with values of values, if they are not explicit declared. 
function AIParameterSettingList:enrichTexts(unit)
	for i,value in ipairs(self.values) do 
		local text = tostring(value)
		if unit then 
			text = text..AIParameterSettingList.UNITS[unit](value)
		end
		self.texts[i] = text
	end
end


-- Is the current value same as the param?
function AIParameterSettingList:is(value)
	return self.values[self.current] == value
end

-- Get the current text key (for the logs, for example)
function AIParameterSettingList:__tostring()
	return self.texts[self.current]
end

-- private function to set to the value at ix
function AIParameterSettingList:setToIx(ix)
	if ix ~= self.current then
		self.previous = self.current
		self.current = ix
		self:onChange()
		self:updateGuiElementValues()
	end
end

function AIParameterSettingList:checkAndSetValidValue(new)
	if new > #self.values then
		return 1
	elseif new < 1 then
		return #self.values
	else
		return new
	end
end

function AIParameterSettingList:onChange()
	if self.setupDone then
		self:raiseCallback(self.callbacks.onChangeCallbackStr)
	end
end

function AIParameterSettingList:validateCurrentValue()
	local new = self:checkAndSetValidValue(self.current)
	self:setToIx(new)
end

function AIParameterSettingList:getDebugString()
	-- replace % as this string goes through multiple formats (%% does not seem to work and I have no time to figure it out
	return string.format('%s: %s', self.name, string.gsub(self.texts[self.current], '%%', 'percent'))
end
function AIParameterSettingList:saveToXMLFile(xmlFile, key, usedModNames)
	xmlFile:setInt(key .. "#value", self.current)
end

function AIParameterSettingList:loadFromXMLFile(xmlFile, key)
	self:setToIx(xmlFile:getInt(key .. "#value", self.current))
end

function AIParameterSettingList:readStream(streamId, connection)
	self:setToIx(streamReadInt32(streamId))
end

function AIParameterSettingList:writeStream(streamId, connection)
	streamWriteInt32(streamId, self.current)
end

local function setValueInternal(self, value, comparisonFunc)
	local new
	-- find the value requested
	for i = 1, #self.values do
		if comparisonFunc(self.values[i], value) then
			new = self:checkAndSetValidValue(i)
			self:setToIx(new)
			return
		end
	end
end

function AIParameterSettingList:setFloatValue(value)
	setValueInternal(self, value, function(a, b)  return MathUtil.equalEpsilon(a, b, 0.01) end)
end

--- Set to a specific value.
function AIParameterSettingList:setValue(value)
	setValueInternal(self, value, function(a, b)  return a == b end)
end

--- Gets a specific value.
function AIParameterSettingList:getValue()
	return self.values[self.current]
end

function AIParameterSettingList:getString()
	return self.texts[self.current]
end

--- Set the next value
function AIParameterSettingList:setNextItem()
	local new = self:checkAndSetValidValue(self.current + 1)
	self:setToIx(new)
end

--- Set the previous value
function AIParameterSettingList:setPreviousItem()
	local new = self:checkAndSetValidValue(self.current - 1)
	self:setToIx(new)
end

function AIParameterSettingList:clone(...)
	return AIParameterSettingList.new(self.data,...)
end

function AIParameterSettingList:getTitle()
	return self.title	
end

function AIParameterSettingList:getTooltip()
	return self.tooltip	
end

function AIParameterSettingList:setGenericGuiElementValues(guiElement)
	guiElement.leftButtonElement:setCallback("onClickCallback", "setPreviousItem")
	guiElement.rightButtonElement:setCallback("onClickCallback", "setNextItem")
	guiElement:setCallback("onClickCallback", "onClick")
	guiElement:setLabel(self:getTitle())
	local toolTipElement = guiElement.elements[6]
	toolTipElement:setText(self:getTooltip())
end

function AIParameterSettingList:getGuiElementTexts()
	return self.texts
end

function AIParameterSettingList:getGuiElementStateFromValue(value)
	for i = 1, #self.values do
		if self.values[i] == value then
			return i
		end
	end
	return nil
end

function AIParameterSettingList:getGuiElementState()
	return self:getGuiElementStateFromValue(self.values[self.current])
end

function AIParameterSettingList:updateGuiElementValues()
	if self.guiElement == nil then return end
	self.guiElement:setState(self:getGuiElementState())
	self.guiElement:setDisabled(self.isDisabled)
end

function AIParameterSettingList:setGuiElement(guiElement)
	self:validateCurrentValue()
	self.guiElement = guiElement
	self.guiElement.target = self
	self.guiElement.leftButtonElement.target = self
	self.guiElement.rightButtonElement.target = self
	self.guiElement.leftButtonElement.onClickCallback = self.setPreviousItem
	self.guiElement.rightButtonElement.onClickCallback = self.setNextItem
	self.guiElement.onClickCallback = self.onClick
	self.guiElement:setTexts(self:getGuiElementTexts())
	self:updateGuiElementValues()
end

function AIParameterSettingList:resetGuiElement()
	self.guiElement = nil
end

function AIParameterSettingList:getName()
	return self.name	
end

function AIParameterSettingList:getIsDisabled()
	return self.isDisabled
end

function AIParameterSettingList:onClick()
	
end

--- Raises an event and sends the callback string to the Settings controller class.
function AIParameterSettingList:raiseCallback(callbackStr)
	if self.class and self.class.raiseCallback and callbackStr then 
		self:debug("raised Callback %s",callbackStr)
		--- If the setting is bound to a setting, then call the specialization function with self as vehicle.
		if self.vehicle ~= nil then 
			self.class.raiseCallback(self.vehicle,callbackStr)
		else
			self.class:raiseCallback(callbackStr)
		end
	end
end

function AIParameterSettingList:debug(str,...)
	local name = string.format("%s: ",self.name)
	if self.vehicle == nil then
		CpUtil.debugFormat(CpUtil.DBG_HUD,name..str,...)
	else 
		CpUtil.debugVehicle(CpUtil.DBG_HUD,self.vehicle,name..str,...)
	end
end