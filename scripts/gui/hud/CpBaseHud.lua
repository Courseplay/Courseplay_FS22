--- TODO: - Make the hud static and only one instance.
---         Apply the update only when data has changed.
---       - Move all the constants into a xml file similar
---         to the gui setup by giants.
---@class CpBaseHud
CpBaseHud = CpObject()

CpBaseHud.OFF_COLOR = {0.2, 0.2, 0.2, 0.9}

CpBaseHud.RECORDER_ON_COLOR = {1, 0, 0, 0.9}
CpBaseHud.ON_COLOR = {0, 0.6, 0, 0.9}
CpBaseHud.SEMI_ON_COLOR = {0.6, 0.6, 0, 0.9}
CpBaseHud.WHITE_COLOR = {1, 1, 1, 0.9}
CpBaseHud.BACKGROUND_COLOR = {0, 0, 0, 0.7}

CpBaseHud.HEADER_COLOR = {
    0, 0.4, 0.6, 1
}
CpBaseHud.BASE_COLOR = {1, 1, 1, 1}

CpBaseHud.basePosition = {
    x = 810,
    y = 60
}

CpBaseHud.baseSize = {
    x = 360,
    y = 230
}

CpBaseHud.headerFontSize = 14
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
    leftArrowSymbol = {
        {384, 512, 128, 128}
    },
    rightArrowSymbol = {
        {512, 512, 128, 128}
    },
    pasteSymbol = {
        {255, 639, 128, 128}
    },
    copySymbol = {
        {127, 637, 128, 128}
    },
    driveNowSymbol = {
        {0, 768, 128, 128}
    },
    goalSymbol = GuiUtils.getUVs({
        788,
	30,
	44,
	44
    }, AITargetHotspot.FILE_RESOLUTION),
    
    exitSymbol = {
        {148, 184, 32, 32}, {256, 512}
    },
    circleSymbol = {
        {0, 366, 28, 28}, {256, 512}
    },
    clearCourseSymbol = {
        {40, 256, 32, 32}, {256, 512}
    },
    eye = { 
        {148, 148, 32, 32}, {256, 512}
    },
    cpIcon = {
        {80, 26, 144, 144}, {256, 256}
    }
}

--- Vertical + horizontal overlay alignment
CpBaseHud.alignments = {
    bottomLeft =    {Overlay.ALIGN_VERTICAL_BOTTOM, Overlay.ALIGN_HORIZONTAL_LEFT},
    bottomCenter =  {Overlay.ALIGN_VERTICAL_BOTTOM, Overlay.ALIGN_HORIZONTAL_CENTER},
    bottomRight =   {Overlay.ALIGN_VERTICAL_BOTTOM, Overlay.ALIGN_HORIZONTAL_RIGHT},
    middleLeft =    {Overlay.ALIGN_VERTICAL_MIDDLE, Overlay.ALIGN_HORIZONTAL_LEFT},
    middleCenter =  {Overlay.ALIGN_VERTICAL_MIDDLE, Overlay.ALIGN_HORIZONTAL_CENTER},
    middleRight =   {Overlay.ALIGN_VERTICAL_MIDDLE, Overlay.ALIGN_HORIZONTAL_RIGHT},
    topLeft =       {Overlay.ALIGN_VERTICAL_TOP,    Overlay.ALIGN_HORIZONTAL_LEFT},
    topCenter =     {Overlay.ALIGN_VERTICAL_TOP,    Overlay.ALIGN_HORIZONTAL_CENTER},
    topRight =      {Overlay.ALIGN_VERTICAL_TOP,    Overlay.ALIGN_HORIZONTAL_RIGHT}
}

CpBaseHud.xmlKey = "Hud"

CpBaseHud.automaticText = g_i18n:getText("CP_automatic")
CpBaseHud.copyText = g_i18n:getText("CP_copy")

CpBaseHud.courseCache = nil

