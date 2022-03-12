--- This is the interface provided to Courseplay
-- Wraps the CourseGenerator which does not depend on the CP or Giants code.
-- all course generator related code dependent on CP/Giants functions go here
CourseGeneratorInterface = {}
---@param fieldPolygon table [{x, z}]
---@param startPosition table {x, z}
---@param isClockwise boolean
---@param workWidth number
---@param numberOfHeadlands number
---@param rowsToSkip number when turning to the next row, skip nRowsToSkip and continue working there. This allows
--- for a bigger turning radius
---@param leaveSkippedRowsUnworked boolean normally, if rowsToSkip > 0, the vehicle will cover all rows, including the
--- skipped ones, for example, on the first run work on the odd rows, then on the even ones. When leaveSkippedRowsUnworked
--- is true, it will not return to work on the skipped rows, will only work on every rowsToSkip + 1 row.
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
										   manualRowAngleDeg,
										   rowsToSkip,
										   leaveSkippedRowsUnworked,
										   rowsPerLand,
										   islandBypassMode,
										   fieldMargin,
										   multiTools,
										   pipeOnLeftSide
)
	CourseGenerator.debug('Generating course, clockwise %s, width %.1f m, turn radius %.1f m, headlands %d, startOnHeadland %s',
			tostring(isClockwise), workWidth, turnRadius, numberOfHeadlands, tostring(startOnHeadland))
	CourseGenerator.debug('                   headland corner %d, headland overlap %d, center mode %d',
			headlandCornerType, headlandOverlapPercent, centerMode)
	CourseGenerator.debug('                   row direction %d, rows to skip %d, rows per land %d',
			rowDirection, rowsToSkip, rowsPerLand)
	CourseGenerator.debug('					  multiTools %d, pipe on left %s',
			multiTools, pipeOnLeftSide)


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

	--------------------------------------------------------------------------------------------------------------------
	-- Center settings
	-----------------------------------------------------------------------------------------------------------------------
	local centerSettings = {
		useBestAngle = rowDirection == CourseGenerator.ROW_DIRECTION_AUTOMATIC,
		useLongestEdgeAngle = rowDirection == CourseGenerator.ROW_DIRECTION_LONGEST_EDGE,
		rowAngle = CourseGenerator.fromCpAngleDeg(manualRowAngleDeg),
		nRowsToSkip = rowsToSkip,
		leaveSkippedRowsUnworked = leaveSkippedRowsUnworked,
		mode = centerMode,
		nRowsPerLand = rowsPerLand or 6,
		pipeOnLeftSide = pipeOnLeftSide
	}

	--------------------------------------------------------------------------------------------------------------------
	-- Detect islands
	-----------------------------------------------------------------------------------------------------------------------
	local islandNodes = Island.findIslands(Polygon:new(CourseGenerator.pointsToXy(fieldPolygon)))

	--------------------------------------------------------------------------------------------------------------------
	-- General settings
	-----------------------------------------------------------------------------------------------------------------------
	local minDistanceBetweenPoints = 0.5

	local field = {}
	field.boundary = Polygon:new(CourseGenerator.pointsToXy(fieldPolygon))
	field.boundary:calculateData()

	--- Multiplies the workWidth with the number of targeted vehicles.
	workWidth = workWidth * multiTools

	local status, ok = xpcall(generateCourseForField, function(err)
		printCallstack();
		return err
	end,
		field, workWidth, headlandSettings,
		minDistanceBetweenPoints,
		headlandCornerType,
		headlandCornerType == CourseGenerator.HEADLAND_CORNER_TYPE_ROUND,
		turnRadius,
		islandNodes,
		islandBypassMode, centerSettings, fieldMargin
	)

	-- return on exception (but continue on not ok as that is just a warning)
	if not status then
		return status, ok
	end

	--removeRidgeMarkersFromLastTrack(field.course,
	--	vehicle.cp.courseGeneratorSettings.startOnHeadland:is(CourseGenerator.HEADLAND_START_ON_UP_DOWN_ROWS))
	local course = Course.createFromGeneratedCourse({}, field.course, workWidth, #field.headlandTracks, multiTools)
	course:setFieldPolygon(fieldPolygon)
	return status, ok, course
end

--- Generates a vine course, where the fieldPolygon are the start/end of the vine node.
---@param fieldPolygon table
---@param workWidth number
---@param turnRadius number
---@param manualRowAngleDeg number
---@param rowsToSkip number
---@param multiTools number
function CourseGeneratorInterface.generateVineCourse(
	fieldPolygon,
	workWidth,
	turnRadius,
	manualRowAngleDeg,
	rowsToSkip,
	multiTools
)
	
	return CourseGeneratorInterface.generate(
		fieldPolygon,
		{x = fieldPolygon[1].x, z = fieldPolygon[1].z},
		true,
		workWidth,
		turnRadius,
		0,
		false,
		CpCourseGeneratorSettings.HEADLAND_CORNER_TYPE_SHARP,
		0,
		CpCourseGeneratorSettings.CENTER_MODE_UP_DOWN,
		CpCourseGeneratorSettings.ROW_DIRECTION_MANUAL,
		manualRowAngleDeg,
		rowsToSkip,
		true,
		0,
		false,
		-workWidth/2,
		multiTools,
		false
	)
					
end

