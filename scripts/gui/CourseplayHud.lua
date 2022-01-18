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
    self.textSize = self.height / 3
    self.hMargin = self.textSize / 3
    self.wMargin = self.hMargin

    self.dragLimit = 2

    local width, height = getNormalizedScreenValues(18 * uiScale, 18 * uiScale)
    self.onOffIndicator = HudOverlayButton.new(g_baseUIFilename, 0, 0, width, height)

    self.onOffIndicator:setAlignment(Overlay.ALIGN_VERTICAL_TOP, Overlay.ALIGN_HORIZONTAL_RIGHT)
    self.onOffIndicator:setUVs(GuiUtils.getUVs(MixerWagonHUDExtension.UV.RANGE_MARKER_ARROW))
    self.onOffIndicator:setColor(unpack(CourseplayHud.OFF_COLOR))
    self:moveTo(self.x, self.y)
end

function CourseplayHud:mouseEvent(posX, posY, isDown, isUp, button)
    if button == Input.MOUSE_BUTTON_LEFT then
        if isDown and
                posX > self.x and posX < self.x + self.width and
                posY > self.y and posY < self.y + self.height then
            if not self.dragging then
                self.dragStartX = posX
                self.dragOffsetX = posX - self.x
                self.dragStartY = posY
                self.dragOffsetY = posY - self.y
                self.dragging = true
            end
        elseif isUp then
            if self.dragging and (math.abs(posX - self.dragStartX) > self.dragLimit / g_screenWidth or
                    math.abs(posY - self.dragStartY) > self.dragLimit / g_screenHeight) then
                self:moveTo(posX - self.dragOffsetX, posY - self.dragOffsetY)
            end
            self.dragging = false
        end
        -- self.vehicle:cpStartStopDriver()
    end
end

function CourseplayHud:moveTo(x, y)
    self.x, self.y = x, y
    -- TODO: make this automatic for all elements of the HUD
    self.onOffIndicator:setPosition(self.x + self.width - self.wMargin, self.y + self.height - self.hMargin)
end


---@param status CourseplayStatus
function CourseplayHud:draw(status)
    self.background:setPosition(self.x, self.y)
    self.background:setDimension(self.width, self.height)
    self.background:render()

    setTextAlignment(RenderText.ALIGN_LEFT)
    local textSize = 0.8 * self.textSize
    renderText(self.x + self.wMargin, self.y + self.height - textSize - self.hMargin, textSize, self.vehicle:getName())
    renderText(self.x + self.wMargin, self.y + self.hMargin, textSize, self.vehicle:getCurrentCpCourseName())

    setTextAlignment(RenderText.ALIGN_RIGHT)
    local waypointProgress = '--/--'
    if status.isActive and status.currentWaypointIx then
        self.onOffIndicator:setColor(unpack(CourseplayHud.ON_COLOR))
        waypointProgress = string.format('%d/%d', status.currentWaypointIx, status.numberOfWaypoints)
    else
        self.onOffIndicator:setColor(unpack(CourseplayHud.OFF_COLOR))
    end
    renderText(self.x + self.width - self.wMargin, self.y + self.hMargin, self.textSize, waypointProgress)

    self.onOffIndicator:render()
end