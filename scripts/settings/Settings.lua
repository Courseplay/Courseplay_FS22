
---@class Setting
Setting = CpObject()

--- Interface for settings
--- @param name string name of this settings, will be used as an identifier in containers and XML
--- @param label string text ID in translations used as a label for this setting on the GUI
--- @param toolTip string text ID in translations used as a tooltip for this setting on the GUI
--- @param vehicle table vehicle, needed for vehicle specific settings for multiplayer syncs
function Setting:init(name, label, toolTip, vehicle, value)
	self.name = name
	self.label = label
	self.toolTip = toolTip
	self.value = value
	-- Required to send sync events for settings changes
	self.vehicle = vehicle
	self.syncValue = false
	-- override
	self.xmlKey = name
	self.xmlAttribute = '#value'
	self.events={}
	--self.debugMpChannel = courseplay.DBG_MULTIPLAYER
end

-- Get the current value
function Setting:get()
	return self.value
end

-- Is the current value same as the param?
function Setting:is(value)
	return self.value == value
end

function Setting:equals(value)
	return self.value == value
end

-- Get the current text to be shown on the UI
function Setting:getText()
	return tostring(self.value)
end

function Setting:getLabel()
	return g_i18n:getText(self.label) --courseplay:loc(self.label)
end

function Setting:getName()
	return self.name
end

function Setting:getParentName()
	return self.parentName
end

function Setting:getToolTip()
	return  g_i18n:getText(self.toolTip)
end

-- function only called from network to set synced setting
function Setting:setFromNetwork(value)
	self:set(value,true)
end

function Setting:getDebugString()
	return string.format('%s: %s', self.name, tostring(self:get()))
end

--- Set to a specific value
function Setting:set(value)
	self.value = value
	self:onChange()
end

function Setting:onChange()
	-- setting specific implementation in the derived classes
end

function Setting:getKey(parentKey)
	return parentKey .. '.' .. self.xmlKey .. self.xmlAttribute
end

function Setting:loadFromXml(xml, parentKey)
	-- override
end

function Setting:saveToXml(xml, parentKey)
	-- override
end

-- For settings where the valid values depend on other conditions, re-evaluate the validity of the
-- current setting (when for example changed the mode of the vehicle, is the current setting still valid for the new mode)
function Setting:validateCurrentValue()
	-- override
end

function Setting:setParent(name)
	self.parentName = name
end

-- remember the associated GUI element
function Setting:setGuiElement(element)
	self.guiElement = element
end

function Setting:getGuiElement()
	return self.guiElement
end

function Setting:hasGuiElement()
	return self.guiElement~=nil
end

--- Should this setting be disabled on the GUI?
function Setting:isDisabled()
	return false
end


--- Registers an event that synchronizes a value.
---@param eventFunc function Callback function run on the receiving end of the event.
---@param getValueFunc function Callback function to get the value, which needs synchronizing.
---@param readFunc function Reads the value data stream on the receiving end with this function.
---@param writeFunc function Writes the value data stream from the sender with this function.
function Setting:registerEvent(eventFunc,getValueFunc,readFunc,writeFunc)
	local ix = #self.events+1
	local event = {
		eventFunc = eventFunc,
		getValueFunc = getValueFunc,
		readFunc = readFunc,
		writeFunc = writeFunc,
		ix = ix
	}
	table.insert(self.events,event)
	return ix
end

--- Registers an event that synchronizes an Int value.
---@param eventFunc function
---@param getValueFunc function
function Setting:registerIntEvent(eventFunc,getValueFunc)
	return self:registerEvent(eventFunc,getValueFunc,streamReadInt32,streamWriteInt32)
end

--- Registers an event that synchronizes an Float value.
---@param eventFunc function
---@param getValueFunc function
function Setting:registerFloatEvent(eventFunc,getValueFunc)
	return self:registerEvent(eventFunc,getValueFunc,streamReadFloat32,streamWriteFloat32)
end

