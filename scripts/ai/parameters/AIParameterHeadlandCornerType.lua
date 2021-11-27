
--- Example AI job parameter, that is listed in the game menu.

---@class AIParameterHeadlandCornerType
AIParameterHeadlandCornerType = {
	SMOOTH = 1,
	SHARP = 2,
	ROUND = 3,
	translations = {
		'COURSEPLAY_HEADLAND_CORNER_TYPE_SMOOTH',
		'COURSEPLAY_HEADLAND_CORNER_TYPE_SHARP',
		'COURSEPLAY_HEADLAND_CORNER_TYPE_ROUND'
	}
}
local AIParameterHeadlandCornerType_mt = Class(AIParameterHeadlandCornerType, AIParameter)

function AIParameterHeadlandCornerType.new(customMt)
	local self = AIParameter.new(customMt or AIParameterHeadlandCornerType_mt)
	self.type = AIParameterType.SELECTOR
	self.min = self.SMOOTH
	self.max = self.ROUND
	self.value  = self.min
	return self
end

function AIParameterHeadlandCornerType:saveToXMLFile(xmlFile, key, usedModNames)
	xmlFile:setInt(key .. "#value", self.value)
end

function AIParameterHeadlandCornerType:loadFromXMLFile(xmlFile, key)
	self.value = xmlFile:getInt(key .. "#value", self.value)
end

function AIParameterHeadlandCornerType:readStream(streamId, connection)
	self:setValue(streamReadInt32(streamId))
end

function AIParameterHeadlandCornerType:writeStream(streamId, connection)
	streamWriteInt32(streamId, self.value)
end

function AIParameterHeadlandCornerType:setValue(value)
	self.value = value
end

function AIParameterHeadlandCornerType:getValue()
	return self.value
end

function AIParameterHeadlandCornerType:getString()
	return g_i18n:getText(self.translations[self.value])
end

function AIParameterHeadlandCornerType:setNextItem()
	self.value = math.min(self.value+1,self.max)
end

function AIParameterHeadlandCornerType:setPreviousItem()
	self.value = math.max(self.value-1,self.min)
end
