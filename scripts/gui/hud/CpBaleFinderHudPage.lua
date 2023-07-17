--- Bale finder Hud page
---@class CpBaleFinderHudPageElement : CpHudElement
CpBaleFinderHudPageElement = {}
local CpBaleFinderHudPageElement_mt = Class(CpBaleFinderHudPageElement, CpHudPageElement)

function CpBaleFinderHudPageElement.new(overlay, parentHudElement, customMt)
    local self = CpHudPageElement.new(overlay, parentHudElement, customMt or CpBaleFinderHudPageElement_mt)
        
    
    return self
end

function CpBaleFinderHudPageElement:setupElements(baseHud, vehicle, lines, wMargin, hMargin)
	--- Tool offset x
	self.toolOffsetXBtn = baseHud:addLineTextButton(self, 2, CpBaseHud.defaultFontSize, 
												vehicle:getCpSettings().baleCollectorOffset)

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

    --- Bale progress of how much bales have bin worked on, similar to waypoint progress.
	self.balesProgressBtn = baseHud:addRightLineTextButton(self, 4, CpBaseHud.defaultFontSize, 
        function(vehicle)
            baseHud:openCourseManagerGui(vehicle)
        end, vehicle)
    
    --- Bale progress of how much bales have bin worked on, similar to waypoint progress.
    local x, y = unpack(lines[4].left)
    self.balesProgressLabel = CpTextHudElement.new(self, x, y, CpBaseHud.defaultFontSize)
    self.balesProgressLabel:setTextDetails(g_i18n:getText("CP_baleFinder_balesLeftover"))
    
    CpGuiUtil.addCopyCourseBtn(self, baseHud, vehicle, lines, wMargin, hMargin, 1)    												
end

function CpBaleFinderHudPageElement:update(dt)
	CpBaleFinderHudPageElement:superClass().update(self, dt)
	
end

function CpBaleFinderHudPageElement:updateContent(vehicle, status)
    local baleCollectorOffset = vehicle:getCpSettings().baleCollectorOffset
    local text = baleCollectorOffset:getIsDisabled() and CpBaseHud.automaticText or baleCollectorOffset:getString()
    self.toolOffsetXBtn:setTextDetails(baleCollectorOffset:getTitle(), text)
    self.toolOffsetXBtn:setDisabled(baleCollectorOffset:getIsDisabled())    

    
    local baleWrapType = vehicle:getCpBaleFinderJobParameters().baleWrapType
    self.baleFinderFillTypeBtn:setTextDetails(baleWrapType:getTitle(), baleWrapType:getString())

    self.baleFinderFillTypeBtn:setVisible(baleWrapType:getIsVisible())

    self.balesProgressBtn:setTextDetails(status:getBalesText())

    CpGuiUtil.updateCopyBtn(self, vehicle, status)
end
