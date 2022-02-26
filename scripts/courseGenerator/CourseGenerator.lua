--- Setting up packages
CourseGenerator = {}

-- Distance of waypoints on the generated track in meters
CourseGenerator.waypointDistance = 5

-- These numbers must match the COURSEPLAY_DIRECTION_* texts in the translation files
CourseGenerator.ROW_DIRECTION_NORTH = 1
CourseGenerator.ROW_DIRECTION_EAST = 2
CourseGenerator.ROW_DIRECTION_SOUTH = 3
CourseGenerator.ROW_DIRECTION_WEST = 4
CourseGenerator.ROW_DIRECTION_AUTOMATIC = 5
CourseGenerator.ROW_DIRECTION_LONGEST_EDGE = 6
CourseGenerator.ROW_DIRECTION_MANUAL = 7

CourseGenerator.trackDirectionRanges = {
	{ angle =  0  },
	{ angle =  1 * math.pi / 16,  text = 'COURSEPLAY_DIRECTION_N' },
	{ angle =  3 * math.pi / 16,  text = 'COURSEPLAY_DIRECTION_NNE' },
	{ angle =  5 * math.pi / 16,  text = 'COURSEPLAY_DIRECTION_NE' },
	{ angle =  7 * math.pi / 16,  text = 'COURSEPLAY_DIRECTION_ENE' },
	{ angle =  9 * math.pi / 16,  text = 'COURSEPLAY_DIRECTION_E' },
	{ angle = 11 * math.pi / 16,  text = 'COURSEPLAY_DIRECTION_ESE' },
	{ angle = 13 * math.pi / 16,  text = 'COURSEPLAY_DIRECTION_SE' },
	{ angle = 15 * math.pi / 16,  text = 'COURSEPLAY_DIRECTION_SSE' },
	{ angle = 17 * math.pi / 16,  text = 'COURSEPLAY_DIRECTION_S' },
	{ angle = 19 * math.pi / 16,  text = 'COURSEPLAY_DIRECTION_SSW' },
	{ angle = 21 * math.pi / 16,  text = 'COURSEPLAY_DIRECTION_SW' },
	{ angle = 23 * math.pi / 16,  text = 'COURSEPLAY_DIRECTION_WSW' },
	{ angle = 25 * math.pi / 16,  text = 'COURSEPLAY_DIRECTION_W' },
	{ angle = 27 * math.pi / 16,  text = 'COURSEPLAY_DIRECTION_WNW' },
	{ angle = 29 * math.pi / 16,  text = 'COURSEPLAY_DIRECTION_NW' },
	{ angle = 31 * math.pi / 16,  text = 'COURSEPLAY_DIRECTION_NNW' },
	{ angle = 32 * math.pi / 16,  text = 'COURSEPLAY_DIRECTION_N' },
}

-- corners of a field block
CourseGenerator.BLOCK_CORNER_BOTTOM_LEFT = 1
CourseGenerator.BLOCK_CORNER_BOTTOM_RIGHT = 2
CourseGenerator.BLOCK_CORNER_TOP_RIGHT = 3
CourseGenerator.BLOCK_CORNER_TOP_LEFT = 4

-- starting location
CourseGenerator.STARTING_LOCATION_MIN = 1
CourseGenerator.STARTING_LOCATION_SW_LEGACY = 1
CourseGenerator.STARTING_LOCATION_NW_LEGACY = 2
CourseGenerator.STARTING_LOCATION_NE_LEGACY = 3
CourseGenerator.STARTING_LOCATION_SE_LEGACY = 4
CourseGenerator.STARTING_LOCATION_NEW_COURSEGEN_MIN = 5
CourseGenerator.STARTING_LOCATION_VEHICLE_POSITION = 5
CourseGenerator.STARTING_LOCATION_LAST_VEHICLE_POSITION = 6
CourseGenerator.STARTING_LOCATION_SW = 7
CourseGenerator.STARTING_LOCATION_NW = 8
CourseGenerator.STARTING_LOCATION_NE = 9
CourseGenerator.STARTING_LOCATION_SE = 10
CourseGenerator.STARTING_LOCATION_SELECT_ON_MAP = 11
CourseGenerator.STARTING_LOCATION_MAX = 11

