---@class CourseplayHud
CourseplayHud = CpObject()

CourseplayHud.OFF_COLOR = {0.2, 0.2, 0.2, 0.9}
CourseplayHud.ON_COLOR = {0, 0.6, 0, 0.9}

function CourseplayHud:init(vehicle)
    self.vehicle = vehicle
    self.background = Overlay.new(g_baseUIFilename, 0, 0, 1, 1)
    self.background:setUVs(g_colorBgUVs)
    self.background:setColor(0, 0, 0, 0.7)
    local uiScale = g_gameSettings:getValue("uiScale")

    self.x, self.y = getNormalizedScreenValues(960 - 150, 60)
    self.width, self.height = getNormalizedScreenValues(300 * uiScale, 60 * uiScale)
    self.lines = 1
    self.margin = self.width / 30
    self.textSize = self.height / 3

    local width, height = getNormalizedScreenValues(18 * uiScale, 18 * uiScale)
    self.onOffIndicator = Overlay.new(g_baseUIFilename, 0, 0, width, height)

    self.onOffIndicator:setAlignment(Overlay.ALIGN_VERTICAL_TOP, Overlay.ALIGN_HORIZONTAL_RIGHT)
    self.onOffIndicator:setUVs(GuiUtils.getUVs(MixerWagonHUDExtension.UV.RANGE_MARKER_ARROW))
    self.onOffIndicator:setColor(unpack(CourseplayHud.OFF_COLOR))
    self.onOffIndicator:setPosition(self.x + self.width - self.margin, self.y + self.height - self.margin)
end

function CourseplayHud:mouseEvent(posX, posY, isDown, isUp, button)
    if button == 1 and isDown and
            posX > self.x and posX < self.x + self.width and
            posY > self.y and posY < self.y + self.height then
        self.vehicle:cpStartStopDriver()
    end
end

---@param status CourseplayStatus
function CourseplayHud:draw(status)
    self.background:setPosition(self.x, self.y)
    self.background:setDimension(self.width, self.height)
    self.background:render()

    setTextAlignment(RenderText.ALIGN_LEFT)
    local textSize = 0.8 * self.textSize
    renderText(self.x + self.margin, self.y + self.height - self.margin - textSize, textSize, self.vehicle:getName())

    setTextAlignment(RenderText.ALIGN_RIGHT)
    local waypointProgress = '--/--'
    if status.isActive and status.currentWaypointIx then
        self.onOffIndicator:setColor(unpack(CourseplayHud.ON_COLOR))
        waypointProgress = string.format('%d/%d', status.currentWaypointIx, status.numberOfWaypoints)
    else
        self.onOffIndicator:setColor(unpack(CourseplayHud.OFF_COLOR))
    end
    renderText(self.x + self.width - self.margin, self.y + self.margin, self.textSize, waypointProgress)

    self.onOffIndicator:render()
end