function CpBaseHud.registerXmlSchema(xmlSchema, baseKey)
    xmlSchema:register(XMLValueType.FLOAT, baseKey..CpBaseHud.xmlKey.."#posX", "Hud position x.")
    xmlSchema:register(XMLValueType.FLOAT, baseKey..CpBaseHud.xmlKey.."#posY", "Hud position y.")
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

    
    self.lineHeight = self.height/(self.numLines+2)
    self.hMargin = self.lineHeight
    self.wMargin = self.lineHeight/2

    self.lines = {}
    for i=1, (self.numLines+1) do 
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

    
    local background = CpGuiUtil.createOverlay({self.width, self.height},
                                            {g_baseUIFilename, g_colorBgUVs}, 
                                            self.BACKGROUND_COLOR,
                                            self.alignments.bottomLeft)

    --- Root element
    self.baseHud = CpHudMoveableElement.new(background)
    self.baseHud:setPosition(CpBaseHud.x, CpBaseHud.y)
    self.baseHud:setDimension(self.width, self.height)
    self.baseHud:setCallback("onMove", self, self.moveToPosition)

    self.fieldworkLayout = CpHudElement.new(nil, self.baseHud)
    self.fieldworkLayout:setPosition(CpBaseHud.x, CpBaseHud.y)
    self.fieldworkLayout:setDimension(self.width, self.height)

    self.baleFinderLayout = CpHudElement.new(nil, self.baseHud)
    self.baleFinderLayout:setPosition(CpBaseHud.x, CpBaseHud.y)
    self.baleFinderLayout:setDimension(self.width, self.height)

    self.combineUnloaderLayout = CpHudElement.new(nil, self.baseHud)
    self.combineUnloaderLayout:setPosition(CpBaseHud.x, CpBaseHud.y)
    self.combineUnloaderLayout:setDimension(self.width, self.height)
    --------------------------------------
    --- Header
    --------------------------------------
    
    local headerHeight = self.hMargin

    local headerBackground = CpGuiUtil.createOverlay({self.width, headerHeight},
                                                    {g_baseUIFilename, g_colorBgUVs}, 
                                                    self.HEADER_COLOR,
                                                    self.alignments.bottomLeft)

    local topElement = CpHudElement.new(headerBackground, self.baseHud)
    topElement:setPosition(CpBaseHud.x, CpBaseHud.y + self.height - headerHeight)
    topElement:setDimension(self.width, headerHeight)

    local leftTopText = CpTextHudElement.new(self.baseHud, CpBaseHud.x + self.wMargin, CpBaseHud.y + self.hMargin/4 + self.height - headerHeight, self.headerFontSize)
    leftTopText:setTextDetails("Courseplay")
    local rightTopText = CpTextHudElement.new(self.baseHud, CpBaseHud.x + self.width - 3*self.wMargin/2, CpBaseHud.y + self.hMargin/4 + self.height - headerHeight, self.headerFontSize, RenderText.ALIGN_RIGHT)
    rightTopText:setTextDetails(g_Courseplay.currentVersion)

    --------------------------------------
    --- Left side
    --------------------------------------

    --- Cp icon 
    local cpIconWidth, height = getNormalizedScreenValues(22, 22)
    local cpIconOverlay = CpGuiUtil.createOverlay({cpIconWidth, height},
                                                    {Utils.getFilename("img/courseplayIconHud.dds", Courseplay.BASE_DIRECTORY), GuiUtils.getUVs(unpack(self.uvs.cpIcon))}, 
                                                    self.BASE_COLOR,
                                                    self.alignments.bottomLeft)
    self.cpIcon = CpHudButtonElement.new(cpIconOverlay, self.baseHud)
    local x, y = unpack(self.lines[7].left)
    y = y - self.hMargin/4
    self.cpIcon:setPosition(x, y)
    self.cpIcon:setCallback("onClickPrimary", self.vehicle, function (vehicle)
                                self:openGlobalSettingsGui(vehicle)
                            end)

    --- Title 
    local x, y = unpack(self.lines[7].left)
    x = x + cpIconWidth + self.wMargin/2
    self.vehicleNameBtn = CpTextHudElement.new(self.baseHud , x , y, self.defaultFontSize)
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
    local exitBtnOverlay = CpGuiUtil.createOverlay({width, height},
                                                    {imageFilename, GuiUtils.getUVs(unpack(self.uvs.exitSymbol))}, 
                                                    self.WHITE_COLOR,
                                                    self.alignments.bottomRight)

    self.exitBtn = CpHudButtonElement.new(exitBtnOverlay, self.baseHud)
    local x, y = CpBaseHud.x + self.width -width/3 , CpBaseHud.y + self.height - headerHeight + self.hMargin/8
    self.exitBtn:setPosition(x, y) 
    self.exitBtn:setCallback("onClickPrimary", self.vehicle, function (vehicle)
        vehicle:closeCpHud()
    end)


    --- Create start/stop button
    local onOffBtnWidth, height = getNormalizedScreenValues(20, 20)
    local onOffIndicatorOverlay = CpGuiUtil.createOverlay({onOffBtnWidth, height},
                                                        {g_baseUIFilename, GuiUtils.getUVs(MixerWagonHUDExtension.UV.RANGE_MARKER_ARROW)}, 
                                                        self.OFF_COLOR,
                                                        self.alignments.bottomRight)
    self.onOffButton = CpHudButtonElement.new(onOffIndicatorOverlay, self.baseHud)
    local x, y = unpack(self.lines[6].right)
    self.onOffButton:setPosition(x, y)
    self.onOffButton:setCallback("onClickPrimary", self.vehicle, self.vehicle.cpStartStopDriver)
    
    --- Create start/stop field boarder record button
    local recordingBtnWidth, height = getNormalizedScreenValues(18, 18)
    local imageFilename = Utils.getFilename('img/iconSprite.dds', g_Courseplay.BASE_DIRECTORY)
    local circleOverlay = CpGuiUtil.createOverlay({recordingBtnWidth, height},
                                                {imageFilename, GuiUtils.getUVs(unpack(self.uvs.circleSymbol))}, 
                                                self.OFF_COLOR,
                                                self.alignments.bottomRight)
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
    local clearCourseOverlay = CpGuiUtil.createOverlay({width, height},
                                                {imageFilename, GuiUtils.getUVs(unpack(self.uvs.clearCourseSymbol))}, 
                                                self.OFF_COLOR,
                                                self.alignments.bottomRight)
    self.clearCourseBtn = CpHudButtonElement.new(clearCourseOverlay, self.baseHud)
    local x, y = unpack(self.lines[6].right)
    x = x - onOffBtnWidth - self.wMargin/2 - recordingBtnWidth - self.wMargin/4
    self.clearCourseBtn:setPosition(x, y)
    self.clearCourseBtn:setCallback("onClickPrimary", self.vehicle, function (vehicle)
        if vehicle:hasCpCourse() and not vehicle:getIsCpActive() then
            vehicle:resetCpCoursesFromGui()
        end
    end)
    
    --- Toggle waypoint visibility.
    local width, height = getNormalizedScreenValues(20, 20)
    local imageFilename = Utils.getFilename('img/iconSprite.dds', g_Courseplay.BASE_DIRECTORY)
    local courseVisibilityOverlay = CpGuiUtil.createOverlay({width, height},
                                                        {imageFilename, GuiUtils.getUVs(unpack(self.uvs.eye))}, 
                                                        self.OFF_COLOR,
                                                        self.alignments.bottomRight)
    self.courseVisibilityBtn = CpHudButtonElement.new(courseVisibilityOverlay, self.baseHud)
    local _, y = unpack(self.lines[6].right)
    y = y - self.hMargin/16
    x = x - width - self.wMargin/4
    self.courseVisibilityBtn:setPosition(x, y)
    self.courseVisibilityBtn:setCallback("onClickPrimary", self.vehicle, function (vehicle)
        vehicle:getCpSettings().showCourse:setNextItem()
    end)
    
    --- Lane offset
    self.laneOffsetBtn = self:addRightLineTextButton(self.fieldworkLayout, 5, self.defaultFontSize, 
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
    self.workWidthBtn = self:addLineTextButton(self.fieldworkLayout, 3, self.defaultFontSize, 
                                                self.vehicle:getCourseGeneratorSettings().workWidth)

    --- Bale finder fill type
    local x, y = unpack(self.lines[3].left)
    local xRight,_ = unpack(self.lines[3].right)
    self.baleFinderFillTypeBtn = CpHudTextSettingElement.new(self.baleFinderLayout, x, y,
                                     xRight, self.defaultFontSize)
    local callback = {
        callbackStr = "onClickPrimary",
        class =  vehicle:getCpBaleFinderJobParameters().baleWrapType,
        func =   vehicle:getCpBaleFinderJobParameters().baleWrapType.setNextItem,
    }
    self.baleFinderFillTypeBtn:setCallback(callback, callback)                                           


    --- Tool offset x
    self.toolOffsetXBtn = self:addLineTextButton(self.baseHud, 2, self.defaultFontSize, 
                                                self.vehicle:getCpSettings().toolOffsetX)

    --- Tool offset z
    self.toolOffsetZBtn = self:addLineTextButton(self.combineUnloaderLayout, 1, self.defaultFontSize, 
                                                self.vehicle:getCpSettings().toolOffsetZ)

    --- Full threshold 
    self.fullThresholdBtn = self:addLineTextButton(self.combineUnloaderLayout, 3, self.defaultFontSize, 
                                                self.vehicle:getCpCombineUnloaderJobParameters().fullThreshold)              

    --- Giants unloading station
    local x, y = unpack(self.lines[4].left)
    self.giantsUnloadStationText = CpTextHudElement.new(self.combineUnloaderLayout , x , y, self.defaultFontSize)                 
    self.giantsUnloadStationText:setCallback("onClickPrimary", self.vehicle, 
    function(vehicle)
        vehicle:getCpCombineUnloaderJobParameters().unloadingStation:setNextItem()
    end)

    --- Drive now button
    local driveNowBtnWidth, height = getNormalizedScreenValues(26, 30)
    local imageFilename = Utils.getFilename('img/ui_courseplay.dds', g_Courseplay.BASE_DIRECTORY)
    local driveNowOverlay = CpGuiUtil.createOverlay({driveNowBtnWidth, height},
                                                        {imageFilename, GuiUtils.getUVs(unpack(self.uvs.driveNowSymbol))}, 
                                                        self.OFF_COLOR,
                                                        self.alignments.bottomRight)
    self.driveNowBtn = CpHudButtonElement.new(driveNowOverlay, self.combineUnloaderLayout)
    local x, y = unpack(self.lines[6].right)
    y = y - self.hMargin/4
    local driveNowBtnX = x - onOffBtnWidth - self.wMargin/2 - recordingBtnWidth - self.wMargin/8
    self.driveNowBtn:setPosition(driveNowBtnX, y)
    self.driveNowBtn:setCallback("onClickPrimary", self.vehicle, function (vehicle)
        self.vehicle:startCpCombineUnloaderUnloading()
    end)

    --- Giants unload button
    local width, height = getNormalizedScreenValues(22, 22)
    local giantsUnloadOverlay = CpGuiUtil.createOverlay({width, height},
                                                        {AIHotspot.FILENAME, AIHotspot.UVS}, 
                                                        self.OFF_COLOR,
                                                        self.alignments.bottomRight)
    self.activateGiantsUnloadBtn = CpHudButtonElement.new(giantsUnloadOverlay, self.combineUnloaderLayout)
    local _, y = unpack(self.lines[6].right)
    y = y - self.hMargin/16
    x = driveNowBtnX - driveNowBtnWidth - self.wMargin/8
    self.activateGiantsUnloadBtn:setPosition(x, y)
    self.activateGiantsUnloadBtn:setCallback("onClickPrimary", self.vehicle, function (vehicle)
        vehicle:getCpCombineUnloaderJobParameters().useGiantsUnload:setNextItem()
    end)

    --- Goal button.
    local width, height = getNormalizedScreenValues(37, 37)    
    local goalOverlay = CpGuiUtil.createOverlay({width, height},
                                                {AITargetHotspot.FILENAME, self.uvs.goalSymbol}, 
                                                self.OFF_COLOR,
                                                self.alignments.bottomRight)
    
    self.goalBtn = CpHudButtonElement.new(goalOverlay, self.combineUnloaderLayout)
    local x, y = unpack(self.lines[4].right)
    self.goalBtn:setPosition(x, y + self.hMargin/2)
    self.goalBtn:setCallback("onClickPrimary", self.vehicle, function (vehicle)
        self:openCourseGeneratorGui(vehicle)
    end)
    --- Copy course btn.                                          
    self:addCopyCourseBtn(1)

    ---- Disables zoom, while mouse is over the cp hud. 
    local function disableCameraZoomOverHud(vehicle, superFunc, ...)
        if vehicle.getIsMouseOverCpHud and vehicle:getIsMouseOverCpHud() then 
            return
        end
        return superFunc(vehicle, ...)
    end                                                   

    Enterable.actionEventCameraZoomIn = Utils.overwrittenFunction(Enterable.actionEventCameraZoomIn, disableCameraZoomOverHud)
    Enterable.actionEventCameraZoomOut = Utils.overwrittenFunction(Enterable.actionEventCameraZoomOut, disableCameraZoomOverHud)

    self.baseHud:setVisible(false)

    self.baseHud:setScale(self.uiScale, self.uiScale)
end

function CpBaseHud:addLeftLineTextButton(parent, line, textSize, callbackFunc, callbackClass)
    local x, y = unpack(self.lines[line].left)
    local element = CpTextHudElement.new(parent , x , y, textSize)
    element:setCallback("onClickPrimary", callbackClass, callbackFunc)
    return element
end

function CpBaseHud:addRightLineTextButton(parent, line, textSize, callbackFunc, callbackClass)
    local x, y = unpack(self.lines[line].right)
    local element = CpTextHudElement.new(parent , x , y, 
                                        textSize, RenderText.ALIGN_RIGHT)
    element:setCallback("onClickPrimary", callbackClass, callbackFunc)
    return element
end

function CpBaseHud:addLineTextButton(parent, line, textSize, setting)
    if setting == nil then 
        self:debug("Setting is nil!")
        printCallstack()
        return
    end
    local imageFilename = Utils.getFilename('img/ui_courseplay.dds', g_Courseplay.BASE_DIRECTORY)

    local width, height = getNormalizedScreenValues(16, 16)
    local incrementalOverlay = CpGuiUtil.createOverlay({width, height},
                                                            {imageFilename, GuiUtils.getUVs(unpack(self.uvs.plusSymbol))}, 
                                                            self.OFF_COLOR,
                                                            self.alignments.bottomRight)

    local decrementalOverlay = CpGuiUtil.createOverlay({width, height},
                                                        {imageFilename, GuiUtils.getUVs(unpack(self.uvs.minusSymbol))}, 
                                                        self.OFF_COLOR,
                                                        self.alignments.bottomLeft)

    local x, y = unpack(self.lines[line].left)
    local dx, dy = unpack(self.lines[line].right)
    local btnYOffset = self.hMargin*0.1
    local element = CpHudSettingElement.new(parent, x, y, dx, y - btnYOffset, 
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
        func = function (class, element, dir)
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

--- Setup for the copy course btn.
function CpBaseHud:addCopyCourseBtn(line)    
    local imageFilename = Utils.getFilename('img/ui_courseplay.dds', g_Courseplay.BASE_DIRECTORY)
    local imageFilename2 = Utils.getFilename('img/iconSprite.dds', g_Courseplay.BASE_DIRECTORY)
    --- Copy course btn.                                          
    self.copyCourseElements = {}
    self.copyCourseIx = 1
    self.courseVehicles = {}
    local leftX, leftY = unpack(self.lines[line].left)
    local rightX, rightY = unpack(self.lines[line].right)
    local btnYOffset = self.hMargin*0.2

    local width, height = getNormalizedScreenValues(22, 22)
    
    local copyOverlay = CpGuiUtil.createOverlay({width, height},
                                                        {imageFilename, GuiUtils.getUVs(unpack(self.uvs.copySymbol))}, 
                                                        self.OFF_COLOR,
                                                        self.alignments.bottomRight)

    local pasteOverlay = CpGuiUtil.createOverlay({width, height},
                                                        {imageFilename, GuiUtils.getUVs(unpack(self.uvs.pasteSymbol))}, 
                                                        self.OFF_COLOR,
                                                        self.alignments.bottomRight)

   
    local clearCourseOverlay = CpGuiUtil.createOverlay({width, height},
                                                        {imageFilename2, GuiUtils.getUVs(unpack(self.uvs.clearCourseSymbol))}, 
                                                        self.OFF_COLOR,
                                                        self.alignments.bottomRight)

    self.copyButton = CpHudButtonElement.new(copyOverlay, self.baseHud)
    self.copyButton:setPosition(rightX, rightY-btnYOffset)
    self.copyButton:setCallback("onClickPrimary", self.vehicle, function (vehicle)
        if not CpBaseHud.courseCache and self.vehicle:hasCpCourse() then 
            CpBaseHud.courseCache = self.vehicle:getFieldWorkCourse()
        end
    end)

    self.pasteButton = CpHudButtonElement.new(pasteOverlay, self.baseHud)
    self.pasteButton:setPosition(rightX, rightY-btnYOffset)
    self.pasteButton:setCallback("onClickPrimary", self.vehicle, function (vehicle)
        if CpBaseHud.courseCache and not self.vehicle:hasCpCourse() then 
            self.vehicle:cpCopyCourse(CpBaseHud.courseCache)
        end
    end)

    self.clearCacheBtn = CpHudButtonElement.new(clearCourseOverlay, self.baseHud)
    self.clearCacheBtn:setPosition(rightX - width - self.wMargin/2, rightY - btnYOffset)
    self.clearCacheBtn:setCallback("onClickPrimary", self.vehicle, function (vehicle)
        CpBaseHud.courseCache = nil
    end)

    self.copyCacheText = CpTextHudElement.new(self.baseHud, leftX, leftY,self.defaultFontSize)

end

function CpBaseHud:moveToPosition(element, x, y)
    CpBaseHud.x = x 
    CpBaseHud.y = y
end

function CpBaseHud:openClose(open)
    self.baseHud:setVisible(open)
    if open then 
        self.baseHud:setPosition(CpBaseHud.x, CpBaseHud.y)
    end
end

function CpBaseHud:getIsOpen()
    return self.baseHud:getVisible()
end

function CpBaseHud:mouseEvent(posX, posY, isDown, isUp, button)
    if not self.baseHud:getVisible() or self.baseHud:getIsDisabled() then 
        return
    end
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

    self.fieldworkLayout:setVisible(not (self.vehicle:getCanStartCpBaleFinder() or self.vehicle:getCanStartCpCombineUnloader()))
    self.fieldworkLayout:setDisabled(self.vehicle:getCanStartCpBaleFinder() or self.vehicle:getCanStartCpCombineUnloader())
    self.baleFinderLayout:setVisible(self.vehicle:getCanStartCpBaleFinder())
    self.baleFinderLayout:setDisabled(not self.vehicle:getCanStartCpBaleFinder())
    self.combineUnloaderLayout:setVisible(self.vehicle:getCanStartCpCombineUnloader())
    self.combineUnloaderLayout:setDisabled(not self.vehicle:getCanStartCpCombineUnloader())

    self.courseNameBtn:setTextDetails(self.vehicle:getCurrentCpCourseName())
    local isCourseNameBtnDisabled = self.vehicle:getCanStartCpCombineUnloader() or self.vehicle:getCanStartCpBaleFinder() and not self.vehicle:hasCpCourse()
    self.courseNameBtn:setDisabled(isCourseNameBtnDisabled)
    self.courseNameBtn:setVisible(not isCourseNameBtnDisabled)

    self.goalBtn:setDisabled(not self.fieldworkLayout:getIsDisabled())
    self.goalBtn:setVisible(not self.fieldworkLayout:getVisible())

    self.vehicleNameBtn:setTextDetails(self.vehicle:getName())
    if self.vehicle:hasCpCourse() then 
        self.startingPointBtn:setDisabled(false)
        self.startingPointBtn:setTextDetails(self.vehicle:getCpStartingPointSetting():getString())
    elseif self.vehicle:getCanStartCpBaleFinder() or self.vehicle:getCanStartCpCombineUnloader() then 
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
    end
    self.clearCourseBtn:setVisible(self.vehicle:hasCpCourse() and not self.vehicle:getIsCpActive() and not self.vehicle:getCanStartCpCombineUnloader())
    self.onOffButton:setVisible((self.vehicle:getCanStartCp() or self.vehicle:getIsCpActive()) and not self.vehicle:getIsCpCourseRecorderActive())

    if self.vehicle:getIsCpCourseRecorderActive() then
        self.startStopRecordingBtn:setColor(unpack(CpBaseHud.RECORDER_ON_COLOR))
    else 
        self.startStopRecordingBtn:setColor(unpack(CpBaseHud.OFF_COLOR))
    end
    self.startStopRecordingBtn:setVisible(self.vehicle:getCanStartCpCourseRecorder())

    self.waypointProgressBtn:setTextDetails(status:getWaypointText())
    self.waypointProgressBtn:setDisabled(self.vehicle:getCanStartCpCombineUnloader())
    self.waypointProgressBtn:setVisible(not self.vehicle:getCanStartCpCombineUnloader())

    local laneOffset = self.vehicle:getCpLaneOffsetSetting()
    self.laneOffsetBtn:setVisible(laneOffset:getCanBeChanged())
    self.laneOffsetBtn:setTextDetails(laneOffset:getString())

    local workWidth = self.vehicle:getCourseGeneratorSettings().workWidth
    self.workWidthBtn:setTextDetails(workWidth:getTitle(), workWidth:getString())

    self.workWidthBtn:setVisible(workWidth:getIsVisible())
    

    local toolOffsetX = self.vehicle:getCpSettings().toolOffsetX
    local text = toolOffsetX:getIsDisabled() and CpBaseHud.automaticText or toolOffsetX:getString()
    self.toolOffsetXBtn:setTextDetails(toolOffsetX:getTitle(), text)
    self.toolOffsetXBtn:setDisabled(toolOffsetX:getIsDisabled())

    
    local toolOffsetZ = self.vehicle:getCpSettings().toolOffsetZ
    self.toolOffsetZBtn:setTextDetails(toolOffsetZ:getTitle(), toolOffsetZ:getString())
    self.toolOffsetZBtn:setDisabled(toolOffsetZ:getIsDisabled())

    local fullThreshold = self.vehicle:getCpCombineUnloaderJobParameters().fullThreshold
    self.fullThresholdBtn:setTextDetails(fullThreshold:getTitle(), fullThreshold:getString())
    self.fullThresholdBtn:setDisabled(fullThreshold:getIsDisabled())

    local useGiantsUnload = self.vehicle:getCpCombineUnloaderJobParameters().useGiantsUnload
    self.giantsUnloadStationText:setVisible(useGiantsUnload:getValue() and not useGiantsUnload:getIsDisabled())
    self.giantsUnloadStationText:setDisabled(not useGiantsUnload:getValue() or self.vehicle:getIsCpActive())
    local giantsUnloadStation = self.vehicle:getCpCombineUnloaderJobParameters().unloadingStation
    self.giantsUnloadStationText:setTextDetails(giantsUnloadStation:getString())

    self.activateGiantsUnloadBtn:setColor(useGiantsUnload:getValue() and unpack(CpBaseHud.ON_COLOR) or unpack(CpBaseHud.OFF_COLOR))
    self.activateGiantsUnloadBtn:setVisible(not useGiantsUnload:getIsDisabled())
    self.activateGiantsUnloadBtn:setDisabled(useGiantsUnload:getIsDisabled() or self.vehicle:getIsCpActive())

    local fillLevelPercentage = FillLevelManager.getTotalTrailerFillLevelPercentage(self.vehicle)
    if fillLevelPercentage > 0.01 then 
        self.driveNowBtn:setColor(unpack(CpBaseHud.SEMI_ON_COLOR))    
    else
        self.driveNowBtn:setColor(unpack(CpBaseHud.OFF_COLOR))
    end
    self.driveNowBtn:setDisabled(not self.vehicle:getIsCpActive())
    self.driveNowBtn:setVisible(self.vehicle:getIsCpActive())
    local baleWrapType = self.vehicle:getCpBaleFinderJobParameters().baleWrapType
    self.baleFinderFillTypeBtn:setTextDetails(baleWrapType:getTitle(), baleWrapType:getString())

    self.baleFinderFillTypeBtn:setVisible(baleWrapType:getIsVisible())

    if self.vehicle:hasCpCourse() then 
        self.courseVisibilityBtn:setVisible(true)
        local value = self.vehicle:getCpSettings().showCourse:getValue()
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

    self:updateCopyBtn(status)


    self.baseHud:draw()
end

function CpBaseHud:updateCopyBtn(status)
    if self.courseCache and not self.vehicle:getCanStartCpCombineUnloader() then 
        local courseName =  CpCourseManager.getCourseName(self.courseCache)
        self.copyCacheText:setTextDetails(self.copyText .. courseName)
        self.clearCacheBtn:setVisible(true)
        self.pasteButton:setVisible(true)
        self.copyButton:setVisible(false)
        if self.vehicle:hasCpCourse() then 
            self.copyCacheText:setTextColorChannels(unpack(self.OFF_COLOR))
            self.pasteButton:setColor(unpack(self.OFF_COLOR))
        else 
            self.copyCacheText:setTextColorChannels(unpack(self.WHITE_COLOR))
            self.pasteButton:setColor(unpack(self.ON_COLOR))
        end
        self.copyButton:setDisabled(false)
        self.pasteButton:setDisabled(false)
        self.clearCacheBtn:setDisabled(false)
    else
        self.copyCacheText:setTextDetails("")
        self.clearCacheBtn:setVisible(false)
        self.pasteButton:setVisible(false)
        self.copyButton:setVisible(self.vehicle:hasCpCourse() and not self.vehicle:getCanStartCpCombineUnloader())
        self.copyButton:setDisabled(self.vehicle:getCanStartCpCombineUnloader())
        self.copyButton:setDisabled(self.vehicle:getCanStartCpCombineUnloader())
        self.pasteButton:setDisabled(self.vehicle:getCanStartCpCombineUnloader())
        self.clearCacheBtn:setDisabled(self.vehicle:getCanStartCpCombineUnloader())
    end
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
    inGameMenu.pageAI.hudVehicle = self.vehicle
    if g_gui.currentGuiName ~= "InGameMenu" then
		g_gui:showGui("InGameMenu")
	end
    return inGameMenu
end

function CpBaseHud:openCourseManagerGui(vehicle)
    local inGameMenu = self:preOpeningInGameMenu(vehicle)
    local courseManagerPageIx = inGameMenu.pagingElement:getPageMappingIndexByElement(inGameMenu.pageCpCourseManager)
    inGameMenu.pageSelector:setState(courseManagerPageIx, true)
end

function CpBaseHud:openCourseGeneratorGui(vehicle)
    local inGameMenu = self:preOpeningInGameMenu(vehicle)
    local pageAI = inGameMenu.pageAI
    --- Opens the ai inGame menu
    inGameMenu:goToPage(pageAI)
    local hotspot = self.vehicle:getMapHotspot()
    pageAI:setMapSelectionItem(hotspot)
    self:debug("opened ai inGame menu.")
    if self.vehicle:getIsCpActive() or not g_currentMission:getHasPlayerPermission("hireAssistant") then 
        return
    end
    self:debug("opened ai inGame job creation.")
    self.vehicle:updateAIFieldWorkerImplementData()
    pageAI:onCreateJob()
    for _, job in pairs(pageAI.jobTypeInstances) do 
        if job:isa(CpAIJobFieldWork) and job:getIsAvailableForVehicle(vehicle) then 
            local jobTypeIndex = g_currentMission.aiJobTypeManager:getJobTypeIndex(job)
            self:debug("opened ai inGame menu job %s.", job:getDescription())
            pageAI.currentJob = nil
            pageAI:setActiveJobTypeSelection(jobTypeIndex)
            pageAI.currentJob:applyCurrentState(vehicle, g_currentMission, g_currentMission.player.farmId, false, pageAI.currentJob:getCanGenerateFieldWorkCourse())
            pageAI:updateParameterValueTexts()
            pageAI:validateParameters()
            --- Fixes the job selection gui element.
            local currentIndex = table.findListElementFirstIndex(pageAI.currentJobTypes, jobTypeIndex, 1)
            pageAI.jobTypeElement:setState(currentIndex)
            if not vehicle:hasCpCourse() then 
                if pageAI.currentJob:getCanGenerateFieldWorkCourse() then 
                    self:debug("opened ai inGame menu course generator.")
                    pageAI:onClickOpenCloseCourseGenerator()
                end
            end
            break
        end
    end
    --- Moves the map, so the selected vehicle is directly visible.
    local worldX, _, worldZ = getWorldTranslation(vehicle.rootNode)
    CpGuiUtil.movesMapCenterTo(pageAI.ingameMap, worldX, worldZ)
end

function CpBaseHud:openVehicleSettingsGui(vehicle)
    local inGameMenu = self:preOpeningInGameMenu(vehicle)
    inGameMenu:goToPage(inGameMenu.pageCpVehicleSettings)
end

function CpBaseHud:openGlobalSettingsGui(vehicle)
    local inGameMenu = self:preOpeningInGameMenu(vehicle)
    inGameMenu:goToPage(inGameMenu.pageCpGlobalSettings)
end

--- Saves hud position.
function CpBaseHud.saveToXmlFile(xmlFile, baseKey)
    if CpBaseHud.x ~= nil and CpBaseHud.y ~= nil then
        xmlFile:setValue(baseKey..CpBaseHud.xmlKey.."#posX", CpBaseHud.x)
        xmlFile:setValue(baseKey..CpBaseHud.xmlKey.."#posY", CpBaseHud.y)
    end
end

--- Loads hud position.
function CpBaseHud.loadFromXmlFile(xmlFile, baseKey)
    local posX = xmlFile:getValue(baseKey..CpBaseHud.xmlKey.."#posX")
    local posY = xmlFile:getValue(baseKey..CpBaseHud.xmlKey.."#posY")
    if posX ~= nil and posY ~= nil then 
        CpBaseHud.savedPositions = {
           posX, posY
        }
    end
end

function CpBaseHud:debug(str, ...)
    CpUtil.debugVehicle(CpDebug.DBG_HUD, self.vehicle, "Hud: "..str, ...)    
end