-- headland modes
CourseGenerator.HEADLAND_MODE_NONE = 1
-- 0-n headland rows all around the field and up/down rows in the middle
CourseGenerator.HEADLAND_MODE_NORMAL = 2
-- 0-n headland rows on the short edge, maximum possible number of
-- headland rows on the long edge covering the entire field, now up/down rows
-- in the middle.
CourseGenerator.HEADLAND_MODE_NARROW_FIELD = 3
-- 0-n headland rows on two opposite ends of the field, up/down rows between.
CourseGenerator.HEADLAND_MODE_TWO_SIDE = 4

CourseGenerator.headlandModeTexts = { 'none', 'normal', 'narrow', 'two side'}

CourseGenerator.HEADLAND_CLOCKWISE = 1
CourseGenerator.HEADLAND_COUNTERCLOCKWISE = 2

CourseGenerator.HEADLAND_START_ON_HEADLAND = 1
CourseGenerator.HEADLAND_START_ON_UP_DOWN_ROWS = 2


-- headland turn modes
CourseGenerator.HEADLAND_CORNER_TYPE_SMOOTH = 1
CourseGenerator.HEADLAND_CORNER_TYPE_SHARP = 2
CourseGenerator.HEADLAND_CORNER_TYPE_ROUND = 3
CourseGenerator.headlandCornerTypeTexts = {'smooth', 'sharp', 'round'}

-- Up/down mode is a regular up/down pattern, may skip rows between for wider turns

CourseGenerator.CENTER_MODE_UP_DOWN = 1

-- Spiral mode: the center is split into multiple blocks, one block
-- is not more than 10 rows wide. Each block is then worked in a spiral
-- fashion from the outside to the inside, see below:

--  ----- 1 ---- < -------  \
--  ----- 3 ---- < -------  |
--  ----- 5 ---- < -------  |
--  ----- 6 ---- > -------  | Block 1
--  ----- 4 ---- > -------  |
--  ----- 2 ---- > -------  /
--  ----- 7 ---- < -------  \
--  ----- 9 ---- < -------  |
--  -----11 ---- < -------  | Block 2
--  -----12 ---- > -------  |
--  -----10 ---- > -------  |
--  ----- 8 ---- > -------  /
CourseGenerator.CENTER_MODE_SPIRAL = 2

-- Circular mode, (for now) the area is split into multiple blocks which are then worked one by one. Work in each
-- block starts around the middle, skipping a maximum of four rows to avoid 180 turns and working the block in
-- a circular, racetrack like pattern.
-- Depending on the number of rows, there may be a few of them left at the end which will need to be worked in a
-- regular up/down pattern
--  ----- 2 ---- > -------     \
--  ----- 4 ---- > -------     |
--  ----- 6 ---- > -------     |
--  ----- 8 ---- > -------     | Block 1
--  ----- 1 ---- < -------     |
--  ----- 3 ---- < -------     |
--  ----- 5 ---- < ------      |
--  ----- 7 ---- < -------     /
--  -----10 ---- > -------    \
--  -----12 ---- > -------     |
--  ----- 9 ---- < -------     | Block 2
--  -----11 ---- < -------     /
CourseGenerator.CENTER_MODE_CIRCULAR = 3

-- Lands mode, making a break through the field and progressively working
-- outwards in a counterclockwise spiral fashion
--  ----- 5 ---- < -------  \
--  ----- 3 ---- < -------  |
--  ----- 1 ---- < -------  |
--  ----- 2 ---- > -------  | Block 1
--  ----- 4 ---- > -------  |
--  ----- 6 ---- > -------  /
--  -----11 ---- < -------  \
--  ----- 9 ---- < -------  |
--  ----- 7 ---- < -------  | Block 2
--  ----- 8 ---- > -------  |
--  -----10 ---- > -------  |
--  -----12 ---- > -------  /
CourseGenerator.CENTER_MODE_LANDS = 4

