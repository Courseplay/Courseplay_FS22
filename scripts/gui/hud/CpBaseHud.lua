---@class CpBaseHud
CpBaseHud = CpObject()

CpBaseHud.OFF_COLOR = {0.2, 0.2, 0.2, 0.9}

CpBaseHud.RECORDER_ON_COLOR = {1, 0, 0, 0.9}
CpBaseHud.ON_COLOR = {0, 0.6, 0, 0.9}

CpBaseHud.basePosition = {
    x = 810,
    y = 60
}

CpBaseHud.baseSize = {
    x = 360,
    y = 200
}

CpBaseHud.titleFontSize = 20
CpBaseHud.defaultFontSize = 16

CpBaseHud.numLines = 7

CpBaseHud.uvs = {
    plusSymbol = {
        {0, 512, 128, 128}
    },
    minusSymbol = {
        {128, 512, 128, 128}
    },
    exitSymbol = {
        {148, 184, 32, 32}
    },
    circleSymbol = {
        {0, 366, 28, 28}
    },
    clearCourseSymbol = {
        {40, 256, 32, 32}
    },
}

CpBaseHud.xmlKey = "Hud"

CpBaseHud.automaticText = g_i18n:getText("CP_automatic")

function CpBaseHud.registerXmlSchema(xmlSchema,baseKey)
    xmlSchema:register(XMLValueType.FLOAT,baseKey..CpBaseHud.xmlKey.."#posX","Hud position x.")
    xmlSchema:register(XMLValueType.FLOAT,baseKey..CpBaseHud.xmlKey.."#posY","Hud position y.")
end

