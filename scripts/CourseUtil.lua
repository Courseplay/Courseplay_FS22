---@class CourseUtil
CourseUtil = {}
function CourseUtil.serializeWaypoints(course)
	local function serializeBool(bool)
		return bool and 'Y' or 'N'
	end

	local function serializeInt(number)
		return number and string.format('%d', number) or ''
	end

	local serializedWaypoints = '\n' -- (pure cosmetic)
	for _, p in ipairs(course.waypoints) do
		-- we are going to celebrate once we get rid of the cx, cz variables!
		local x, z = p.x or p.cx, p.z or p.cz
		local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z)
		local turn = p.turnStart and 'S' or (p.turnEnd and 'E' or '')
		local serializedWaypoint = string.format('%.2f %.2f %.2f;%.2f;%s;%s;',
			x, y, z, p.angle, serializeInt(p.speed), turn)
		serializedWaypoint = serializedWaypoint .. string.format('%s;%s;%s;%s;',
			serializeBool(p.rev), serializeBool(p.unload), serializeBool(p.wait), serializeBool(p.crossing))
		serializedWaypoint = serializedWaypoint .. string.format('%s;%s;%s;%s|\n',
			serializeInt(p.lane), serializeInt(p.ridgeMarker),
			serializeInt(p.headlandHeightForTurn), serializeBool(p.isConnectingTrack))
		serializedWaypoints = serializedWaypoints .. serializedWaypoint
	end
	return serializedWaypoints
end

function CourseUtil.deserializeWaypoints(serializedWaypoints)
	local function deserializeBool(str)
		if str == 'Y' then
			return true
		elseif str == 'N' then
			return false
		else
			return nil
		end
	end

	local waypoints = {}

	local lines = string.split(serializedWaypoints, '|')
	for _, line in ipairs(lines) do
		local p = {}
		local fields = string.split(line,';')
		p.x, p.y, p.z = string.getVector(fields[1])
		-- just skip empty lines
		if p.x then
			p.angle = tonumber(fields[2])
			p.speed = tonumber(fields[3])
			local turn = fields[4]
			p.turnStart = turn == 'S'
			p.turnEnd = turn == 'E'
			p.rev = deserializeBool(fields[5])
			p.unload = deserializeBool(fields[6])
			p.wait = deserializeBool(fields[7])
			p.crossing = deserializeBool(fields[8])
			p.lane = tonumber(fields[9])
			p.ridgeMarker = tonumber(fields[10])
			p.headlandHeightForTurn = tonumber(fields[11])
			p.isConnectingTrack = deserializeBool(fields[12])
			table.insert(waypoints, p)
		end
	end
	return waypoints
end

--- Saves a course.
---@param courseXml XmlFile
---@param key string
function CourseUtil.saveToXml(course,courseXml, key)
	courseXml:setValue(key .. '#name',course.name)
	courseXml:setValue(key  .. '#workWidth',course.workWidth or 0)
	courseXml:setValue(key  .. '#numHeadlands',course.numHeadlands or 0)
	courseXml:setValue(key  .. '#multiTools',course.multiTools or 0)
	courseXml:setValue(key  .. '.waypoints',CourseUtil.serializeWaypoints(course))
end

function CourseUtil.writeStream(course,streamId, connection)
	streamWriteString(streamId, course.name)
	streamWriteFloat32(streamId, course.workWidth or 0)
	streamWriteInt32(streamId, course.numHeadlands or 0 )
	streamWriteInt32(streamId, course.multiTools or 0)
	streamWriteString(streamId, CourseUtil.serializeWaypoints(course))
end

--- Loads a course.
---@param vehicle table
---@param courseXml XmlFile
---@param key string
function CourseUtil.createFromXml(vehicle, courseXml, key)
	local name = courseXml:getValue( key .. '#name')
	local workWidth = courseXml:getValue( key .. '#workWidth')
	local numHeadlands = courseXml:getValue( key .. '#numHeadlands')
	local multiTools = courseXml:getValue( key .. '#multiTools')
	local serializedWaypoints = courseXml:getValue( key .. '.waypoints')

	local course = Course(vehicle, CourseUtil.deserializeWaypoints(serializedWaypoints))
	course.name = name
	course.workWidth = workWidth
	course.numHeadlands = numHeadlands
	course.multiTools = multiTools

	CpUtil.debugVehicle(CpDebug.DBG_COURSES, vehicle, 'Course with %d waypoints loaded.', #course.waypoints)
	return course
end

function CourseUtil.createFromStream(streamId, connection)
	local name = streamReadString(streamId)
	local workWidth = streamReadFloat32(streamId)
	local numHeadlands = streamReadInt32(streamId)
	local multiTools = streamReadInt32(streamId)
	local serializedWaypoints = streamReadString(streamId)
	local course = Course(vehicle, CourseUtil.deserializeWaypoints(serializedWaypoints))
	course.name = name
	course.workWidth = workWidth
	course.numHeadlands = numHeadlands
	course.multiTools = multiTools

	CpUtil.debugVehicle(CpDebug.DBG_COURSES, vehicle, 'Course with %d waypoints loaded.', #course.waypoints)
	return course
end