CourseGenerator.centerModeTexts = {'up/down', 'spiral', 'circular', 'lands'}
CourseGenerator.CENTER_MODE_MIN = CourseGenerator.CENTER_MODE_UP_DOWN
CourseGenerator.CENTER_MODE_MAX = CourseGenerator.CENTER_MODE_LANDS

CourseGenerator.RIDGEMARKER_NONE = 0
CourseGenerator.RIDGEMARKER_LEFT = 1
CourseGenerator.RIDGEMARKER_RIGHT = 2

-- Distance of waypoints on the generated track in meters
CourseGenerator.waypointDistance = 5
--- Minimum radius in meters where a lane change on the headland is allowed. This is to ensure that
--- we only change lanes on relatively straight sections of the headland (not around corners)
CourseGenerator.headlandLaneChangeMinRadius = 20
--- No lane change allowed on the headland if there is a corner ahead within this distance in meters
CourseGenerator.headlandLaneChangeMinDistanceToCorner = 20
--- No lane change allowed on the headland if there is a corner behind within this distance in meters
CourseGenerator.headlandLaneChangeMinDistanceFromCorner = 10

CourseGenerator.cornerTypeText = {
	'COURSEPLAY_HEADLAND_CORNER_TYPE_SMOOTH',
	'COURSEPLAY_HEADLAND_CORNER_TYPE_SHARP',
	'COURSEPLAY_HEADLAND_CORNER_TYPE_ROUND' }


function CourseGenerator.isOrdinalDirection( startingLocation )
	return startingLocation >= CourseGenerator.STARTING_LOCATION_SW and
		startingLocation <= CourseGenerator.STARTING_LOCATION_SE
end

--- Debug print, will either just call print when running standalone
--  or use the CP debug channel when running in the game.
function CourseGenerator.debug( ... )
	if CourseGenerator.isRunningInGame() then
		-- TODO: debug channel
		print( string.format( ... ))
	else
		print( string.format( ... ))
		io.stdout:flush()
	end
end

function CourseGenerator.info( ... )
	if CourseGenerator.isRunningInGame() then
		-- TODO: debug channel (info)
		print( string.format( ... ))
	else
		print( string.format( ... ))
		io.stdout:flush()
	end
end

--- Return true when running in the game
-- used by file and log functions to determine how exactly to do things,
-- for example, io.flush is not available from within the game.
--
function CourseGenerator.isRunningInGame()
	return g_currentMission ~= nil and not g_currentMission.mock;
end

function CourseGenerator.getCurrentTime()
	if CourseGenerator.isRunningInGame() then
		return g_currentMission.time
	else
		return os.time()
	end
end
--- Function to convert between CP/Giants coordinate representations
-- and the course generator conventional x/y coordinates.
--
function CourseGenerator.pointsToXy( points )
	local result = {}
	for _, point in ipairs( points ) do
		table.insert( result, {x = point.x, y = -point.z})
	end
	return result
end

function CourseGenerator.pointsToXz( points )
	local result = {}
	for _, point in ipairs( points) do
		table.insert( result, {x = point.x, z = -point.y})
	end
	return result
end

--- Convert an array of points from x/y to x/z in place (also keeping other attributes)
function CourseGenerator.pointsToXzInPlace(points)
	for _, point in ipairs(points) do
		point.z = -point.y
		-- wipe y as it is a different coordinate in this system
		point.y = nil
	end
	return points
end

--- Convert an array of points from x/z to x/y in place (also keeping other attributes)
function CourseGenerator.pointsToXyInPlace(points)
	for _, point in ipairs(points) do
		point.y = -point.z
		point.z = nil
	end
	return points
end

function CourseGenerator.pointToXy( point )
	return({ x = point.x or point.cx, y = - ( point.z or point.cz )})
