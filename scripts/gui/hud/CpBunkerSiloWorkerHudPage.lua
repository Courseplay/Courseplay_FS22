--- Bunker silo worker Hud page
---@class CpBunkerSiloWorkerHudPageElement : CpHudElement
CpBunkerSiloWorkerHudPageElement = {}
local CpBunkerSiloWorkerHudPageElement_mt = Class(CpBunkerSiloWorkerHudPageElement, CpHudPageElement)

function CpBunkerSiloWorkerHudPageElement.new(overlay, parentHudElement, customMt)
    local self = CpHudPageElement.new(overlay, parentHudElement, customMt or CpBunkerSiloWorkerHudPageElement_mt)
    return self
end

function CpBunkerSiloWorkerHudPageElement:setupElements(baseHud, vehicle, lines, wMargin, hMargin)

		
	--- Driving direction
	local x, y = unpack(lines[4].left)
	local xRight,_ = unpack(lines[4].right)
	self.driveDirectionBtn = CpHudTextSettingElement.new(self, x, y,
										xRight, CpBaseHud.defaultFontSize)
	local callback = {
		callbackStr = "onClickPrimary",
		class =  vehicle:getCpBunkerSiloWorkerJobParameters().drivingForwardsIntoSilo,
		func =   vehicle:getCpBunkerSiloWorkerJobParameters().drivingForwardsIntoSilo.setNextItem,
	}
	self.driveDirectionBtn:setCallback(callback, callback)             			
    
    --- Waiting at park position
	local x, y = unpack(lines[2].left)
	local xRight,_ = unpack(lines[2].right)
	self.waitAtBtn = CpHudTextSettingElement.new(self, x, y,
										xRight, CpBaseHud.defaultFontSize)
	local callback = {
		callbackStr = "onClickPrimary",
		class =  vehicle:getCpBunkerSiloWorkerJobParameters().waitAtParkPosition,
		func =   vehicle:getCpBunkerSiloWorkerJobParameters().waitAtParkPosition.setNextItem,
	}
	self.waitAtBtn:setCallback(callback, callback)             				
	
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

function CpBunkerSiloWorkerHudPageElement:update(dt)
	CpBunkerSiloWorkerHudPageElement:superClass().update(self, dt)
	
end

function CpBunkerSiloWorkerHudPageElement:updateContent(vehicle, status)
   
	local driveDirection = vehicle:getCpBunkerSiloWorkerJobParameters().drivingForwardsIntoSilo
    self.driveDirectionBtn:setTextDetails(driveDirection:getTitle(), driveDirection:getString())
    self.driveDirectionBtn:setVisible(driveDirection:getIsVisible())
    self.driveDirectionBtn:setDisabled(driveDirection:getIsDisabled())

    local waitAt = vehicle:getCpBunkerSiloWorkerJobParameters().waitAtParkPosition
    self.waitAtBtn:setTextDetails(waitAt:getTitle(), waitAt:getString())
    self.waitAtBtn:setVisible(waitAt:getIsVisible())
    self.waitAtBtn:setDisabled(waitAt:getIsDisabled())

	local workWidth = vehicle:getCpSettings().bunkerSiloWorkWidth
    self.workWidthBtn:setTextDetails(workWidth:getTitle(), workWidth:getString())
    self.workWidthBtn:setVisible(workWidth:getIsVisible())

    CpGuiUtil.updateCopyBtn(self, vehicle, status)
end

function CpBunkerSiloWorkerHudPageElement:isStartingPointBtnDisabled(vehicle)
    return AIUtil.hasAIImplementWithSpecialization(vehicle, Leveler)
end