--- Registers an event that synchronizes an Boolean value.
---@param eventFunc function
---@param getValueFunc function
function Setting:registerBoolEvent(eventFunc,getValueFunc)
	return self:registerEvent(eventFunc,getValueFunc,streamReadBool,streamWriteBool)
end
--- Registers an event that requests a function call on the receiving end.
---@param eventFunc function
function Setting:registerFunctionEvent(eventFunc)
	return self:registerEvent(eventFunc)
end

--- Gets an event by it's id.
function Setting:getEvent(ix)
	return self.events[ix]
end

--- Raises an event by it's id to synchronize a value,
--- which is defined by a callback function.
function Setting:raiseEvent(eventIx,value)
	local event = self:getEvent(eventIx)
	value = event.getValueFunc and event.getValueFunc(self) or value
	if self.vehicle ~= nil then
	--	VehicleSettingEvent.sendEvent(self.vehicle,self,event,value)
	else
	--	GlobalSettingEvent.sendEvent(self,event,value)
	end
end

--- Setting debug.
---@param channel number debug channel
function Setting:debug(channel,...)
--	courseplay.debugFormat(channel,...)
end

function Setting:debugMp(...)
	self:debug(self.debugMpChannel,...)
end

function Setting:isMpDebugActive()
--	return courseplay.debugChannels[courseplay.DBG_MULTIPLAYER]
end

--- Debug for synchronizing on joining a game.
---@param value any the value that gets synchronized.
---@param valueName string the value name
function Setting:debugWriteStream(value,valueName)
	if self:isMpDebugActive() then
		self:debugMp("Write, container: %s, setting: %s, %s: %s",self.parentName,self.name,valueName or "value",tostring(value))
	end
end

--- Debug for synchronizing on joining a game.
---@param value any the value that gets synchronized.
---@param valueName string the value name
function Setting:debugReadStream(value,valueName)
	if self:isMpDebugActive() then
		self:debugMp("Read, container: %s, setting: %s, %s: %s",self.parentName,self.name,valueName or "value",tostring(value))
	end
end

--- Is synchronizing of this setting allowed.
function Setting:isSyncAllowed()
	return self.syncValue
end


---@class SettingList : Setting
SettingList = CpObject(Setting)

--- A setting that can have a predefined set of values
--- @param name string name of this settings, will be used as an identifier in containers and XML
--- @param label string text ID in translations used as a label for this setting on the GUI
--- @param toolTip string text ID in translations used as a tooltip for this setting on the GUI
--- @param vehicle table vehicle, needed for vehicle specific settings for multiplayer syncs
--- @param values table with the valid values
--- @param texts string[] name in the translation XML files describing the corresponding value
function SettingList:init(name, label, toolTip, vehicle, values, texts)
	Setting.init(self, name, label, toolTip, vehicle)
	self.values = values
	self.texts = texts
	-- index of the current value/text
	self.current = 1
	-- index of the previous value/text
	self.previous = 1

	self.DEFAULT_EVENT = self:registerIntEvent(self.setFromNetwork,self.getNetworkCurrentValue)
end

-- Get the current value
function SettingList:get()
	return self.values[self.current]
end

---@param seconds number if value changed within seconds than it should be considered invalid
---@return nil if value changed in the last seconds seconds, otherwise the current value
function SettingList:getIfNotChangedFor(seconds)
	if self:getSecondsSinceLastChange() > seconds then
		return self:get()
	else
		return nil
	end
end

-- Is the current value same as the param?
function SettingList:is(value)
	return self.values[self.current] == value
end

-- Get the current text key (for the logs, for example)
function SettingList:__tostring()
	return self.texts[self.current]
end

-- Get the current text
function SettingList:getText()
	return g_i18n:getText(self.texts[self.current])
end

--- Set the next value
function SettingList:setNext()
	local new = self:checkAndSetValidValue(self.current + 1)
	self:setToIx(new)
end

--- Set the previous value
function SettingList:setPrevious()
	local new = self:checkAndSetValidValue(self.current - 1)
	self:setToIx(new)
end