end

function CourseGenerator.pointToXz( point )
	return({ x = point.x, z = -point.y })
end

	--- Convert our angle representation (measured from the x axis up in radians)
-- into CP's, where 0 is to the south, to our negative y axis.
--
function CourseGenerator.toCpAngleDeg( angle )
	local a = math.deg( angle ) + 90
	if a > 180 then
		a = a - 360
	end
	return a
end

function CourseGenerator.toCpAngle( angle )
	local a = angle + math.pi / 2
	if a > math.pi then
		a = a - 2 * math.pi
	end
	return a
end


--- Convert the Courseplay angle to the Cartesian representation
function CourseGenerator.fromCpAngleDeg(angleDeg)
	local a = angleDeg - 90
	if a < 0 then
		a = 360 + a
	end
	return math.rad(a)
end

function CourseGenerator.fromCpAngle(angle)
	local a = angle - math.pi / 2
	if a < 0 then
		a = 2 * math.pi + a
	end
	return a
end

--- Find the starting location coordinates when the user wants to start
-- at a corner. Use the appropriate bounding box coordinates of the field
-- as the starting location and let the generator find the closest part
-- of the field which will be the corner as long as it is more or less
-- rectangular. Oddly shaped fields may produce odd results.
function CourseGenerator.getStartingLocation( boundary, startingCorner )
	local x, y = 0, 0
	if startingCorner == CourseGenerator.STARTING_LOCATION_NW then
		x, y = boundary.boundingBox.minX, boundary.boundingBox.maxY
	elseif startingCorner == CourseGenerator.STARTING_LOCATION_NE then
		x, y = boundary.boundingBox.maxX, boundary.boundingBox.maxY
	elseif startingCorner == CourseGenerator.STARTING_LOCATION_SE then
		x, y = boundary.boundingBox.maxX, boundary.boundingBox.minY
	elseif startingCorner == CourseGenerator.STARTING_LOCATION_SW then
		x, y = boundary.boundingBox.minX, boundary.boundingBox.minY
	end
	return { x = x, y = y }
end

function CourseGenerator.getCompassDirectionText( gameAngleDeg )
	local compassAngle = math.rad( CourseGenerator.getCompassAngleDeg( gameAngleDeg ))
	for r = 2, #CourseGenerator.trackDirectionRanges, 1 do
		if compassAngle >= CourseGenerator.trackDirectionRanges[ r - 1 ].angle and
			compassAngle < CourseGenerator.trackDirectionRanges[ r ].angle then
			return CourseGenerator.trackDirectionRanges[ r ].text
		end
	end
end

--- Convert the game direction angles to compass direction
function CourseGenerator.getCompassAngleDeg( gameAngleDeg )
	return ( 360 + gameAngleDeg - 90 ) % 360
end

function CourseGenerator.setCornerParameters(headlandSettings, headlandCornerType)
	local minSmoothAngle, maxSmoothAngle
	if headlandCornerType == CourseGenerator.HEADLAND_CORNER_TYPE_SMOOTH then
		-- do not generate turns on headland
		headlandSettings.minHeadlandTurnAngleDeg = 150
		-- use smoothing instead
		minSmoothAngle, maxSmoothAngle = math.rad(25), math.rad(150)
	elseif headlandCornerType == CourseGenerator.HEADLAND_CORNER_TYPE_ROUND then
		-- generate turns for whatever is left after rounding the corners, for example
		-- the transitions between headland and up/down rows.
		headlandSettings.minHeadlandTurnAngleDeg = 75
		minSmoothAngle, maxSmoothAngle = math.rad(25), math.rad(75)
	else
		-- generate turns over 75 degrees
		headlandSettings.minHeadlandTurnAngleDeg = 60
		-- smooth only below 75 degrees
		minSmoothAngle, maxSmoothAngle = math.rad(25), math.rad(60)
	end
	return minSmoothAngle, maxSmoothAngle
end