--- @class GlobalSettingEvent
GlobalSettingEvent = {}
local GlobalSettingEvent_mt = Class(GlobalSettingEvent, Event)

InitEventClass(GlobalSettingEvent, "GlobalSettingEvent")

function GlobalSettingEvent.emptyNew()
	return Event.new(GlobalSettingEvent_mt)
end

--- Creates a new Event
function GlobalSettingEvent.new(settingIx)
	local self = GlobalSettingEvent.emptyNew()
	self.settingIx = settingIx
	return self
end

--- Reads the serialized data on the receiving end of the event.
function GlobalSettingEvent:readStream(streamId, connection) -- wird aufgerufen wenn mich ein Event erreicht
	self.settingIx = streamReadUInt8(streamId)
	local settings = g_Courseplay.globalSettings:getSettingsTable()
	local setting = settings[self.settingIx]
	setting:readStream(streamId, connection)
	self:run(connection);
end

--- Writes the serialized data from the sender.
function GlobalSettingEvent:writeStream(streamId, connection)  -- Wird aufgrufen wenn ich ein event verschicke (merke: reihenfolge der Daten muss mit der bei readStream uebereinstimmen 
	streamWriteUInt8(streamId,self.settingIx)
	local settings = g_Courseplay.globalSettings:getSettingsTable()
	local setting = settings[self.settingIx]
	setting:writeStream(streamId, connection)
end

--- Runs the event on the receiving end of the event.
function GlobalSettingEvent:run(connection) -- wir fuehren das empfangene event aus
	--- If the receiver was the client make sure every clients gets also updated.
	if not connection:getIsServer() then
		g_server:broadcastEvent(GlobalSettingEvent.new(self.settingIx), nil, connection, nil)
	end
end

function GlobalSettingEvent.sendEvent(settingIx)
	if g_server ~= nil then
		g_server:broadcastEvent(GlobalSettingEvent.new(settingIx), nil, nil, nil)
	else
		g_client:getServerConnection():sendEvent(GlobalSettingEvent.new(settingIx))
	end
end
