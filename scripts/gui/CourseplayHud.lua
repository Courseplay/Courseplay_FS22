---@class CourseplayHud
CourseplayHud = CpObject()

CourseplayHud.OFF_COLOR = {0.2, 0.2, 0.2, 0.9}
CourseplayHud.ON_COLOR = {0, 0.6, 0, 0.9}

CourseplayHud.basePosition = {
    x = 810,
    y = 60
}

CourseplayHud.baseSize = {
    x = 300,
    y = 60
}

CourseplayHud.defaultFontSize = 20

CourseplayHud.dragDelayMs = 15

function CourseplayHud:init(vehicle)
    self.vehicle = vehicle
    

    self.uiScale = g_gameSettings:getValue("uiScale")

    self.x, self.y = getNormalizedScreenValues(self.basePosition.x, self.basePosition.y)
    self.width, self.height = getNormalizedScreenValues(self.baseSize.x * self.uiScale, self.baseSize.y * self.uiScale)

    local background = Overlay.new(g_baseUIFilename, 0, 0, 1, 1)
    background:setUVs(g_colorBgUVs)
    background:setColor(0, 0, 0, 0.7)
    --- Root element
    self.baseHud = CpHudElement.new(background)
    self.baseHud:setPosition(self.x, self.y)
    self.baseHud:setDimension(self.width, self.height)
    

    self.lines = 1
    self.textSize = self.height / 3
    self.hMargin = self.textSize / 3
    self.wMargin = self.hMargin

    self.dragLimit = 2

    --- Create start/stop button
    local width, height = getNormalizedScreenValues(18 * self.uiScale, 18 * self.uiScale)
    local onOffIndicatorOverlay =  Overlay.new(g_baseUIFilename, 0, 0,width, height)
    onOffIndicatorOverlay:setAlignment(Overlay.ALIGN_VERTICAL_TOP, Overlay.ALIGN_HORIZONTAL_RIGHT)
    onOffIndicatorOverlay:setUVs(GuiUtils.getUVs(MixerWagonHUDExtension.UV.RANGE_MARKER_ARROW))
    onOffIndicatorOverlay:setColor(unpack(CourseplayHud.OFF_COLOR))
    self.onOffIndicator = CpHudButtonElement.new(onOffIndicatorOverlay,self.baseHud)
    self.onOffIndicator:setPosition(self.x + self.width - self.wMargin, self.y + self.height - self.hMargin)
    self.onOffIndicator:setCallback("onClickPrimary",self.vehicle,self.vehicle.cpStartStopDriver)
    --- Creates vehicle name text
    local textSize = 0.8 * self.textSize
    local x,y = self.x + self.wMargin, self.y + self.height - textSize - self.hMargin
    self.vehicleName = CpTextHudElement.new(self.baseHud,x, y,  self.defaultFontSize)
    --- Creates course name text
    x,y = self.x + self.wMargin, self.y + self.hMargin
    self.courseName = CpTextHudElement.new(self.baseHud,x, y, self.defaultFontSize)
    --- Creates waypoint progress text
    x,y = self.x + self.width - self.wMargin, self.y + self.hMargin
    self.waypointProgress = CpTextHudElement.new(self.baseHud,x, y,  self.defaultFontSize+2,RenderText.ALIGN_RIGHT)

    
end

function CourseplayHud:mouseEvent(posX, posY, isDown, isUp, button)
    if not self.dragging then 
        --- WIP click callbacks are not yet working
        if not self.baseHud:isMouseOverArea(posX,posY) then 
            return
        end
        local wasUsed = self.baseHud:mouseEvent(posX,posY, isDown, isUp, button)
        if wasUsed then 
            return
        end
    end

    if button == Input.MOUSE_BUTTON_LEFT then
        if isDown and self.baseHud:isMouseOverArea(posX,posY) then
            if not self.dragging then
                self.dragStartX = posX
                self.dragOffsetX = posX - self.x
                self.dragStartY = posY
                self.dragOffsetY = posY - self.y
                self.dragging = true
                self.lastDragTimeStamp =  g_time
            end
        elseif isUp then
            if self.dragging and (math.abs(posX - self.dragStartX) > self.dragLimit / g_screenWidth or
                    math.abs(posY - self.dragStartY) > self.dragLimit / g_screenHeight) then
                self:moveTo(posX - self.dragOffsetX, posY - self.dragOffsetY)
            else 

            end
            self.dragging = false
        end
        -- self.vehicle:cpStartStopDriver()
    end
    --- Handles the dragging
    if self.dragging and g_time > (self.lastDragTimeStamp + self.dragDelayMs) then 
        if  math.abs(posX - self.dragStartX) > self.dragLimit / g_screenWidth or
        math.abs(posY - self.dragStartY) > self.dragLimit / g_screenHeight then
            self:moveTo(posX - self.dragOffsetX, posY - self.dragOffsetY)
            self.dragStartX = posX
            self.dragOffsetX = posX - self.x
            self.dragStartY = posY
            self.dragOffsetY = posY - self.y
            self.lastDragTimeStamp = g_time
        end
    end
end

function CourseplayHud:moveTo(x, y)
    self.x, self.y = x, y
    self.baseHud:setPosition(x,y)
end


---@param status CourseplayStatus
function CourseplayHud:draw(status)
    
    --- Set variable data.
    self.courseName.text = self.vehicle:getCurrentCpCourseName()
    self.vehicleName.text = self.vehicle:getName()

    local waypointProgress = '--/--'
    if status.isActive and status.currentWaypointIx then
        self.onOffIndicator:setColor(unpack(CourseplayHud.ON_COLOR))
        waypointProgress = string.format('%d/%d', status.currentWaypointIx, status.numberOfWaypoints)
    else
        self.onOffIndicator:setColor(unpack(CourseplayHud.OFF_COLOR))
    end
    self.waypointProgress.text = waypointProgress
    self.baseHud:draw()
end

