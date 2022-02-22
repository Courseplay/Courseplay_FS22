---@class CoursesEvent
CoursesEvent = {}
local CoursesEvent_mt = Class(CoursesEvent, Event)

InitEventClass(CoursesEvent, "CoursesEvent")

function CoursesEvent.emptyNew()
	return Event.new(CoursesEvent_mt)
end

function CoursesEvent.new(vehicle, courses)
	local self = CoursesEvent.emptyNew()
	self.vehicle = vehicle;
	self.courses = courses
	return self
end

function CoursesEvent:readStream(streamId, connection)
	self.vehicle = NetworkUtil.getObject(streamReadInt32(streamId))
	CpUtil.debugVehicle(CpDebug.DBG_MULTIPLAYER,self.vehicle,"course event: read stream")
	local nCourses = streamReadUInt8(streamId)
	self.courses = {}
	for _ = 1, nCourses do
		table.insert(self.courses, Course.createFromStream(self.vehicle,streamId, connection))
	end
	self:run(connection)
end

function CoursesEvent:writeStream(streamId, connection)
	CpUtil.debugVehicle(CpDebug.DBG_MULTIPLAYER,self.vehicle,"course event: write stream")
	streamWriteInt32(streamId, NetworkUtil.getObjectId(self.vehicle))
	if self.courses == nil then self.courses = {} end
	streamWriteUInt8(streamId, #self.courses)
	for _, course in ipairs(self.courses) do
		course:writeStream(self.vehicle,streamId, connection)
	end
end

-- Process the received event
function CoursesEvent:run(connection)
	if self.vehicle then
		if #self.courses > 0 then
			CpUtil.debugVehicle(CpDebug.DBG_MULTIPLAYER,self.vehicle,"course event: set course from stream (%s).",self.courses[1].name)
			self.vehicle:setCpCoursesFromNetworkEvent(self.courses)
		else
			CpUtil.debugVehicle(CpDebug.DBG_MULTIPLAYER,self.vehicle,"course event: reset courses.")
			self.vehicle:resetCpCourses()
		end
	end
	if not connection:getIsServer() then
		-- event was received from a client, so we, the server broadcast it to all other clients now
		CpUtil.debugVehicle(CpDebug.DBG_MULTIPLAYER,self.vehicle,"sending courses event to all clients.")
		g_server:broadcastEvent(CoursesEvent.new(self.vehicle, self.courses), nil, connection, self.vehicle)
	end
end

function CoursesEvent.sendEvent(vehicle, courses)
	CpUtil.debugVehicle(CpDebug.DBG_MULTIPLAYER, vehicle, "sending courses event.")
	if g_server ~= nil then
		g_server:broadcastEvent(CoursesEvent.new(vehicle, courses), nil, nil, vehicle)
	else
		g_client:getServerConnection():sendEvent(CoursesEvent.new(vehicle, courses))
	end
end

--- Updates the course name on save for the server and other players.
---@class CourseSaveNameEvent
CourseSaveNameEvent = {}
local CourseSaveNameEvent_mt = Class(CourseSaveNameEvent, Event)

InitEventClass(CourseSaveNameEvent, "CourseSaveNameEvent")

function CourseSaveNameEvent.emptyNew()
	return Event.new(CourseSaveNameEvent_mt)
end

function CourseSaveNameEvent.new(vehicle, courseName)
	local self = CourseSaveNameEvent.emptyNew()
	self.vehicle = vehicle;
	self.courseName = courseName
	return self
end

function CourseSaveNameEvent:readStream(streamId, connection) 
	self.vehicle = NetworkUtil.readNodeObject(streamId)
	CpUtil.debugVehicle(CpDebug.DBG_MULTIPLAYER,self.vehicle,"course save name event: read stream")
	self.courseName = streamReadString(streamId)
	
	self:run(connection)
end

function CourseSaveNameEvent:writeStream(streamId, connection)
	CpUtil.debugVehicle(CpDebug.DBG_MULTIPLAYER,self.vehicle,"course save name event: write stream")
	NetworkUtil.writeNodeObject(streamId, self.vehicle)
	streamWriteString(streamId, self.courseName)
end

-- Process the received event
function CourseSaveNameEvent:run(connection)
	if self.vehicle then
		self.vehicle:setCpCourseName(self.courseName)
		CpUtil.debugVehicle(CpDebug.DBG_MULTIPLAYER,self.vehicle,"set course name %s.", self.courseName)
	end
	if not connection:getIsServer() then
		-- event was received from a client, so we, the server broadcast it to all other clients now
		CpUtil.debugVehicle(CpDebug.DBG_MULTIPLAYER,self.vehicle,"sending course save name event to all clients.")
		g_server:broadcastEvent(CourseSaveNameEvent.new(self.vehicle, self.courseName), nil, connection, self.vehicle)
	end
end

function CourseSaveNameEvent.sendEvent(vehicle, courseName)
	CpUtil.debugVehicle(CpDebug.DBG_MULTIPLAYER, vehicle, "sending course save name event.")
	if g_server ~= nil then
		g_server:broadcastEvent(CourseSaveNameEvent.new(vehicle, courseName), nil, nil, vehicle)
	else
		g_client:getServerConnection():sendEvent(CourseSaveNameEvent.new(vehicle, courseName))
	end
end