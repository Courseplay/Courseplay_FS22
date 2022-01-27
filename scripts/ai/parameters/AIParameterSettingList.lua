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
	--- We keep the config data, as we might need to fall back to it.
	--- For example to reenable specific values after they were deactivated in self:refresh().  
	self.data = data
	self.textInputAllowed = data.textInputAllowed
	if next(data.values) ~=nil then
		self.values = table.copy(data.values)
		self.texts = table.copy(data.texts)
	else
		self.data.values = {}
		self.data.texts = {}
		AIParameterSettingList.generateValues(self,self.data.values,self.data.texts,data.min,data.max,data.incremental,data.unit)
		self.values = table.copy(self.data.values)
		if self.data.texts ~= nil then
			self.texts = table.copy(self.data.texts)
		end
		data.textInputAllowed = true
	end
	self.textInputAllowed = data.textInputAllowed
--	self:debug("textInputAllowed: %s",tostring(self.textInputAllowed))
	self.title = data.title
	self.tooltip = data.tooltip

	-- index of the current value/text
	self.current =  1
	-- index of the previous value/text
	self.previous = 1

	if self.texts == nil or next(self.texts) == nil then
		self.data.texts = {}
		AIParameterSettingList.enrichTexts(self,self.data.texts,data.unit)
		self.texts = table.copy(self.data.texts)
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
	return string.format("%.1f %s",g_i18n:getSpeed(value),g_i18n:getSpeedMeasuringUnit())
end

function AIParameterSettingList.getDistanceText(value)
	if g_i18n.useMiles then 
		return string.format("%.1f %s",value*AIParameterSettingList.FOOT_FACTOR,g_i18n:getText("CP_unit_foot"))
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

AIParameterSettingList.UNITS_CONVERSION = {
	function (value) return g_i18n.useMiles and value/AIParameterSettingList.MILES_FACTOR or value end,
	function (value) return g_i18n.useMiles and value/AIParameterSettingList.FOOT_FACTOR or value end,
	function (value) return g_i18n.useAcre and value/AIParameterSettingList.ACRE_FACTOR or value end
}

AIParameterSettingList.MILES_FACTOR = 0.62137
AIParameterSettingList.FOOT_FACTOR = 3.28
AIParameterSettingList.ACRE_FACTOR = 2.4711
AIParameterSettingList.INPUT_VALUE_THRESHOLD = 2
--- Generates numeric values and texts from min to max with incremental of inc or 1.
---@param values table
---@param texts table
---@param min number
---@param max number
---@param inc number
---@param unit number
function AIParameterSettingList:generateValues(values,texts,min,max,inc,unit)
	inc = inc or 1
	for i=min,max,inc do 
		table.insert(values,i)
		local value = MathUtil.round(i,2)
		local text = unit and AIParameterSettingList.UNITS_TEXTS[unit] and AIParameterSettingList.UNITS_TEXTS[unit](value) or tostring(value)
		table.insert(texts,text)
	end
end

--- Enriches texts with values of values, if they are not explicit declared. 
function AIParameterSettingList:enrichTexts(texts,unit)
	for i,value in ipairs(self.values) do 
		local text = tostring(value)
		if unit then 
			text = AIParameterSettingList.UNITS_TEXTS[unit](value)
		end
		texts[i] = text
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

function AIParameterSettingList:isValueDisabled(value)
	local disabledFunc = self.disabledValuesFuncs and self.disabledValuesFuncs[value]
	if disabledFunc ~= nil and self:hasCallback(disabledFunc) then 
		if self:getCallback(disabledFunc) then 
			self:debug("value %s is disabled",tostring(value))
			return true
		end 
	end
--	self:debug("value %s is valid",tostring(value))
end

--- Excludes deactivated values from the current values and texts tables.
function AIParameterSettingList:refresh()
	self.values = {}
	self.texts = {}
	for ix,v in ipairs(self.data.values) do 
		if not self:isValueDisabled(v) then
			table.insert(self.values,v)
			table.insert(self.texts,self.data.texts[ix])
		end	
	end
	self:validateCurrentValue()
end

function AIParameterSettingList:validateCurrentValue()
	local new = self:checkAndSetValidValue(self.current)
	self:setToIx(new)
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

function AIParameterSettingList:saveToRawXMLFile(xmlFile, key)
	setXMLInt(xmlFile,key.."#value",self.current)
end

function AIParameterSettingList:loadFromXMLFile(xmlFile, key)
	self:setToIx(xmlFile:getInt(key .. "#value", self.current))
end

function AIParameterSettingList:loadFromRawXMLFile(xmlFile, key)
	self:setToIx(getXMLInt(xmlFile,key .. "#value") or 1)
end

function AIParameterSettingList:readStream(streamId, connection)
	self:setToIx(streamReadInt32(streamId))
end

function AIParameterSettingList:writeStream(streamId, connection)
	streamWriteInt32(streamId, self.current)
end

--- Sets the value.
---@param self AIParameterSettingList
---@param value number
---@param comparisonFunc function
---@return boolean value is not valid and could not be set.
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
	return value ~= new
end

