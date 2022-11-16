
--- Fieldwork Hud page
---@class CpHudPageElement : CpHudElement
---@field private parent CpBaseHud
CpFieldWorkHudPageElement = {}
local CpFieldWorkHudPageElement_mt = Class(CpFieldWorkHudPageElement, CpHudPageElement)

function CpFieldWorkHudPageElement.new(overlay, parentHudElement, customMt)
	local self = CpHudPageElement.new(overlay, parentHudElement, customMt or CpFieldWorkHudPageElement_mt)
	return self
end

function CpFieldWorkHudPageElement:setupElements(baseHud, vehicle, lines, wMargin, hMargin)
	
    --- Time remaining text
    local x, y = unpack(lines[6].left)
    self.timeRemainingText = CpTextHudElement.new(self , x , y, CpBaseHud.defaultFontSize)
    
	--- Clear course button.
    local width, height = getNormalizedScreenValues(18, 18)
    local imageFilename = Utils.getFilename('img/iconSprite.dds', g_Courseplay.BASE_DIRECTORY)
    local clearCourseOverlay = CpGuiUtil.createOverlay({width, height},
                                                {imageFilename, GuiUtils.getUVs(unpack(CpBaseHud.uvs.clearCourseSymbol))}, 
                                                CpBaseHud.OFF_COLOR,
                                                CpBaseHud.alignments.bottomRight)
    self.clearCourseBtn = CpHudButtonElement.new(clearCourseOverlay, self)
    local x, y = unpack(lines[6].right)
    x = x - 2*width - wMargin/2 - wMargin/4
    self.clearCourseBtn:setPosition(x, y)
    self.clearCourseBtn:setCallback("onClickPrimary", vehicle, function (vehicle)
        if vehicle:hasCpCourse() and not vehicle:getIsCpActive() then
            vehicle:resetCpCoursesFromGui()
        end
    end)
    
    --- Toggle waypoint visibility.
    local width, height = getNormalizedScreenValues(20, 20)
    local imageFilename = Utils.getFilename('img/iconSprite.dds', g_Courseplay.BASE_DIRECTORY)
    local courseVisibilityOverlay = CpGuiUtil.createOverlay({width, height},
                                                        {imageFilename, GuiUtils.getUVs(unpack(CpBaseHud.uvs.eye))}, 
                                                        CpBaseHud.OFF_COLOR,
                                                        CpBaseHud.alignments.bottomRight)
    self.courseVisibilityBtn = CpHudButtonElement.new(courseVisibilityOverlay, self)
    local _, y = unpack(lines[6].right)
    y = y - hMargin/16
    x = x - width - wMargin/4
    self.courseVisibilityBtn:setPosition(x, y)
    self.courseVisibilityBtn:setCallback("onClickPrimary", vehicle, function (vehicle)
        vehicle:getCpSettings().showCourse:setNextItem()
    end)

	
    --- Work width
    self.workWidthBtn = baseHud:addLineTextButton(self, 3, CpBaseHud.defaultFontSize, 
                                                vehicle:getCourseGeneratorSettings().workWidth)

	--- Tool offset x
	self.toolOffsetXBtn = baseHud:addLineTextButton(self, 2, CpBaseHud.defaultFontSize, 
												vehicle:getCpSettings().toolOffsetX)

	--- Lane offset
    self.laneOffsetBtn = baseHud:addRightLineTextButton(self, 5, CpBaseHud.defaultFontSize, 
	function (vehicle)
		vehicle:getCpLaneOffsetSetting():setNextItem()
	end, vehicle)


     --- Course name
    self.courseNameBtn = baseHud:addLeftLineTextButton(self, 4, CpBaseHud.defaultFontSize, 
                                                        function(vehicle)
                                                            baseHud:openCourseGeneratorGui(vehicle)
                                                        end, vehicle)              

	--- Waypoint progress
	self.waypointProgressBtn = baseHud:addRightLineTextButton(self, 4, CpBaseHud.defaultFontSize, 
														function(vehicle)
															baseHud:openCourseManagerGui(vehicle)
														end, vehicle)
                                                        
    CpGuiUtil.addCopyCourseBtn(self, baseHud, vehicle, lines, wMargin, hMargin, 1)    												
end

function CpFieldWorkHudPageElement:update(dt)
	CpFieldWorkHudPageElement:superClass().update(self, dt)

end

function CpFieldWorkHudPageElement:updateContent(vehicle, status)

    self.timeRemainingText:setTextDetails(status:getTimeRemainingText())

    self.courseNameBtn:setTextDetails(vehicle:getCurrentCpCourseName())

	self.clearCourseBtn:setVisible(vehicle:hasCpCourse() and not vehicle:getIsCpActive())

	self.waypointProgressBtn:setTextDetails(status:getWaypointText())

	local laneOffset = vehicle:getCpLaneOffsetSetting()
    self.laneOffsetBtn:setVisible(laneOffset:getCanBeChanged())
    self.laneOffsetBtn:setTextDetails(laneOffset:getString())

    local workWidth = vehicle:getCourseGeneratorSettings().workWidth
    self.workWidthBtn:setTextDetails(workWidth:getTitle(), workWidth:getString())
    self.workWidthBtn:setVisible(workWidth:getIsVisible())

	local toolOffsetX = vehicle:getCpSettings().toolOffsetX
    local text = toolOffsetX:getIsDisabled() and CpBaseHud.automaticText or toolOffsetX:getString()
    self.toolOffsetXBtn:setTextDetails(toolOffsetX:getTitle(), text)
    self.toolOffsetXBtn:setDisabled(toolOffsetX:getIsDisabled())

	if vehicle:hasCpCourse() then 
        self.courseVisibilityBtn:setVisible(true)
        local value = vehicle:getCpSettings().showCourse:getValue()
        if value == CpVehicleSettings.SHOW_COURSE_DEACTIVATED then 
            self.courseVisibilityBtn:setColor(unpack(CpBaseHud.OFF_COLOR))
        elseif value == CpVehicleSettings.SHOW_COURSE_START_STOP then 
            self.courseVisibilityBtn:setColor(unpack(CpBaseHud.SEMI_ON_COLOR))
        else 
            self.courseVisibilityBtn:setColor(unpack(CpBaseHud.ON_COLOR))
        end
    else 
        self.courseVisibilityBtn:setVisible(false)
    end

    CpGuiUtil.updateCopyBtn(self, vehicle, status)
end

function CpFieldWorkHudPageElement:isStartingPointBtnDisabled(vehicle)
    return false
end

function CpFieldWorkHudPageElement:getStartingPointBtnText(vehicle)
    return vehicle:getCpStartingPointSetting():getString()
end