function CpBaseHud:init(vehicle)
    self.vehicle = vehicle

    self.uiScale = g_gameSettings:getValue("uiScale")

    if CpBaseHud.savedPositions then 
        CpBaseHud.x, CpBaseHud.y = unpack(CpBaseHud.savedPositions)
        CpBaseHud.savedPositions = nil
    end

    if CpBaseHud.x == nil or CpBaseHud.y == nil then
        CpBaseHud.x, CpBaseHud.y = getNormalizedScreenValues(self.basePosition.x, self.basePosition.y)
    end
    self.width, self.height = getNormalizedScreenValues(self.baseSize.x, self.baseSize.y)

    local background = Overlay.new(g_baseUIFilename, 0, 0, self.width, self.height)
    background:setUVs(g_colorBgUVs)
    background:setColor(0, 0, 0, 0.7)

    
    self.lineHeight = self.height/(self.numLines+1)
    self.hMargin = self.lineHeight
    self.wMargin = self.lineHeight/2

    self.lines = {}
    for i=1,self.numLines do 
        local y = CpBaseHud.y + self.hMargin + self.lineHeight * (i-1)
        local line = {
            left = {
                CpBaseHud.x + self.wMargin, y
            },
            right = {
                CpBaseHud.x + self.width - self.wMargin, y
            }
        }
        self.lines[i] = line
    end


    --- Root element
    self.baseHud = CpHudMoveableElement.new(background)
    self.baseHud:setPosition(CpBaseHud.x, CpBaseHud.y)
    self.baseHud:setDimension(self.width, self.height)
    self.baseHud:setCallback("onMove",self,self.moveToPosition)
    --------------------------------------
    --- Left side
    --------------------------------------

    --- Cp icon 
    local cpIconWidth, height = getNormalizedScreenValues(30, 30)
    local cpIconOverlay =  Overlay.new(Utils.getFilename("img/courseplayIconHud.dds",Courseplay.BASE_DIRECTORY), 0, 0,cpIconWidth, height)
    cpIconOverlay:setAlignment(Overlay.ALIGN_VERTICAL_MIDDLE, Overlay.ALIGN_HORIZONTAL_LEFT)
    cpIconOverlay:setUVs(GuiUtils.getUVs({80, 26, 144, 144}, {256,256}))
    self.cpIcon = CpHudButtonElement.new(cpIconOverlay, self.baseHud)
    local x, y = unpack(self.lines[7].left)
    self.cpIcon:setPosition(x, y)
    self.cpIcon:setCallback("onClickPrimary",self.vehicle,function (vehicle)
                                self:openGlobalSettingsGui(vehicle)
                            end)


    --- Title 
    local x,y = unpack(self.lines[7].left)
    x = x + cpIconWidth + self.wMargin
    self.vehicleNameBtn = CpTextHudElement.new(self.baseHud ,x , y, self.defaultFontSize)
    self.vehicleNameBtn:setCallback("onClickPrimary", self.vehicle, 
                                function()
                                    self:openVehicleSettingsGui(self.vehicle)
                                end)

    --- Starting point
    self.startingPointBtn = self:addLeftLineTextButton(self.baseHud, 5, self.defaultFontSize, 
        function (vehicle)
            vehicle:getCpStartingPointSetting():setNextItem()
        end, self.vehicle)

     --- Course name
    self.courseNameBtn = self:addLeftLineTextButton(self.baseHud, 4, self.defaultFontSize, 
                                                        function()
                                                            self:openCourseGeneratorGui(self.vehicle)
                                                        end, self.vehicle)

    --------------------------------------
    --- Right side
    --------------------------------------

    --- Exit button                                                  
    local width, height = getNormalizedScreenValues(18, 18)
    local imageFilename = Utils.getFilename('img/iconSprite.dds', g_Courseplay.BASE_DIRECTORY)
    local exitBtnOverlay =  Overlay.new(imageFilename, 0, 0, width, height)
    exitBtnOverlay:setAlignment(Overlay.ALIGN_VERTICAL_TOP, Overlay.ALIGN_HORIZONTAL_RIGHT)
    exitBtnOverlay:setUVs(GuiUtils.getUVs(unpack(self.uvs.exitSymbol),{256,512}))
    exitBtnOverlay:setColor(unpack(CpBaseHud.OFF_COLOR))
    self.exitBtn = CpHudButtonElement.new(exitBtnOverlay, self.baseHud)
    local x, y = CpBaseHud.x + self.width -width/3 , CpBaseHud.y + self.height -height/3
    self.exitBtn:setPosition(x, y)
    self.exitBtn:setCallback("onClickPrimary", self.vehicle, function (vehicle)
        vehicle:closeCpHud()
    end)


    --- Create start/stop button
    local onOffBtnWidth, height = getNormalizedScreenValues(20, 20)
    local onOffIndicatorOverlay =  Overlay.new(g_baseUIFilename, 0, 0, onOffBtnWidth, height)
    onOffIndicatorOverlay:setAlignment(Overlay.ALIGN_VERTICAL_BOTTOM, Overlay.ALIGN_HORIZONTAL_RIGHT)
    onOffIndicatorOverlay:setUVs(GuiUtils.getUVs(MixerWagonHUDExtension.UV.RANGE_MARKER_ARROW))
    onOffIndicatorOverlay:setColor(unpack(CpBaseHud.OFF_COLOR))
    self.onOffButton = CpHudButtonElement.new(onOffIndicatorOverlay, self.baseHud)
    local x, y = unpack(self.lines[6].right)
    self.onOffButton:setPosition(x, y)
    self.onOffButton:setCallback("onClickPrimary", self.vehicle, self.vehicle.cpStartStopDriver)
    
    --- Create start/stop field boarder record button
    local recordingBtnWidth, height = getNormalizedScreenValues(18, 18)
    local imageFilename = Utils.getFilename('img/iconSprite.dds', g_Courseplay.BASE_DIRECTORY)
    local circleOverlay =  Overlay.new(imageFilename, 0, 0, recordingBtnWidth, height)
    circleOverlay:setAlignment(Overlay.ALIGN_VERTICAL_BOTTOM, Overlay.ALIGN_HORIZONTAL_RIGHT)
    circleOverlay:setUVs(GuiUtils.getUVs(unpack(self.uvs.circleSymbol),{256,512}))
    circleOverlay:setColor(unpack(CpBaseHud.OFF_COLOR))
    self.startStopRecordingBtn = CpHudButtonElement.new(circleOverlay, self.baseHud)
    local x, y = unpack(self.lines[6].right)
    x = x - onOffBtnWidth - self.wMargin/2
    self.startStopRecordingBtn:setPosition(x, y)
    self.startStopRecordingBtn:setCallback("onClickPrimary", self.vehicle, function (vehicle)
        if vehicle:getIsCpCourseRecorderActive() then 
            vehicle:cpStopCourseRecorder()
        elseif vehicle:getCanStartCpCourseRecorder() then 
            vehicle:cpStartCourseRecorder()
        end
    end)
    
    --- Clear course button.
    local width, height = getNormalizedScreenValues(18, 18)
    local imageFilename = Utils.getFilename('img/iconSprite.dds', g_Courseplay.BASE_DIRECTORY)
    local clearCourseOverlay =  Overlay.new(imageFilename, 0, 0, width, height)
    clearCourseOverlay:setAlignment(Overlay.ALIGN_VERTICAL_BOTTOM, Overlay.ALIGN_HORIZONTAL_RIGHT)
    clearCourseOverlay:setUVs(GuiUtils.getUVs(unpack(self.uvs.clearCourseSymbol),{256,512}))
    clearCourseOverlay:setColor(unpack(CpBaseHud.OFF_COLOR))
    self.clearCourseBtn = CpHudButtonElement.new(clearCourseOverlay, self.baseHud)
    local x, y = unpack(self.lines[6].right)
    x = x - onOffBtnWidth - self.wMargin/2 - recordingBtnWidth - self.wMargin/4
    self.clearCourseBtn:setPosition(x, y)
    self.clearCourseBtn:setCallback("onClickPrimary", self.vehicle, function (vehicle)
        if vehicle:hasCpCourse() and not vehicle:getIsCpActive() then
            vehicle:resetCpCoursesFromGui()
        end
    end)
    
    
    
    --- Lane offset
    self.laneOffsetBtn = self:addRightLineTextButton(self.baseHud, 5, self.defaultFontSize, 
        function (vehicle)
            vehicle:getCpLaneOffsetSetting():setNextItem()
        end, self.vehicle)
  
    --- Waypoint progress
    self.waypointProgressBtn = self:addRightLineTextButton(self.baseHud, 4, self.defaultFontSize, 
                                                        function()
                                                            self:openCourseManagerGui(self.vehicle)
                                                        end, self.vehicle)

    --------------------------------------
    --- Complete line
    --------------------------------------
   
    --- Work width
    self.workWidthBtn = self:addLineTextButton(self.baseHud, 3, self.defaultFontSize, 
                                                self.vehicle:getCourseGeneratorSettings().workWidth)

    --- Tool offset x
    self.toolOffsetXBtn = self:addLineTextButton(self.baseHud, 2, self.defaultFontSize, 
                                                self.vehicle:getCpSettings().toolOffsetX)

    --- Tool offset z
    self.toolOffsetZBtn = self:addLineTextButton(self.baseHud, 1, self.defaultFontSize, 
                                                self.vehicle:getCpSettings().toolOffsetZ)

    ---- Disables zoom, while mouse is over the cp hud. 
    local function disableCameraZoomOverHud(vehicle,superFunc,...)
        if vehicle:getIsMouseOverCpHud() then 
            return
        end
        return superFunc(vehicle,...)
    end                                                   

    Enterable.actionEventCameraZoomIn = Utils.overwrittenFunction(Enterable.actionEventCameraZoomIn,disableCameraZoomOverHud)
    Enterable.actionEventCameraZoomOut = Utils.overwrittenFunction(Enterable.actionEventCameraZoomOut,disableCameraZoomOverHud)

    self.baseHud:setVisible(false)

    self.baseHud:setScale(self.uiScale,self.uiScale)
