--- @class GlobalSettingEvent
GlobalSettingEvent = {}
local GlobalSettingEvent_mt = Class(GlobalSettingEvent, Event)

InitEventClass(GlobalSettingEvent, "GlobalSettingEvent")

function GlobalSettingEvent.emptyNew()
	return Event.new(GlobalSettingEvent_mt)
end

--- Creates a new Event
function GlobalSettingEvent.new(settingIx,currentIx)
	local self = GlobalSettingEvent.emptyNew()
	self.settingIx = settingIx
	self.currentIx = currentIx
	return self
end

--- Reads the serialized data on the receiving end of the event.
function GlobalSettingEvent:readStream(streamId, connection) -- wird aufgerufen wenn mich ein Event erreicht
	self.settingIx = streamReadUInt8(streamId)
	local setting = g_Courseplay.globalSettings:getSettingByIndex(self.settingIx)
	setting:readStream(streamId, connection)
--	self.currentIx = streamReadUInt16(streamId)
	self:run(connection);
end

--- Writes the serialized data from the sender.
function GlobalSettingEvent:writeStream(streamId, connection)  -- Wird aufgrufen wenn ich ein event verschicke (merke: reihenfolge der Daten muss mit der bei readStream uebereinstimmen 
	streamWriteUInt8(streamId,self.settingIx)
	local setting = g_Courseplay.globalSettings:getSettingByIndex(self.settingIx)
	setting:writeStream(streamId, connection)
--	streamWriteUInt16(streamId,self.currentIx)
end

--- Runs the event on the receiving end of the event.
function GlobalSettingEvent:run(connection) -- wir fuehren das empfangene event aus
--	g_Courseplay.globalSettings:setSettingValueFromNetwork(self.settingIx,self.currentIx)
	--- If the receiver was the client make sure every clients gets also updated.
	if not connection:getIsServer() then
		g_server:broadcastEvent(GlobalSettingEvent.new(self.settingIx,self.currentIx), nil, connection, nil)
	end
end

function GlobalSettingEvent.sendEvent(settingIx,currentIx)
	if g_server ~= nil then
		g_server:broadcastEvent(GlobalSettingEvent.new(settingIx,currentIx), nil, nil, nil)
	else
		g_client:getServerConnection():sendEvent(GlobalSettingEvent.new(settingIx,currentIx))
	end
end
