---@class DebugChannelEvent
DebugChannelEvent = {}
local DebugChannelEvent_mt = Class(DebugChannelEvent, Event)

InitEventClass(DebugChannelEvent, "DebugChannelEvent")

function DebugChannelEvent.emptyNew()
	return Event.new(DebugChannelEvent_mt)
end

function DebugChannelEvent.new(channel, value)
	local self = DebugChannelEvent.emptyNew()
	self.channel = channel
	self.value = value
	return self
end

function DebugChannelEvent:readStream(streamId, connection)
	self.channel = streamReadUInt8(streamId)
	self.value = streamReadBool(streamId)
	self:run(connection)
end

function DebugChannelEvent:writeStream(streamId, connection)
	streamWriteUInt8(streamId, self.channel)
	streamWriteBool(streamId, self.value or false)
end

-- Process the received event
function DebugChannelEvent:run(connection)
	CpDebug:setChannelActive(self.channel, self.value)
	if not connection:getIsServer() then
		-- event was received from a client, so we, the server broadcast it to all other clients now
		g_server:broadcastEvent(DebugChannelEvent.new(self.channel, self.value))
	end
end

function DebugChannelEvent.sendEvent(channel, value)
	if g_server ~= nil then
		g_server:broadcastEvent(DebugChannelEvent.new(channel, value))
	else
		g_client:getServerConnection():sendEvent(DebugChannelEvent.new(channel, value))
	end
end
