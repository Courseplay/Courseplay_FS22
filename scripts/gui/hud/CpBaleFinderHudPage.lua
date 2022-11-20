--- Bale finder Hud page
---@class CpHudPageElement : CpHudElement
CpBaleFinderHudPageElement = {}
local CpBaleFinderHudPageElement_mt = Class(CpBaleFinderHudPageElement, CpHudPageElement)

function CpBaleFinderHudPageElement.new(overlay, parentHudElement, customMt)
    local self = CpHudPageElement.new(overlay, parentHudElement, customMt or CpBaleFinderHudPageElement_mt)
        
    
    return self
end

function CpBaleFinderHudPageElement:setupElements(baseHud, vehicle, lines, wMargin, hMargin)
	--- Tool offset x
	self.toolOffsetXBtn = baseHud:addLineTextButton(self, 2, CpBaseHud.defaultFontSize, 
												vehicle:getCpSettings().toolOffsetX)

    --- Bale finder fill type
    local x, y = unpack(lines[3].left)
    local xRight,_ = unpack(lines[3].right)
    self.baleFinderFillTypeBtn = CpHudTextSettingElement.new(self, x, y,
                                     xRight, CpBaseHud.defaultFontSize)
    local callback = {
        callbackStr = "onClickPrimary",
        class =  vehicle:getCpBaleFinderJobParameters().baleWrapType,
        func =   vehicle:getCpBaleFinderJobParameters().baleWrapType.setNextItem,
    }
    self.baleFinderFillTypeBtn:setCallback(callback, callback)             
    
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

function CpBaleFinderHudPageElement:update(dt)
	CpBaleFinderHudPageElement:superClass().update(self, dt)
	
end

function CpBaleFinderHudPageElement:updateContent(vehicle, status)
    local toolOffsetX = vehicle:getCpSettings().toolOffsetX
    local text = toolOffsetX:getIsDisabled() and CpBaseHud.automaticText or toolOffsetX:getString()
    self.toolOffsetXBtn:setTextDetails(toolOffsetX:getTitle(), text)
    self.toolOffsetXBtn:setDisabled(toolOffsetX:getIsDisabled())    

    
    local baleWrapType = vehicle:getCpBaleFinderJobParameters().baleWrapType
    self.baleFinderFillTypeBtn:setTextDetails(baleWrapType:getTitle(), baleWrapType:getString())

    self.baleFinderFillTypeBtn:setVisible(baleWrapType:getIsVisible())

    CpGuiUtil.updateCopyBtn(self, vehicle, status)
end
