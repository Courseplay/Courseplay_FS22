--- Selection list with values and texts.
---@class AIParameterSettingList : AIParameter
AIParameterSettingList = {}
local AIParameterSettingList_mt = Class(AIParameterSettingList, AIParameter)

function AIParameterSettingList.new(data,vehicle,class,customMt)
	local self = AIParameter.new(customMt or AIParameterSettingList_mt)
	self.type = AIParameterType.SELECTOR
	self.vehicle = vehicle
	self.klass = class
	self.name = data.name
	self.data = data
	if next(data.values) ~=nil then
		self.values = table.copy(data.values)
		self.texts = table.copy(data.texts)
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
	if data.defaultBool ~= nil then
		AIParameterSettingList.setValue(self,data.defaultBool)
		self:debug("set to default %s",tostring(data.defaultBool))
	end

	self.callbacks = data.callbacks
	self.disabledValuesFuncs = data.disabledValuesFuncs

	self.guiElementId = data.uniqueID

	self.guiElement = nil

	self.isDisabled = false
	self.isVisible = true
	self.setupDone = true
	return self
end

function AIParameterSettingList.getSpeedText(value)
	return string.format("%1d %s",g_i18n:getSpeed(value),g_i18n:getSpeedMeasuringUnit())
end

function AIParameterSettingList.getDistanceText(value)
	if g_i18n.useMiles then 
		return string.format("%.1f %s",value*3.28,g_i18n:getText("CP_unit_foot"))
	end
	return string.format("%.1f %s",value,g_i18n:getText("CP_unit_meter"))
end

function AIParameterSettingList.getAreaText(value)
	return g_i18n:formatArea(value, 1, true)
end

AIParameterSettingList.UNITS_TEXTS = {
	AIParameterSettingList.getSpeedText, --- km/h
	AIParameterSettingList.getDistanceText, --- m
	AIParameterSettingList.getAreaText, --- ha/arcs
	function (value) return string.format("%d", value) .. "%" end,			--- percent
	function (value) return string.format("%d", value) .. "°" end			--- degrees
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
		local text = unit and AIParameterSettingList.UNITS_TEXTS[unit] and AIParameterSettingList.UNITS_TEXTS[unit](value) or tostring(value)
		local text = textStr and string.format(textStr,value) or text
		table.insert(texts,text)
	end
end

--- Enriches texts with values of values, if they are not explicit declared. 
function AIParameterSettingList:enrichTexts(unit)
	for i,value in ipairs(self.values) do 
		local text = tostring(value)
		if unit then 
			text = text..AIParameterSettingList.UNITS_TEXTS[unit](value)
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
		self:validateCurrentValue()
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
	local disabledFunc = self.disabledValuesFuncs and self.disabledValuesFuncs[self.values[self.current]]
	if disabledFunc ~= nil and self:hasCallback(disabledFunc) then 
		if self:getCallback(disabledFunc) then
			self:debug("value %s is disabled",tostring(self.values[self.current]))
			local new = self:checkAndSetValidValue(self.current+1)
			self:setToIx(new)
			return
		end
	end
	self:debug("value %s is valid",tostring(self.values[self.current]))

end

--- Refresh the texts, if it depends on a changeable measurement unit.
--- For all units that are not an SI unit ...
function AIParameterSettingList:validateTexts()
	local unit = self.data.unit
	if unit then 
		local unitStrFunc = AIParameterSettingList.UNITS_TEXTS[unit]
		local fixedTexts = {}
		for ix,value in ipairs(self.values) do 
			local value = MathUtil.round(value,2)
			local text = unitStrFunc(value)
			local text = self.data.textStr and string.format(self.data.textStr,value) or text
			fixedTexts[ix] = text
		end
		self.texts = fixedTexts
	end
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
	setValueInternal(self, value, function(a, b)
		return MathUtil.equalEpsilon(a, b, self.data.incremental or 0.1) end)
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

--- Copy the value to another setting.
function AIParameterSettingList:copy(setting)
	if self.data.incremental and self.data.incremental ~= 1 then 
		self:setFloatValue(setting:getValue())
	else 
		self:setValue(setting:getValue())
	end
end

function AIParameterSettingList:getTitle()
	return self.title	
end

function AIParameterSettingList:getTooltip()
	return self.tooltip	
end

function AIParameterSettingList:setGenericGuiElementValues(guiElement)
	if guiElement.labelElement and guiElement.labelElement.setText then
		guiElement:setLabel(self:getTitle())
	end
	local toolTipElement = guiElement.elements[6]
	if toolTipElement then
		toolTipElement:setText(self:getTooltip())
	end
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
	self:validateTexts()
	self.guiElement = guiElement
	self.guiElement.target = self
	self.guiElement.onClickCallback = function(setting,state,element)
		setting:onClick(state)
		CpGuiUtil.debugFocus(element.parent)
		if not FocusManager:setFocus(element) then 
			element.focusActive = false
			FocusManager:setFocus(element)
		end
	end
	self.guiElement.leftButtonElement.target = self
	self.guiElement.rightButtonElement.target = self
	self.guiElement.leftButtonElement:setCallback("onClickCallback", "setPreviousItem")
	self.guiElement.rightButtonElement:setCallback("onClickCallback", "setNextItem")
	self.guiElement:setTexts(self:getGuiElementTexts())
	self:updateGuiElementValues()
	self.guiElement:setVisible(self:getIsVisible())
	self.guiElement:setDisabled(self:getIsDisabled())

--	local max = FocusManager.FIRST_LOCK
--	local min = 50
--	self.guiElement.scrollDelayDuration = MathUtil.clamp(max-#self.values*2.5,min,max)
end

function AIParameterSettingList:resetGuiElement()
	self.guiElement = nil
end

function AIParameterSettingList:getName()
	return self.name	
end

function AIParameterSettingList:getIsDisabled()
	if self:hasCallback(self.data.isDisabledFunc) then 
		return self:getCallback(self.data.isDisabledFunc)
	end
	return self.isDisabled
end

function AIParameterSettingList:getIsVisible()
	if self:hasCallback(self.data.isVisibleFunc) then 
		return self:getCallback(self.data.isVisibleFunc)
	end
	return self.isVisible
end

function AIParameterSettingList:onClick(state)
	local new = self:checkAndSetValidValue(state)
	self:setToIx(new)
end

--- Raises an event and sends the callback string to the Settings controller class.
function AIParameterSettingList:raiseCallback(callbackStr)
	if self.klass ~= nil and self.klass.raiseCallback and callbackStr then
		self:debug("raised Callback %s",callbackStr)
		--- If the setting is bound to a setting, then call the specialization function with self as vehicle.
		if self.vehicle ~= nil then 
			self.klass.raiseCallback(self.vehicle,callbackStr)
		else
			self.klass:raiseCallback(callbackStr)
		end
	end
end

function AIParameterSettingList:hasCallback(callbackStr)
	if self.klass ~= nil and callbackStr then
		if self.klass[callbackStr] ~= nil then 
			return true
		end
	end
end

function AIParameterSettingList:getCallback(callbackStr)
	if self:hasCallback(callbackStr) then
		if self.vehicle ~= nil then 
			return self.klass[callbackStr](self.vehicle)
		else
			return self.klass[callbackStr](self.klass)
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