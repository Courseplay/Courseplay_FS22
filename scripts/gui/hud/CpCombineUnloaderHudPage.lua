--- CombineUnloader Hud page
---@class CpHudPageElement : CpHudElement
CpCombineUnloaderHudPageElement = {}
local CpCombineUnloaderHudPageElement_mt = Class(CpCombineUnloaderHudPageElement, CpHudPageElement)

function CpCombineUnloaderHudPageElement.new(overlay, parentHudElement, customMt)
    local self = CpHudPageElement.new(overlay, parentHudElement, customMt or CpCombineUnloaderHudPageElement_mt)
    return self
end

function CpCombineUnloaderHudPageElement:setupElements(baseHud, vehicle, lines, wMargin, hMargin)
    
    --- Tool offset x
	self.toolOffsetXBtn = baseHud:addLineTextButton(self, 2, CpBaseHud.defaultFontSize, 
												vehicle:getCpSettings().toolOffsetX)

    --- Tool offset z
    self.toolOffsetZBtn = baseHud:addLineTextButton(self, 1, CpBaseHud.defaultFontSize, 
                                                vehicle:getCpSettings().toolOffsetZ)

    --- Full threshold 
    self.fullThresholdBtn = baseHud:addLineTextButton(self, 3, CpBaseHud.defaultFontSize, 
                                                vehicle:getCpCombineUnloaderJobParameters().fullThreshold)              

    --- Giants unloading station
    local x, y = unpack(lines[4].left)
    self.giantsUnloadStationText = CpTextHudElement.new(self , x , y, CpBaseHud.defaultFontSize)                 
    self.giantsUnloadStationText:setCallback("onClickPrimary", vehicle, 
    function(vehicle)
        vehicle:getCpCombineUnloaderJobParameters().unloadingStation:setNextItem()
    end)

    --- Drive now button
    local width, height = getNormalizedScreenValues(22, 22)
    local driveNowBtnWidth, height = getNormalizedScreenValues(26, 30)
    local imageFilename = Utils.getFilename('img/ui_courseplay.dds', g_Courseplay.BASE_DIRECTORY)
    local driveNowOverlay = CpGuiUtil.createOverlay({driveNowBtnWidth, height},
                                                        {imageFilename, GuiUtils.getUVs(unpack(CpBaseHud.uvs.driveNowSymbol))}, 
                                                        CpBaseHud.OFF_COLOR,
                                                        CpBaseHud.alignments.bottomRight)
    self.driveNowBtn = CpHudButtonElement.new(driveNowOverlay, self)
    local x, y = unpack(lines[6].right)
    y = y - hMargin/4
    local driveNowBtnX = x - 2*width - wMargin/2 - wMargin/8
    self.driveNowBtn:setPosition(driveNowBtnX, y)
    self.driveNowBtn:setCallback("onClickPrimary", vehicle, function (vehicle)
        vehicle:startCpCombineUnloaderUnloading()
    end)

    --- Giants unload button
    local width, height = getNormalizedScreenValues(22, 22)
    local giantsUnloadOverlay = CpGuiUtil.createOverlay({width, height},
                                                        {AIHotspot.FILENAME, AIHotspot.UVS}, 
                                                        CpBaseHud.OFF_COLOR,
                                                        CpBaseHud.alignments.bottomRight)
    self.activateGiantsUnloadBtn = CpHudButtonElement.new(giantsUnloadOverlay, self)
    local _, y = unpack(lines[6].right)
    y = y - hMargin/16
    x = driveNowBtnX - driveNowBtnWidth - wMargin/8
    self.activateGiantsUnloadBtn:setPosition(x, y)
    self.activateGiantsUnloadBtn:setCallback("onClickPrimary", vehicle, function (vehicle)
        vehicle:getCpCombineUnloaderJobParameters().useGiantsUnload:setNextItem()
    end)

    --- Goal button.
    local width, height = getNormalizedScreenValues(37, 37)    
    local goalOverlay = CpGuiUtil.createOverlay({width, height},
                                                {AITargetHotspot.FILENAME, CpBaseHud.uvs.goalSymbol}, 
                                                CpBaseHud.OFF_COLOR,
                                                CpBaseHud.alignments.bottomRight)
    
    self.goalBtn = CpHudButtonElement.new(goalOverlay, self)
    local x, y = unpack(lines[4].right)
    self.goalBtn:setPosition(x, y + hMargin/2)
    self.goalBtn:setCallback("onClickPrimary", vehicle, function (vehicle)
        baseHud:openCourseGeneratorGui(vehicle)
    end)
end

function CpCombineUnloaderHudPageElement:update(dt)
	CpCombineUnloaderHudPageElement:superClass().update(self, dt)
	
end

function CpCombineUnloaderHudPageElement:updateContent(vehicle, status)
    local toolOffsetX = vehicle:getCpSettings().toolOffsetX
    local text = toolOffsetX:getIsDisabled() and CpBaseHud.automaticText or toolOffsetX:getString()
    self.toolOffsetXBtn:setTextDetails(toolOffsetX:getTitle(), text)
    self.toolOffsetXBtn:setDisabled(toolOffsetX:getIsDisabled())

    local toolOffsetZ = vehicle:getCpSettings().toolOffsetZ
    self.toolOffsetZBtn:setTextDetails(toolOffsetZ:getTitle(), toolOffsetZ:getString())
    self.toolOffsetZBtn:setDisabled(toolOffsetZ:getIsDisabled())

    local fullThreshold = vehicle:getCpCombineUnloaderJobParameters().fullThreshold
    self.fullThresholdBtn:setTextDetails(fullThreshold:getTitle(), fullThreshold:getString())
    self.fullThresholdBtn:setDisabled(fullThreshold:getIsDisabled())

    local useGiantsUnload = vehicle:getCpCombineUnloaderJobParameters().useGiantsUnload
    self.giantsUnloadStationText:setVisible(useGiantsUnload:getValue() and not useGiantsUnload:getIsDisabled())
    self.giantsUnloadStationText:setDisabled(not useGiantsUnload:getValue() or vehicle:getIsCpActive())
    local giantsUnloadStation = vehicle:getCpCombineUnloaderJobParameters().unloadingStation
    self.giantsUnloadStationText:setTextDetails(giantsUnloadStation:getString())

    self.activateGiantsUnloadBtn:setColor(useGiantsUnload:getValue() and unpack(CpBaseHud.ON_COLOR) or unpack(CpBaseHud.OFF_COLOR))
    self.activateGiantsUnloadBtn:setVisible(not useGiantsUnload:getIsDisabled())
    self.activateGiantsUnloadBtn:setDisabled(useGiantsUnload:getIsDisabled() or vehicle:getIsCpActive())

    local fillLevelPercentage = FillLevelManager.getTotalTrailerFillLevelPercentage(vehicle)
    if fillLevelPercentage > 0.01 then 
        self.driveNowBtn:setColor(unpack(CpBaseHud.SEMI_ON_COLOR))    
    else
        self.driveNowBtn:setColor(unpack(CpBaseHud.OFF_COLOR))
    end
    self.driveNowBtn:setDisabled(not vehicle:getIsCpActive())
    self.driveNowBtn:setVisible(vehicle:getIsCpActive())   
end