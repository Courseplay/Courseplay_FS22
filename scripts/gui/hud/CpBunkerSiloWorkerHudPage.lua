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
    self.driveDirectionBtn = baseHud:addLineTextButton(self, 4, CpBaseHud.defaultFontSize, 
        vehicle:getCpBunkerSiloWorkerJobParameters().drivingForwardsIntoSilo)  			
    
    --- Leveler height offset.
    self.levelerHeightOffsetBtn = baseHud:addLineTextButtonWithIncrementalButtons(self, 4, CpBaseHud.defaultFontSize, 
        vehicle:getCpSettings().levelerHeightOffset) 

    --- Waiting at park position
    self.waitAtBtn = baseHud:addLineTextButton(self, 1, CpBaseHud.defaultFontSize, 
        vehicle:getCpBunkerSiloWorkerJobParameters().waitAtParkPosition)  	

    --- Work width
    self.workWidthBtn = baseHud:addLineTextButtonWithIncrementalButtons(self, 2, CpBaseHud.defaultFontSize, 
                                                vehicle:getCpSettings().bunkerSiloWorkWidth) 

    --- Bunker silo compaction percentage
    local x, y = unpack(lines[3].left)
	local xRight,_ = unpack(lines[3].right)
	self.compactionPercentageBtn = CpHudTextSettingElement.new(self, x, y,
										xRight, CpBaseHud.defaultFontSize)
	local callback = {
		callbackStr = "onClickPrimary",
		class =  vehicle:getCpBunkerSiloWorkerJobParameters().stopWithCompactedSilo,
		func =   vehicle:getCpBunkerSiloWorkerJobParameters().stopWithCompactedSilo.setNextItem,
	}
	self.compactionPercentageBtn:setCallback(callback, callback)             				
end

function CpBunkerSiloWorkerHudPageElement:update(dt)
	CpBunkerSiloWorkerHudPageElement:superClass().update(self, dt)
	
end

---@param vehicle table
---@param status CpStatus
function CpBunkerSiloWorkerHudPageElement:updateContent(vehicle, status)
   
	local driveDirection = vehicle:getCpBunkerSiloWorkerJobParameters().drivingForwardsIntoSilo
    self.driveDirectionBtn:setTextDetails(driveDirection:getTitle(), driveDirection:getString())
    self.driveDirectionBtn:setVisible(driveDirection:getIsVisible())
    self.driveDirectionBtn:setDisabled(not driveDirection:getIsVisible())

    local heightOffset = vehicle:getCpSettings().levelerHeightOffset
    self.levelerHeightOffsetBtn:setTextDetails(heightOffset:getTitle(), heightOffset:getString())
    self.levelerHeightOffsetBtn:setDisabled(heightOffset:getIsDisabled())
    self.levelerHeightOffsetBtn:setVisible(heightOffset:getIsVisible())

    local waitAt = vehicle:getCpBunkerSiloWorkerJobParameters().waitAtParkPosition
    self.waitAtBtn:setTextDetails(waitAt:getTitle(), waitAt:getString())
    self.waitAtBtn:setVisible(waitAt:getIsVisible())
    self.waitAtBtn:setDisabled(waitAt:getIsDisabled())

	local workWidth = vehicle:getCpSettings().bunkerSiloWorkWidth
    self.workWidthBtn:setTextDetails(workWidth:getTitle(), workWidth:getString())
    self.workWidthBtn:setVisible(workWidth:getIsVisible())

    local compactionText 
    local stopWithCompactedSilo = vehicle:getCpBunkerSiloWorkerJobParameters().stopWithCompactedSilo
    if stopWithCompactedSilo:getValue() then
        compactionText = string.format("%s/99%%", status:getCompactionText(true))
    else
        compactionText = status:getCompactionText()
    end
    self.compactionPercentageBtn:setTextDetails(g_i18n:getText("CP_bunkerSilo_compactionPercentage"), compactionText)
    self.compactionPercentageBtn:setDisabled(stopWithCompactedSilo:getIsDisabled())
end
