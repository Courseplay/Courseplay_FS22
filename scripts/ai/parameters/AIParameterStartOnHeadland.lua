
--- Example AI job parameter, that is listed in the game menu.

---@class AIParameterStartOnHeadland
AIParameterStartOnHeadland = {
	START_ON_HEADLAND = 1,
	START_ON_UP_DOWN_ROWS = 2,
	translations = {
		'COURSEPLAY_HEADLAND_PASSES',
		'COURSEPLAY_UP_DOWN_ROWS',
	}
}
local AIParameterStartOnHeadland_mt = Class(AIParameterStartOnHeadland, AIParameter)

function AIParameterStartOnHeadland.new(customMt)
	local self = AIParameter.new(customMt or AIParameterStartOnHeadland_mt)
	self.type = AIParameterType.SELECTOR
	self.min = self.START_ON_HEADLAND
	self.max = self.START_ON_UP_DOWN_ROWS
	self.value  = self.min
	return self
end

function AIParameterStartOnHeadland:saveToXMLFile(xmlFile, key, usedModNames)
	xmlFile:setInt(key .. "#value", self.value)
end

function AIParameterStartOnHeadland:loadFromXMLFile(xmlFile, key)
	self.value = xmlFile:getInt(key .. "#value", self.value)
end

function AIParameterStartOnHeadland:readStream(streamId, connection)
	self:setValue(streamReadInt32(streamId))
end

function AIParameterStartOnHeadland:writeStream(streamId, connection)
	streamWriteInt32(streamId, self.value)
end

function AIParameterStartOnHeadland:setValue(value)
	self.value = value
end

function AIParameterStartOnHeadland:getValue()
	return self.value
end

function AIParameterStartOnHeadland:getString()
	return g_i18n:getText(self.translations[self.value])
end

function AIParameterStartOnHeadland:setNextItem()
	self.value = math.min(self.value+1,self.max)
end

function AIParameterStartOnHeadland:setPreviousItem()
	self.value = math.max(self.value-1,self.min)
end
