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
    pauseSymbol = {
        {40, 328, 32, 32}, {256, 512}
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
CpBaseHud.copyPasteCache = {
    siloLoaderVehicle = nil,
    combineUnloaderVehicle = nil,
    hasVehicle = false
}

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

    self.fieldworkLayout = self:addHudPage(CpFieldWorkHudPageElement, vehicle)

    self.baleFinderLayout = self:addHudPage(CpBaleFinderHudPageElement, vehicle)

    self.combineUnloaderLayout = self:addHudPage(CpCombineUnloaderHudPageElement, vehicle)
   
    self.bunkerSiloWorkerLayout = self:addHudPage(CpBunkerSiloWorkerHudPageElement, vehicle)

    self.siloLoaderWorkerLayout = self:addHudPage(CpSiloLoaderWorkerHudPageElement, vehicle)

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
                                self:executeStartingPointBtnCallback(vehicle)
                            end,self.vehicle)

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
    self.onOffButton:setCallback("onClickPrimary", self.vehicle, function(vehicle)
        vehicle:cpStartStopDriver(true)
    end)
    
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
    
    --- Create start/stop field boarder record button
    local circleOverlay = CpGuiUtil.createOverlay({recordingBtnWidth, height},
                                                {imageFilename, GuiUtils.getUVs(unpack(self.uvs.pauseSymbol))}, 
                                                self.OFF_COLOR,
                                                self.alignments.bottomRight)
    self.pauseRecordingBtn = CpHudButtonElement.new(circleOverlay, self.baseHud)
    local x, y = unpack(self.lines[6].right)
    self.pauseRecordingBtn:setPosition(x, y)
    self.pauseRecordingBtn:setCallback("onClickPrimary", self.vehicle, function (vehicle)
        if vehicle:getIsCpCourseRecorderActive() then 
            vehicle:toggleCpCourseRecorderPause()
        end
    end)


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

function CpBaseHud:addHudPage(class, vehicle)
    local layout = class.new(nil, self.baseHud)
    layout:setPosition(CpBaseHud.x, CpBaseHud.y)
    layout:setDimension(self.width, self.height)
    layout:setupElements(self, vehicle, self.lines, self.wMargin, self.hMargin)
    return layout
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

function CpBaseHud:getActiveHudPage(vehicle)
    if vehicle:getCanStartCpCombineUnloader() then
        return self.combineUnloaderLayout
    elseif vehicle:getCanStartCpBaleFinder() and not vehicle:hasCpCourse() then
        return self.baleFinderLayout
    elseif vehicle:getCanStartCpSiloLoaderWorker() and (vehicle:getCpStartingPointSetting():getValue() == CpJobParameters.START_AT_SILO_LOADING
        or AIUtil.hasChildVehicleWithSpecialization(vehicle, ConveyorBelt)) then 
        return self.siloLoaderWorkerLayout
    elseif vehicle:getCanStartCpBunkerSiloWorker() and (vehicle:getCpStartingPointSetting():getValue() == CpJobParameters.START_AT_BUNKER_SILO or
        (AIUtil.hasChildVehicleWithSpecialization(vehicle, Leveler)
        and not AIUtil.hasChildVehicleWithSpecialization(vehicle, Shovel))) then
        return self.bunkerSiloWorkerLayout
    else
        return self.fieldworkLayout
    end
end

function CpBaseHud:isBunkerSiloLayoutActive()
    return self.bunkerSiloWorkerLayout:getVisible()
end

function CpBaseHud:isSiloLoaderLayoutActive()
    return self.siloLoaderWorkerLayout:getVisible()
end

function CpBaseHud:isCombineUnloaderLayoutActive()
    return self.combineUnloaderLayout:getVisible()
end


---@param status CpStatus
function CpBaseHud:draw(status)
    self:updateContent(self.vehicle, status)
    self.baseHud:draw()
end

function CpBaseHud:updateContent(vehicle, status)
    self.vehicleNameBtn:setTextDetails(vehicle:getName())

    if status:getIsActive() then
        self.onOffButton:setColor(unpack(CpBaseHud.ON_COLOR))
    else
        self.onOffButton:setColor(unpack(CpBaseHud.OFF_COLOR))
    end
    
    self.onOffButton:setVisible((vehicle:getCanStartCp() or vehicle:getIsCpActive()) and not vehicle:getIsCpCourseRecorderActive())

    if self.vehicle:getIsCpCourseRecorderActive() then
        self.startStopRecordingBtn:setColor(unpack(CpBaseHud.RECORDER_ON_COLOR))
        self.pauseRecordingBtn:setVisible(true)
        if self.vehicle:getIsCpCourseRecorderPaused() then
            self.pauseRecordingBtn:setColor(unpack(CpBaseHud.RECORDER_ON_COLOR))
        else 
            self.pauseRecordingBtn:setColor(unpack(CpBaseHud.OFF_COLOR))
        end
    else 
        self.startStopRecordingBtn:setColor(unpack(CpBaseHud.OFF_COLOR))
        self.pauseRecordingBtn:setVisible(false)
    end
    self.startStopRecordingBtn:setVisible(vehicle:getCanStartCpCourseRecorder())

    self.fieldworkLayout:setVisible(false)
    self.fieldworkLayout:setDisabled(true)
    self.baleFinderLayout:setVisible(false)
    self.baleFinderLayout:setDisabled(true)
    self.combineUnloaderLayout:setVisible(false)
    self.combineUnloaderLayout:setDisabled(true)
    self.bunkerSiloWorkerLayout:setVisible(false)
    self.bunkerSiloWorkerLayout:setDisabled(true)
    self.siloLoaderWorkerLayout:setVisible(false)
    self.siloLoaderWorkerLayout:setDisabled(true)

    local activeLayout = self:getActiveHudPage(vehicle)
    activeLayout:setVisible(true)
    activeLayout:setDisabled(false)
    activeLayout:updateContent(vehicle, status)

    self.startingPointBtn:setDisabled(true)
    if activeLayout.isStartingPointBtnDisabled then 
        self.startingPointBtn:setDisabled(activeLayout:isStartingPointBtnDisabled(vehicle))
    end
    self.startingPointBtn:setVisible(true)
    if activeLayout.isStartingPointBtnVisible then 
        self.startingPointBtn:setVisible(activeLayout:isStartingPointBtnVisible(vehicle))
    end
    self.startingPointBtn:setTextDetails(vehicle:getCpStartText())
    if activeLayout.getStartingPointBtnText then 
        self.startingPointBtn:setTextDetails(activeLayout:getStartingPointBtnText(vehicle))
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

function CpBaseHud:openCourseManagerGui(vehicle)
    CpGuiUtil.openCourseManagerGui(vehicle)
end

function CpBaseHud:openCourseGeneratorGui(vehicle)
    CpGuiUtil.openCourseGeneratorGui(vehicle)
end

function CpBaseHud:openVehicleSettingsGui(vehicle)
    CpGuiUtil.openVehicleSettingsGui(vehicle)
end

function CpBaseHud:openGlobalSettingsGui(vehicle)
    CpGuiUtil.openGlobalSettingsGui(vehicle)
end

function CpBaseHud:executeStartingPointBtnCallback(vehicle)
    local activeLayout = self:getActiveHudPage(vehicle)
    if activeLayout and activeLayout.executeStartingPointBtnCallback then 
        activeLayout:executeStartingPointBtnCallback(vehicle)
    else
        vehicle:getCpStartingPointSetting():setNextItem()   
    end
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