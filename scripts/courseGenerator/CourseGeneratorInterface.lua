--- This is the interface provided to Courseplay
-- Wraps the CourseGenerator which does not depend on the CP or Giants code.
-- all course generator related code dependent on CP/Giants functions go here
CourseGeneratorInterface = {}
CourseGeneratorInterface.logger = Logger('CourseGeneratorInterface')

---@param fieldPolygon table [{x, z}]
---@param startPosition table {x, z}
---@param vehicle table
---@param settings CpCourseGeneratorSettings
function CourseGeneratorInterface.generate(fieldPolygon,
                                           startPosition,
                                           vehicle,
                                           settings
)
    local field = CourseGenerator.Field('', 0, CpMathUtil.pointsFromGame(fieldPolygon))

    local context = CourseGenerator.FieldworkContext(field, settings.workWidth:getValue() * settings.multiTools:getValue(),
            AIUtil.getTurningRadius(vehicle), settings.numberOfHeadlands:getValue())
    local rowPatternNumber = settings.centerMode:getValue()
    if rowPatternNumber == CourseGenerator.RowPattern.ALTERNATING and settings.rowsToSkip:getValue() == 0 then
        context:setRowPattern(CourseGenerator.RowPatternAlternating())
    elseif rowPatternNumber == CourseGenerator.RowPattern.ALTERNATING and settings.rowsToSkip:getValue() > 0 then
        context:setRowPattern(CourseGenerator.RowPatternSkip(settings.rowsToSkip:getValue(), false))
    elseif rowPatternNumber == CourseGenerator.RowPattern.SPIRAL then
        -- TODO: add from inside/outside
        context:setRowPattern(CourseGenerator.RowPatternSpiral(settings.centerClockwise:getValue(), false))
    elseif rowPatternNumber == CourseGenerator.RowPattern.LANDS then
        -- TODO: auto fill clockwise from self:isPipeOnLeftSide(vehicle)?
        context:setRowPattern(CourseGenerator.RowPatternLands(settings.centerClockwise:getValue(), settings.rowsPerLand:getValue()))
    elseif rowPatternNumber == CourseGenerator.RowPattern.RACETRACK then
        context:setRowPattern(CourseGenerator.RowPatternRacetrack(settings.rowsToSkip:getValue()))
    end

    context:setStartLocation(startPosition.x, -startPosition.z)
    context:setFieldCornerRadius(settings.fieldCornerRadius:getValue())
    context:setHeadlandFirst(settings.startOnHeadland:getValue())
    context:setHeadlandClockwise(settings.headlandClockwise:getValue())
    context:setHeadlandOverlap(settings.headlandOverlapPercent:getValue())
    context:setSharpenCorners(settings.sharpenCorners:getValue())
    context:setHeadlandsWithRoundCorners(settings.headlandsWithRoundCorners:getValue())
    context:setAutoRowAngle(settings.autoRowAngle:getValue())
    -- the Course Generator UI uses the geographical direction angles (0 - North, 90 - East, etc), convert it to
    -- the mathematical angle (0 - x+, 90 - y+, etc)
    context:setRowAngle(math.rad(-(settings.manualRowAngleDeg:getValue() - 90)))
    context:setBypassIslands(settings.bypassIslands:getValue())

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

    local course = Course.createFromGeneratedCourse(nil, generatedCourse, settings.workWidth:getValue(),
			#generatedCourse:getHeadlands(), settings.multiTools:getValue())
    course:setFieldPolygon(fieldPolygon)
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