--- Sets a float value relative to the incremental.
---@param value number
---@return boolean value is not valid and could not be set.
function AIParameterSettingList:setFloatValue(value)
	return setValueInternal(self, value, function(a, b)
		return MathUtil.equalEpsilon(a, b, self.data.incremental or 0.1) end)
end

--- Gets the closest value ix and absolute difference, relative to the value searched for.
---@param value number
---@return number closest ix
---@return number difference
function AIParameterSettingList:getClosestIx(value)
	-- find the value requested
	local closestIx = 0
	local closestDifference = math.huge
	for i = 1, #self.values do
		local v = self.values[i]
		local d = math.abs(v-value)
		if d < closestDifference then
			closestIx = i
			closestDifference = d
		end
	end
	return closestIx,closestDifference
end

--- Sets a value.
---@param value number
---@return boolean value is not valid and could not be set.
function AIParameterSettingList:setValue(value)
	return setValueInternal(self, value, function(a, b)  return a == b end)
end

function AIParameterSettingList:setDefault()
	if self:hasCallback(self.data.setDefaultFunc) then 
		self:getCallback(self.data.setDefaultFunc)
		self:debug("set to default by extern function.")
		return
	end

	if self.data.default ~=nil then
		AIParameterSettingList.setFloatValue(self,self.data.default)
		self:debug("set to default %s",self.data.default)
		return
	end
	if self.data.defaultBool ~= nil then
		AIParameterSettingList.setValue(self,self.data.defaultBool)
		self:debug("set to default %s",tostring(self.data.defaultBool))
		return
	end
	self:setToIx(1)
end

--- Gets a specific value.
function AIParameterSettingList:getValue()
	return self.values[self.current]
end

function AIParameterSettingList:getString()
	return self.texts[self.current] or ""
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
	if self.textInputAllowed then
		self:registerMouseInputEvent()
	end
	local max = FocusManager.FIRST_LOCK
	local min = 50
	self.guiElement.scrollDelayDuration = MathUtil.clamp(max-#self.values*2.5,min,max)
end

--- Adds text input option to the setting.
function AIParameterSettingList:registerMouseInputEvent()
	local function mouseClick(element,superFunc,posX, posY, isDown, isUp, button, eventUsed)
		local eventUsed = superFunc(element,posX, posY, isDown, isUp, button, eventUsed)
	--	CpUtil.debugFormat(CpDebug.DBG_HUD,"Settings text pressed, pre event used: %s",tostring(eventUsed))
		local x, y = unpack(element.textElement.absPosition)
		local width, height = unpack(element.textElement.absSize)
		local cursorInElement = GuiUtils.checkOverlayOverlap(posX, posY, x, y, width, height)
		if not eventUsed and cursorInElement then 
			if isDown and button == Input.MOUSE_BUTTON_LEFT  then 
				element.mouseDown = true
			end
			if isUp and button == Input.MOUSE_BUTTON_LEFT and element.mouseDown then
				element.mouseDown = false
				if not FocusManager:setFocus(element) then 
					element.focusActive = false
					FocusManager:setFocus(element)
				end
				self:showInputTextDialog()
			end
		end
		return eventUsed
	end
	self.oldMouseEvent = self.guiElement.mouseEvent
	self.guiElement.mouseEvent = Utils.overwrittenFunction(self.guiElement.mouseEvent, mouseClick)
end

--- Used for text input settings.
function AIParameterSettingList:showInputTextDialog()
	g_gui:showTextInputDialog({
		disableFilter = true,
		callback = function (self,value,clickOk)
			if clickOk and value ~= nil then
				local v = value:match("-%d[%d.,]*")
				v = v or value:match("%d[%d.,]*")
				v = v and tonumber(v)
				if v then
					local unit = self.data.unit
					if unit then 
						local unitStrFunc = AIParameterSettingList.UNITS_CONVERSION[unit]
						if unitStrFunc then
							v = unitStrFunc(v)
						end
					end
					local ix,diff = self:getClosestIx(v)
					if diff < self.INPUT_VALUE_THRESHOLD then
						self:setToIx(ix)
					else 
						self:setDefault()
					end
				else 
					self:setDefault()
				end
				if self.guiElement then
					if not FocusManager:setFocus(self.guiElement) then 
						self.guiElement.focusActive = false
						FocusManager:setFocus(self.guiElement)
					end
				end
			end
		end,
		maxCharacters = 7,
		target = self,
		dialogPrompt = self.data.title,
		confirmText = g_i18n:getText("button_ok"),
	})
end

function AIParameterSettingList:resetGuiElement()
	if self.guiElement then
		if self.oldMouseEvent then
			self.guiElement.mouseEvent = self.oldMouseEvent
		end
	end

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

function AIParameterSettingList:getCanBeChanged()
	return not self:getIsDisabled()
end

function AIParameterSettingList:getIsVisible()
	if self:hasCallback(self.data.isVisibleFunc) then 
		return self:getCallback(self.data.isVisibleFunc)
	end
	return self.isVisible
end

function AIParameterSettingList:getIsUserSetting()
	return self.data.isUserSetting	
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