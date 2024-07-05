--- This is the interface provided to Courseplay
-- Wraps the CourseGenerator which does not depend on the CP or Giants code.
-- all course generator related code dependent on CP/Giants functions go here
CourseGeneratorInterface = {}
CourseGeneratorInterface.logger = Logger('CourseGeneratorInterface')

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
                                           rowPatternNumber,
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
    local field = CourseGenerator.Field('', 0, CpMathUtil.pointsFromGame(fieldPolygon))

    local context = CourseGenerator.FieldworkContext(field, workWidth * multiTools, turnRadius, numberOfHeadlands)
    if rowPatternNumber == CourseGenerator.RowPattern.ALTERNATING then
        context:setRowPattern(CourseGenerator.RowPatternAlternating())
    elseif rowPatternNumber == CourseGenerator.RowPattern.SKIP then
        context:setRowPattern(CourseGenerator.RowPatternSkip(rowsToSkip, leaveSkippedRowsUnworked))
    elseif rowPatternNumber == CourseGenerator.RowPattern.SPIRAL then
        -- TODO: add center clockwise for first param
        context:setRowPattern(CourseGenerator.RowPatternSpiral(true, rowsToSkip))
    elseif rowPatternNumber == CourseGenerator.RowPattern.LANDS then
        context:setRowPattern(CourseGenerator.RowPatternLands(rowsPerLand))
    elseif rowPatternNumber == CourseGenerator.RowPattern.RACETRACK then
        context:setRowPattern(CourseGenerator.RowPatternRacetrack(rowsToSkip))
    end

    context:setStartLocation(startPosition.x, -startPosition.z)
    context:setHeadlandFirst(startOnHeadland):setHeadlandClockwise(isClockwise)
    context:setSharpenCorners(true)
    context:setHeadlandsWithRoundCorners(headlandCornerType and numberOfHeadlands or 0)
    -- the Course Generator UI uses the geographical direction angles (0 - North, 90 - East, etc), convert it to
    -- the mathematical angle (0 - x+, 90 - y+, etc)
    context:setAutoRowAngle(rowDirection):setRowAngle(math.rad(-(manualRowAngleDeg - 90)))
    context:setBypassIslands(islandBypassMode)

    --------------------------------------------------------------------------------------------------------------------
    -- General settings
    -----------------------------------------------------------------------------------------------------------------------
    local status, generatedCourse = xpcall(
            function()
                return CourseGenerator.FieldworkCourse(context)
            end,
            function(err)
                printCallstack();
                return err
            end
    )


    -- return on exception or if the result is not usable
    if not status or generatedCourse == nil then
        return false
    end

    CourseGeneratorInterface.logger:debug('Generated course: %d/%d headland/center waypoints',
            #generatedCourse:getHeadlandPath(), #generatedCourse:getCenterPath())

    local course = Course.createFromGeneratedCourse(nil, generatedCourse:getPath(), workWidth,
			#generatedCourse:getHeadlands(), multiTools)
    course:setFieldPolygon(fieldPolygon)
    CourseGeneratorInterface.logger:debug('%s', tostring(course))
    return true, course
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
        startingPoint,
        workWidth,
        turnRadius,
        manualRowAngleDeg,
        rowsToSkip,
        multiTools
)

    return CourseGeneratorInterface.generate(
            fieldPolygon,
            startingPoint,
            true,
            workWidth,
            turnRadius,
            0,
            false,
            CpCourseGeneratorSettings.HEADLAND_CORNER_TYPE_SHARP,
            0,
            CourseGenerator.RowPattern.ALTERNATING,
            CpCourseGeneratorSettings.ROW_DIRECTION_MANUAL,
            manualRowAngleDeg,
            rowsToSkip,
            true,
            0,
            false,
            0,
            multiTools,
            false
    )

end