function SettingList:changeByX(x)
	local ix = 1
	if x<0 then
		ix = -1
	end
	local new = self:checkAndSetValidValue(self.current + ix)
	self:setToIx(new)
end

-- TODO: consolidate this with setNext()
function SettingList:next()
	self:setNext()
end

-- private function to set to the value at ix
function SettingList:setToIx(ix, noEventSend)
	if ix ~= self.current then
		self.previous = self.current
		self.current = ix
		self:onChange()
		self.lastChangeTimeMilliseconds = g_time
		if noEventSend == nil or noEventSend == false then
			if self:isSyncAllowed() then
				self:sendEvent()
			end
		end
	end
end

-- function only called from network to set synced setting
function SettingList:setFromNetwork(ix)
	if ix ~= self.current then
		self.previous = self.current
		self.current = ix
		self:onChange()
	end
end

--- Set to a specific value
function SettingList:set(value,noEventSend)
	local new
	-- find the value requested
	for i = 1, #self.values do
		if self.values[i] == value then
			new = self:checkAndSetValidValue(i)
			self:setToIx(new,noEventSend)
			return
		end
	end
end

function SettingList:checkAndSetValidValue(new)
	if new > #self.values then
		return 1
	elseif new < 1 then
		return #self.values
	else
		return new
	end
end

function SettingList:onChange()
	if self.guiElement then 
		self:updateGuiElement()
	end
	-- setting specific implementation in the derived classes
end

--- Helper functions for the case when used with a GUI multi text option element
function SettingList:getGuiElementTexts()
	local texts = {}
	for _, text in ipairs(self.texts) do
		table.insert(texts,g_i18n:getText(text))
	end
	return texts
end

function SettingList:getValueFromGuiElementState(state)
	return self.values[state]
end

function SettingList:getGuiElementState()
	return self:getGuiElementStateFromValue(self.values[self.current])
end

function SettingList:getGuiElementStateFromValue(value)
	for i = 1, #self.values do
		if self.values[i] == value then
			return i
		end
	end
	return nil
end

function SettingList:setFromGuiElement()
	if self.guiElement then
		self:setToIx(self.guiElement:getState())
	end
end

function SettingList:updateGuiElement()
	if self.guiElement and self.getGuiElementTexts then
		self.guiElement:setTexts(self:getGuiElementTexts())
		self.guiElement:setState(self:getGuiElementState())
	end
end

function SettingList:getKey(parentKey)
	return  self:getElementKey(parentKey) .. self.xmlAttribute
end

function SettingList:getElementKey(parentKey)
	return parentKey .. '.' .. self.xmlKey
end

function SettingList:loadFromXml(xml, parentKey)
	-- remember the value loaded from XML for those settings which aren't up to date when loading,
	-- for example the field numbers
	self.valueFromXml = getXMLInt(xml, self:getKey(parentKey))
	if self.valueFromXml then 
		self:set(self.valueFromXml,true)
	end
end

function SettingList:saveToXml(xml, parentKey)
	setXMLInt(xml, self:getKey(parentKey), Utils.getNoNil(self:get(),0))
end

---@return number seconds since last change
function SettingList:getSecondsSinceLastChange()
	return self:getMilliSecondsSinceLastChange() / 1000
end

---@return number milliseconds since last change
function SettingList:getMilliSecondsSinceLastChange()
	return (g_time - self.lastChangeTimeMilliseconds)
end

function SettingList:validateCurrentValue()
	local new = self:checkAndSetValidValue(self.current)
	self:setToIx(new,true)
end

