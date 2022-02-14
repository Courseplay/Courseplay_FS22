--- Event called on joining a multiplayer from the server to the joining player.
--- Used for synchronizing global value.
---@class CpJoinEvent
local CpJoinEvent = {}
local CpJoinEvent_mt = Class(CpJoinEvent, Event)

InitEventClass(CpJoinEvent, "CpJoinEvent")

function CpJoinEvent.emptyNew()
	return Event.new(CpJoinEvent_mt)
end

--- Creates a new Event
function CpJoinEvent.new()
	local self = CpJoinEvent.emptyNew()
	
	return self
end

--- Reads the serialized data on the receiving end of the event.
function CpJoinEvent:readStream(streamId, connection) -- wird aufgerufen wenn mich ein Event erreicht
	CpJoinEvent.debug("readStream")
	local settings = g_Courseplay.globalSettings:getSettings()
	for i = 1, #settings do 
		if not settings[i]:getIsUserSetting() then
			settings[i]:readStream(streamId, connection)
		end
	end
	
	self:run(connection);
end

--- Writes the serialized data from the sender.
function CpJoinEvent:writeStream(streamId, connection)  -- Wird aufgrufen wenn ich ein event verschicke (merke: reihenfolge der Daten muss mit der bei readStream uebereinstimmen 
	CpJoinEvent.debug("writeStream")
	local settings = g_Courseplay.globalSettings:getSettings()
	for i = 1, #settings do 
		if not settings[i]:getIsUserSetting() then
			settings[i]:writeStream(streamId, connection)
		end
	end
end

--- Runs the event on the receiving end of the event.
function CpJoinEvent:run(connection) -- wir fuehren das empfangene event aus
	--- If the receiver was the client make sure every clients gets also updated.
	if not connection:getIsServer() then

	end
end

function CpJoinEvent.debug(str, ...)
	CpUtil.debugFormat(CpDebug.DBG_MULTIPLAYER, "CpJoinEvent: "..str,...)
end

local function sendEvent(baseMission,connection, x, y, z, viewDistanceCoeff)
	-- body
	if connection ~= nil then 
		connection:sendEvent(CpJoinEvent.new())
	end
end

FSBaseMission.onConnectionFinishedLoading = Utils.appendedFunction(FSBaseMission.onConnectionFinishedLoading,sendEvent)