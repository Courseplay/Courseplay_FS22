--- @class VehicleSettingEvent
VehicleSettingEvent = {}

local VehicleSettingEvent_mt = Class(VehicleSettingEvent, Event)

InitEventClass(VehicleSettingEvent, "VehicleSettingEvent")

function VehicleSettingEvent.emptyNew()
	return Event.new(VehicleSettingEvent_mt)
end

--- Creates a new Event
function VehicleSettingEvent.new(vehicle,settingIx)
	local self = VehicleSettingEvent.emptyNew()
	self.vehicle = vehicle
	self.settingIx = settingIx
	return self
end

--- Reads the serialized data on the receiving end of the event.
function VehicleSettingEvent:readStream(streamId, connection) -- wird aufgerufen wenn mich ein Event erreicht
	self.vehicle = NetworkUtil.readNodeObject(streamId)
	self.settingIx = streamReadUInt8(streamId)
	local settings = self.vehicle:getCpSettingsTable(self.settingIx)
	local setting = settings[self.settingIx]
	setting:readStream(streamId,connection)
	self:run(connection);
end

--- Writes the serialized data from the sender.
function VehicleSettingEvent:writeStream(streamId, connection)  -- Wird aufgrufen wenn ich ein event verschicke (merke: reihenfolge der Daten muss mit der bei readStream uebereinstimmen 
	NetworkUtil.writeNodeObject(streamId,self.vehicle)
	streamWriteUInt8(streamId,self.settingIx)
	local settings = self.vehicle:getCpSettingsTable(self.settingIx)
	local setting = settings[self.settingIx]
	setting:writeStream(streamId,connection)
end

--- Runs the event on the receiving end of the event.
function VehicleSettingEvent:run(connection) -- wir fuehren das empfangene event aus
	--- If the receiver was the client make sure every clients gets also updated.
	if not connection:getIsServer() then
		g_server:broadcastEvent(VehicleSettingEvent.new(self.vehicle,self.settingIx), nil, connection, self.vehicle)
	end
end

function VehicleSettingEvent.sendEvent(vehicle,settingIx)
	if g_server ~= nil then
		g_server:broadcastEvent(VehicleSettingEvent.new(vehicle,settingIx), nil, nil, vehicle)
	else
		g_client:getServerConnection():sendEvent(VehicleSettingEvent.new(vehicle,settingIx))
	end
end
