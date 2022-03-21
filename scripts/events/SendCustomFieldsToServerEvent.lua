--- Sends the custom field data from the client to the server.
--- The custom fields are then only used for the driving, for example the bale collector.
---@class SendCustomFieldsToServerEvent
SendCustomFieldsToServerEvent = {}
local SendCustomFieldsToServerEvent_mt = Class(SendCustomFieldsToServerEvent, Event)

InitEventClass(SendCustomFieldsToServerEvent, "SendCustomFieldsToServerEvent")

function SendCustomFieldsToServerEvent.emptyNew()
	return Event.new(SendCustomFieldsToServerEvent_mt)
end

function SendCustomFieldsToServerEvent.new(fields)
	local self = SendCustomFieldsToServerEvent.emptyNew()
	self.fields = fields
	return self
end

function SendCustomFieldsToServerEvent:readStream(streamId, connection)
	self.fields = {}
	local numFields = streamReadInt32(streamId)
	for _ = 1, numFields do 
		table.insert(self.fields, CustomField.createFromStream(streamId, connection))
	end
	self:run(connection)
end

function SendCustomFieldsToServerEvent:writeStream(streamId, connection)
	streamWriteInt32(streamId, #self.fields)
	for _, field in ipairs(self.fields) do 
		field:writeStream(streamId, connection)
	end
end

-- Process the received event
function SendCustomFieldsToServerEvent:run(connection)
	local uniqueUserId = g_currentMission.userManager:getUniqueUserIdByConnection(connection)
	g_customFieldManager:setFromClient(uniqueUserId, self.fields)
end

function SendCustomFieldsToServerEvent.sendEvent(fields)
	if g_server == nil then
		g_client:getServerConnection():sendEvent(SendCustomFieldsToServerEvent.new(fields))
	end
end