end

function CpBaseHud:addLeftLineTextButton(parent, line, textSize, callbackFunc,callbackClass)
    local x,y = unpack(self.lines[line].left)
    local element = CpTextHudElement.new(parent ,x , y, textSize)
    element:setCallback("onClickPrimary", callbackClass, callbackFunc)
    return element
end

function CpBaseHud:addRightLineTextButton(parent, line, textSize, callbackFunc,callbackClass)
    local x,y = unpack(self.lines[line].right)
    local element = CpTextHudElement.new(parent ,x , y, 
                                        textSize,RenderText.ALIGN_RIGHT)
    element:setCallback("onClickPrimary", callbackClass, callbackFunc)
    return element
end

function CpBaseHud:addLineTextButton(parent, line, textSize, setting)
    local imageFilename = Utils.getFilename('img/ui_courseplay.dds', g_Courseplay.BASE_DIRECTORY)

    local width, height = getNormalizedScreenValues(16, 16)
    local incrementalOverlay =  Overlay.new(imageFilename, 0, 0, width, height)
    incrementalOverlay:setAlignment(Overlay.ALIGN_VERTICAL_BOTTOM, Overlay.ALIGN_HORIZONTAL_RIGHT)
    incrementalOverlay:setUVs(GuiUtils.getUVs(unpack(self.uvs.plusSymbol)))
    incrementalOverlay:setColor(unpack(self.OFF_COLOR))
    local decrementalOverlay =  Overlay.new(imageFilename, 0, 0, width, height)
  --  decrementalOverlay:setAlignment(Overlay.ALIGN_VERTICAL_TOP, Overlay.ALIGN_HORIZONTAL_RIGHT)
    decrementalOverlay:setUVs(GuiUtils.getUVs(unpack(self.uvs.minusSymbol)))
    decrementalOverlay:setColor(unpack(self.OFF_COLOR))

    local x, y = unpack(self.lines[line].left)
    local dx, dy = unpack(self.lines[line].right)
    local element = CpHudSettingElement.new(parent, x, y, dx, dy, 
                                            incrementalOverlay, decrementalOverlay, textSize)

    local callbackIncremental = {
        callbackStr = "onClickPrimary",
        class =  setting,
        func =  setting.setNextItem,
    }
    
    local callbackDecremental = {
        callbackStr = "onClickPrimary",
        class =  setting,
        func =  setting.setPreviousItem,
    }

    local callbackLabel = {
        callbackStr = "onClickPrimary",
        class =  setting,
        func =  setting.setDefault,
    }

    local callbackText = {
        callbackStr = "onClickMouseWheel",
        class =  setting,
        func = function (class,dir)
            if dir >0 then 
                class:setNextItem()
            else
                class:setPreviousItem()
            end
        end
    }
                                             

    element:setCallback(callbackLabel, callbackText, callbackIncremental, callbackDecremental)
    return element
