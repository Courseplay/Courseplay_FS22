
--- Example AI job parameter, that is listed in the game menu.

---@class AIParameterWorkWidth
AIParameterWorkWidth = {}
local AIParameterWorkWidth_mt = Class(AIParameterWorkWidth,AIParameter)

function AIParameterWorkWidth.new(customMt)
	local self = AIParameter.new(customMt or AIParameterWorkWidth_mt)
	self.type = AIParameterType.SELECTOR
	self.isValid = true
	self.value = 0
	self.incremental = 0.1
	self.max = 50

	return self
end

function AIParameterWorkWidth:saveToXMLFile(xmlFile, key, usedModNames)
	if self.value ~= nil then
		xmlFile:setFloat(key .. "#value", self.value)
	end
end

function AIParameterWorkWidth:loadFromXMLFile(xmlFile, key)
	self.value = xmlFile:getFloat(key .. "#value")
end

function AIParameterWorkWidth:readStream(streamId, connection)
	self.value = streamReadFloat32(streamId)
end

function AIParameterWorkWidth:writeStream(streamId, connection)
	streamWriteFloat32(streamId,self.value)
end

function AIParameterWorkWidth:getString()
	return string.format("%.2f",self.value)
end

function AIParameterWorkWidth:setNextItem()
	self.value = math.min(self.value+self.incremental,self.max)
end

function AIParameterWorkWidth:setPreviousItem()
	self.value = math.max(self.value-self.incremental,0)
end

function AIParameterWorkWidth:get()
	return self.value	
end

function AIParameterWorkWidth:set(value)
	self.value = value
end
