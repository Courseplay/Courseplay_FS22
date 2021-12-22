--- @class VehicleSettingEvent
VehicleSettingEvent = {}

local VehicleSettingEvent_mt = Class(VehicleSettingEvent, Event)

InitEventClass(VehicleSettingEvent, "VehicleSettingEvent")

function VehicleSettingEvent.emptyNew()
	return Event.new(VehicleSettingEvent_mt)
end

--- Creates a new Event
function VehicleSettingEvent.new(vehicle,settingIx,currentIx)
	local self = VehicleSettingEvent.emptyNew()
	self.vehicle = vehicle
	self.settingIx = settingIx
	self.currentIx = currentIx
	return self
end

--- Reads the serialized data on the receiving end of the event.
function VehicleSettingEvent:readStream(streamId, connection) -- wird aufgerufen wenn mich ein Event erreicht
	self.vehicle = NetworkUtil.readNodeObject(streamId)
	self.settingIx = streamReadUInt8(streamId)
	local setting = self.vehicle:getCpSettingByIndex(self.settingIx)
	setting:readStream(streamId,connection)
--	self.currentIx = streamReadUInt16(streamId)
	self:run(connection);
end

--- Writes the serialized data from the sender.
function VehicleSettingEvent:writeStream(streamId, connection)  -- Wird aufgrufen wenn ich ein event verschicke (merke: reihenfolge der Daten muss mit der bei readStream uebereinstimmen 
	NetworkUtil.writeNodeObject(streamId,self.vehicle)
	streamWriteUInt8(streamId,self.settingIx)

	local setting = self.vehicle:getCpSettingByIndex(self.settingIx)
	setting:writeStream(streamId,connection)

---	streamWriteUInt16(streamId,self.currentIx)
end

--- Runs the event on the receiving end of the event.
function VehicleSettingEvent:run(connection) -- wir fuehren das empfangene event aus
	if self.vehicle then 
--		self.vehicle:setCpSettingValue(self.settingIx,self.currentIx)
	end
	--- If the receiver was the client make sure every clients gets also updated.
	if not connection:getIsServer() then
		g_server:broadcastEvent(VehicleSettingEvent.new(self.vehicle,self.settingIx,self.currentIx), nil, connection, self.vehicle)
	end
end

function VehicleSettingEvent.sendEvent(vehicle,settingIx,currentIx)
	if g_server ~= nil then
		g_server:broadcastEvent(VehicleSettingEvent.new(vehicle,settingIx,currentIx), nil, nil, vehicle)
	else
		g_client:getServerConnection():sendEvent(VehicleSettingEvent.new(vehicle,settingIx,currentIx))
	end
end