end

function CpBaseHud:moveToPosition(x, y)
    CpBaseHud.x = x 
    CpBaseHud.y = y
end

function CpBaseHud:openClose(open)
    self.baseHud:setVisible(open)
    if open then 
        self.baseHud:setPosition(CpBaseHud.x,CpBaseHud.y)
    end
end

function CpBaseHud:getIsOpen()
    return self.baseHud:getVisible()
end

function CpBaseHud:mouseEvent(posX, posY, isDown, isUp, button)
    local wasUsed = self.baseHud:mouseEvent(posX, posY, isDown, isUp, button)
    if wasUsed then 
        return
    end
end

function CpBaseHud:isMouseOverArea(posX, posY)
    return self.baseHud:isMouseOverArea(posX, posY) 
end

---@param status CpStatus
function CpBaseHud:draw(status)
    
    --- Set variable data.
    self.courseNameBtn:setTextDetails(self.vehicle:getCurrentCpCourseName())
    self.vehicleNameBtn:setTextDetails(self.vehicle:getName())
    if self.vehicle:getCanStartCpBaleFinder() then 
        self.startingPointBtn:setDisabled(true)
        self.startingPointBtn:setTextDetails(self.vehicle:getCpStartText())
    else
        self.startingPointBtn:setDisabled(false)
        self.startingPointBtn:setTextDetails(self.vehicle:getCpStartingPointSetting():getString())
    end
   
    if status:getIsActive() then
        self.onOffButton:setColor(unpack(CpBaseHud.ON_COLOR))
    else
        self.onOffButton:setColor(unpack(CpBaseHud.OFF_COLOR))
        self.clearCourseBtn:setVisible(self.vehicle:hasCpCourse() and not self.vehicle:getIsCpActive())
    end
    self.onOffButton:setVisible(self.vehicle:getCanStartCp() or self.vehicle:getIsCpActive())

    if self.vehicle:getIsCpCourseRecorderActive() then
        self.startStopRecordingBtn:setColor(unpack(CpBaseHud.RECORDER_ON_COLOR))
    else 
        self.startStopRecordingBtn:setColor(unpack(CpBaseHud.OFF_COLOR))
    end
    self.startStopRecordingBtn:setVisible(self.vehicle:getCanStartCpCourseRecorder())

    self.waypointProgressBtn:setTextDetails(status:getWaypointText())
    
    local laneOffset = self.vehicle:getCpLaneOffsetSetting()
    self.laneOffsetBtn:setVisible(laneOffset:getCanBeChanged())
    self.laneOffsetBtn:setTextDetails(laneOffset:getString())

    local workWidth = self.vehicle:getCourseGeneratorSettings().workWidth
    self.workWidthBtn:setTextDetails(workWidth:getTitle(), workWidth:getString())

    local toolOffsetX = self.vehicle:getCpSettings().toolOffsetX
    local text = toolOffsetX:getIsDisabled() and CpBaseHud.automaticText or toolOffsetX:getString()
    self.toolOffsetXBtn:setTextDetails(toolOffsetX:getTitle(), text)
    self.toolOffsetXBtn:setDisabled(toolOffsetX:getIsDisabled())

    local toolOffsetZ = self.vehicle:getCpSettings().toolOffsetZ
    text = toolOffsetZ:getIsDisabled() and CpBaseHud.automaticText or toolOffsetZ:getString()
    self.toolOffsetZBtn:setTextDetails(toolOffsetZ:getTitle(), text)
    self.toolOffsetZBtn:setDisabled(toolOffsetZ:getIsDisabled())

    self.baseHud:draw()
