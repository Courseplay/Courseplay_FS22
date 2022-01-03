--- This is the interface provided to Courseplay
-- Wraps the CourseGenerator which does not depend on the CP or Giants code.
-- all course generator related code dependent on CP/Giants functions go here
CourseGeneratorInterface = {}
---@param fieldPolygon table [{x, z}]
---@param startPosition table {x, z}
---@param isClockwise boolean
---@param workWidth number
---@param numberOfHeadlands number
function CourseGeneratorInterface.generate(fieldPolygon,
										   startPosition,
										   isClockwise,
										   workWidth,
										   turnRadius,
										   numberOfHeadlands,
										   startOnHeadland,
										   headlandCornerType,
										   headlandOverlapPercent,
										   centerMode,
										   rowDirection,
										   rowsToSkip,
										   rowsPerLand,
										   fieldMargin
)

	CourseGenerator.debug('Generating course, clockwise %s, width %.1f m, turn radius %.1f m, headlands %d, startOnHeadland %s',
			tostring(isClockwise), workWidth, turnRadius, numberOfHeadlands, tostring(startOnHeadland))
	CourseGenerator.debug('                   headland corner %d, headland overlap %d, center mode %d',
			headlandCornerType, headlandOverlapPercent, centerMode)
	CourseGenerator.debug('                   row direction %d, rows to skip %d, rows per land %d',
			rowDirection, rowsToSkip, rowsPerLand)

	--------------------------------------------------------------------------------------------------------------------
	-- Headland settings
	-----------------------------------------------------------------------------------------------------------------------
	-- ignore headland order setting when there's no headland
	local headlandFirst = startOnHeadland == CourseGenerator.HEADLAND_START_ON_HEADLAND or numberOfHeadlands == 0
	if headlandFirst then
		isClockwise = isClockwise == CourseGenerator.HEADLAND_CLOCKWISE
	else
		-- reverse clockwise when starting in the middle
		isClockwise = isClockwise == CourseGenerator.HEADLAND_COUNTERCLOCKWISE
	end
	local headlandSettings = {
		startLocation = CourseGenerator.pointToXy(startPosition),
		-- use some overlap between headland passes to get better results
		-- (=less fruit missed) at smooth headland corners
		overlapPercent = headlandOverlapPercent,
		nPasses = numberOfHeadlands,
		headlandFirst = headlandFirst,
		isClockwise = isClockwise,
		mode = numberOfHeadlands == 0 and CourseGenerator.HEADLAND_MODE_NONE or CourseGenerator.HEADLAND_MODE_NORMAL
	}
	local roundCorners = headlandCornerType == CourseGenerator.HEADLAND_CORNER_TYPE_ROUND
	local minSmoothAngle, maxSmoothAngle = CourseGeneratorInterface.setSmoothAngles(headlandSettings, headlandCornerType)

	--------------------------------------------------------------------------------------------------------------------
	-- Center settings
	-----------------------------------------------------------------------------------------------------------------------
	local centerSettings = {
		useBestAngle = rowDirection == CourseGenerator.ROW_DIRECTION_AUTOMATIC,
		useLongestEdgeAngle = rowDirection == CourseGenerator.ROW_DIRECTION_LONGEST_EDGE,
		rowAngle = 0,
		nRowsToSkip = rowsToSkip,
		mode = centerMode,
		nRowsPerLand = rowsPerLand or 6,
		pipeOnLeftSide = true
	}

	--------------------------------------------------------------------------------------------------------------------
	-- Detect islands
	-----------------------------------------------------------------------------------------------------------------------
	local islandNodes = Island.findIslands(Polygon:new(CourseGenerator.pointsToXy(fieldPolygon)))

	--------------------------------------------------------------------------------------------------------------------
	-- General settings
	-----------------------------------------------------------------------------------------------------------------------
	local minDistanceBetweenPoints = 0.5
	local doSmooth = true
	local islandBypassMode = Island.BYPASS_MODE_CIRCLE

	local field = {}
	field.boundary = Polygon:new(CourseGenerator.pointsToXy(fieldPolygon))
	field.boundary:calculateData()

	local status, ok = xpcall(generateCourseForField, function(err)
		printCallstack();
		return err
	end,
		field, workWidth, headlandSettings,
		minDistanceBetweenPoints,
		minSmoothAngle, maxSmoothAngle, doSmooth,
		roundCorners, turnRadius,
		islandNodes,
		islandBypassMode, centerSettings, fieldMargin
	)

	-- return on exception (but continue on not ok as that is just a warning)
	if not status then
		return status, ok
	end

	--removeRidgeMarkersFromLastTrack(field.course,
	--	vehicle.cp.courseGeneratorSettings.startOnHeadland:is(CourseGenerator.HEADLAND_START_ON_UP_DOWN_ROWS))
	local course = Course.createFromGeneratedCourse({}, field.course, workWidth, #field.headlandTracks, 1)
	course:setFieldPolygon(fieldPolygon)
	return status, ok, course
end

function CourseGeneratorInterface.setSmoothAngles(headlandSettings, headlandCornerType)
	local minSmoothAngle, maxSmoothAngle, roundCorners
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