function SettingList:getDebugString()
	-- replace % as this string goes through multiple formats (%% does not seem to work and I have no time to figure it out
	return string.format('%s: %s', self.name, string.gsub(self.texts[self.current], '%%', 'percent'))
end

function SettingList:onWriteStream(stream)
	local value =  self:getNetworkCurrentValue()
	self:debugWriteStream(value)
	streamWriteInt32(stream, value)
end

function SettingList:onReadStream(stream)
	local value = streamReadInt32(stream)
	self:debugReadStream(value)
	if value ~= nil then 
		self:setFromNetwork(value)
	end
end

function SettingList:getNetworkCurrentValue()
	return self.current
end

function SettingList:sendEvent()
	self:raiseEvent(self.DEFAULT_EVENT)
end

--- Generic boolean setting
---@class BooleanSetting : SettingList
BooleanSetting = CpObject(SettingList)

function BooleanSetting:init(name, label, toolTip, vehicle, texts)
	if not texts then
		texts = {
			'COURSEPLAY_DEACTIVATED',
			'COURSEPLAY_ACTIVATED'
		}
	end
	SettingList.init(self, name, label, toolTip, vehicle,
		{
			false,
			true
		}, texts)
	self.xmlAttribute = '#active'
end

function BooleanSetting:toggle()
	self:set(not self:get())
end

function BooleanSetting:changeByX(x)
	self:toggle()
end


function BooleanSetting:loadFromXml(xml, parentKey)
	local value = getXMLBool(xml, self:getKey(parentKey))
	if value ~= nil then
		self:set(value,true)
	end
end

function BooleanSetting:saveToXml(xml, parentKey)
	setXMLBool(xml, self:getKey(parentKey), self:get())
end

--- Generic Percentage setting from 1% to 100%
---@class PercentageSettingList : SettingList
PercentageSettingList = CpObject(SettingList)
function PercentageSettingList:init(name, label, toolTip, vehicle)
	local values = {}
	local texts = {}
	for i=1,100 do 
		values[i] = i
		texts[i] = i.."%"
	end
	SettingList.init(self, name, label, toolTip, vehicle,values, texts)
end

function PercentageSettingList:checkAndSetValidValue(new)
	if new <= #self.values and new > 0 then
		return new
	else
		return self.current
	end
end


--- Container for settings
--- @class SettingsContainer
SettingsContainer = CpObject()

function SettingsContainer:init(name,headerText)
	self.name = name
	self.headerText = headerText
	self.settings = {}
	self.settingsIx = 1
end

--- Add a setting which then can be addressed by its name like container['settingName'] or container.settingName
function SettingsContainer:addSetting(settingClass, ...)
	local s = settingClass(...)
	s.syncValue = true -- Only sync values that are part of a SettingsContainer
	s:setParent(self.name)
	self.settings[self.settingsIx] = s
	self.settingsIx = self.settingsIx +1
	self[s.name] = s
end

function SettingsContainer:saveToXML(xml, parentKey)
	for _, setting in ipairs(self.settings) do
		setting:saveToXml(xml, parentKey)
	end
end

function SettingsContainer:loadFromXML(xml, parentKey)
	for _, setting in ipairs(self.settings) do
		setting:loadFromXml(xml, parentKey)
	end
end

function SettingsContainer:validateCurrentValues()
	for k, setting in ipairs(self.settings) do
		setting:validateCurrentValue()
	end
end

--TODO: test if in pairs() or in ipairs() is needed, as ipairs would be safer as
--		I am not sure if the order is the same on Client and Server,
--		but doesn't seem to work at the moment

function SettingsContainer:onReadStream(stream)
	for k, setting in ipairs(self.settings) do
		if setting:isSyncAllowed() then 
			setting:onReadStream(stream)
		end
	end
end

function SettingsContainer:onWriteStream(stream)
	for k, setting in ipairs(self.settings) do
		if setting:isSyncAllowed() then 
			setting:onWriteStream(stream)
		end
	end
end


function SettingsContainer:debug(channel)
	for key, setting in ipairs(self.settings) do
		if setting.vehicle then
			--courseplay.debugVehicle(channel, setting.vehicle, setting:getDebugString())
		else
			--courseplay.debugFormat(channel, setting:getDebugString())
		end
	end
end

function SettingsContainer:iterate(lambda,...)
	for k, setting in ipairs(self.settings) do
		lambda(setting,...)
	end
end

function SettingsContainer:getHeaderText()
	return g_i18n:getText(self.headerText)
end