end

function CpBaseHud:delete()
    self.baseHud:delete()
end

function CpBaseHud:getIsHovered()
    return self.baseHud:getIsHovered()    
end

--------------------------------------
--- Hud element callbacks
--------------------------------------

function CpBaseHud:preOpeningInGameMenu(vehicle)
    local inGameMenu =  g_currentMission.inGameMenu
    local pageAI = inGameMenu.pageAI
    pageAI.controlledVehicle = vehicle
    pageAI.currentHotspot = nil
    inGameMenu:updatePages()
    g_gui:showGui("InGameMenu")
    inGameMenu:changeScreen(InGameMenu)
    return inGameMenu
end

function CpBaseHud:openCourseManagerGui(vehicle)
    local inGameMenu = self:preOpeningInGameMenu(vehicle)
    local courseManagerPageIx = inGameMenu.pagingElement:getPageMappingIndexByElement(inGameMenu.pageCpCourseManager)
    inGameMenu.pageSelector:setState(courseManagerPageIx, true)
end

function CpBaseHud:openCourseGeneratorGui(vehicle)
    local inGameMenu = self:preOpeningInGameMenu(vehicle)
     --- Opens the course generator if possible.
    local pageIx = inGameMenu.pagingElement:getPageMappingIndexByElement(inGameMenu.pageAI)
    inGameMenu.pageSelector:setState(pageIx, true)
    inGameMenu.pageAI:onCreateJob()
    for i,index in ipairs(inGameMenu.pageAI.currentJobTypes) do 
        local job = inGameMenu.pageAI.jobTypeInstances[index]
        if job:isa(CpAIJobFieldWork) then 
            if not vehicle:hasCpCourse() then 
                -- Sets the start position relative to the vehicle position, but only if no course is set.
                job:resetStartPositionAngle(vehicle)
                job:setValues()
                local x, z, rot = job:getTarget()
                inGameMenu.pageAI.aiTargetMapHotspot:setWorldPosition(x, z)
                if rot ~= nil then
                    inGameMenu.pageAI.aiTargetMapHotspot:setWorldRotation(rot + math.pi)
                end

            end
            inGameMenu.pageAI:setActiveJobTypeSelection(index)
            break
        end
    end
    inGameMenu.pageAI:onClickOpenCloseCourseGenerator()
end

function CpBaseHud:openVehicleSettingsGui(vehicle)
    local inGameMenu = self:preOpeningInGameMenu(vehicle)
    local vehiclePageIx = inGameMenu.pagingElement:getPageMappingIndexByElement(inGameMenu.pageCpVehicleSettings)
    inGameMenu.pageSelector:setState(vehiclePageIx, true)
end

function CpBaseHud:openGlobalSettingsGui(vehicle)
    local inGameMenu = self:preOpeningInGameMenu(vehicle)
    local pageIx = inGameMenu.pagingElement:getPageMappingIndexByElement(inGameMenu.pageCpGlobalSettings)
    inGameMenu.pageSelector:setState(pageIx, true)
end

--- Saves hud position.
function CpBaseHud.saveToXmlFile(xmlFile,baseKey)
    xmlFile:setValue(baseKey..CpBaseHud.xmlKey.."#posX",CpBaseHud.x)
    xmlFile:setValue(baseKey..CpBaseHud.xmlKey.."#posY",CpBaseHud.y)
end

--- Loads hud position.
function CpBaseHud.loadFromXmlFile(xmlFile,baseKey)
    local posX = xmlFile:getValue(baseKey..CpBaseHud.xmlKey.."#posX")
    local posY = xmlFile:getValue(baseKey..CpBaseHud.xmlKey.."#posY")
    if posX ~= nil and posY ~= nil then 
        CpBaseHud.savedPositions = {
           posX, posY
        }
    end
end