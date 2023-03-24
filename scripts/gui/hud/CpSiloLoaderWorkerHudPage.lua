--- Bale finder Hud page
---@class CpSiloLoaderWorkerHudPageElement : CpHudElement
CpSiloLoaderWorkerHudPageElement = {}
local CpSiloLoaderWorkerHudPageElement_mt = Class(CpSiloLoaderWorkerHudPageElement, CpHudPageElement)

function CpSiloLoaderWorkerHudPageElement.new(overlay, parentHudElement, customMt)
    local self = CpHudPageElement.new(overlay, parentHudElement, customMt or CpSiloLoaderWorkerHudPageElement_mt)
        
    return self
end

function CpSiloLoaderWorkerHudPageElement:setupElements(baseHud, vehicle, lines, wMargin, hMargin)
	
    --- Work width
    self.workWidthBtn = baseHud:addLineTextButton(self, 3, CpBaseHud.defaultFontSize, 
                                                vehicle:getCpSettings().bunkerSiloWorkWidth) 

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

    CpGuiUtil.addCopyCourseBtn(self, baseHud, vehicle, lines, wMargin, hMargin, 1)
end

function CpSiloLoaderWorkerHudPageElement:update(dt)
	CpSiloLoaderWorkerHudPageElement:superClass().update(self, dt)
	
end

function CpSiloLoaderWorkerHudPageElement:updateContent(vehicle, status)
    local workWidth = vehicle:getCpSettings().bunkerSiloWorkWidth
    self.workWidthBtn:setTextDetails(workWidth:getTitle(), workWidth:getString())
    self.workWidthBtn:setVisible(workWidth:getIsVisible())


    CpGuiUtil.updateCopyBtn(self, vehicle, status)
end
