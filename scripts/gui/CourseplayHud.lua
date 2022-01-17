---@class CourseplayHud
CourseplayHud = CpObject()

function CourseplayHud:init(vehicle)
    self.vehicle = vehicle
    self.background = Overlay.new(g_baseUIFilename, 0, 0, 1, 1)
    self.background:setUVs(g_colorBgUVs)
    self.background:setColor(0, 0, 0, 0.7)
    self.x = 0.4
    self.y = 0.06
    self.width = 0.2
    self.height = 0.05
    self.lines = 1
    self.margin = 0.005
    self.textSize = 0.02
end

function CourseplayHud:mouseEvent(posX, posY, isDown, isUp, button)
    if button == 1 and isDown and
            posX > self.x and posX < self.x + self.width and
            posY > self.y and posY < self.y + self.height then
        self.vehicle:cpStartStopDriver()
    end
end

function CourseplayHud:draw()
    self.background:setPosition(self.x, self.y)
    self.background:setDimension(self.width, self.height)
    self.background:render()

    setTextAlignment(RenderText.ALIGN_RIGHT)
    local strategy = self.vehicle:getCpDriveStrategy()
    local waypointProgress = '--/--'
    if strategy and strategy.course then
        waypointProgress = string.format('%d/%d',
                strategy.ppc:getCurrentWaypointIx(), strategy.ppc:getCourse():getNumberOfWaypoints())
    end
    renderText(self.x + self.width - self.margin, self.y + self.margin, self.textSize, waypointProgress)

end