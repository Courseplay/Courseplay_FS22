--- Selection list with values and texts.
---@class AIParameterSettingList : AIParameter
AIParameterSettingList = {}
local AIParameterSettingList_mt = Class(AIParameterSettingList, AIParameter)

function AIParameterSettingList.new(data,customMt)
	local self = AIParameter.new(customMt or AIParameterSettingList_mt)
	self.type = AIParameterType.SELECTOR
	self.name = data.name
	if next(data.values) ~=nil then 
		self.values = data.values
		self.texts = data.texts
	else 
		self.values = {}
		self.texts = {}
		AIParameterSettingList.generateValues(self.values,self.texts,data.min,data.max,data.incremental)
	end
	-- index of the current value/text
	self.current = 1
	-- index of the previous value/text
	self.previous = 1
	return self
end

--- Generates numeric values and texts from min to max with incremental of inc or 1.
function AIParameterSettingList.generateValues(values,texts,min,max,inc)
	inc = inc or 1
	for i=min,max,inc do 
		table.insert(values,i)
		table.insert(texts,tostring(i))
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
	-- setting specific implementation in the derived classes
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
