--- Bale finder Hud page
---@class CpSiloLoaderWorkerHudPageElement : CpHudPageElement
CpSiloLoaderWorkerHudPageElement = {}
local CpSiloLoaderWorkerHudPageElement_mt = Class(CpSiloLoaderWorkerHudPageElement, CpHudPageElement)

function CpSiloLoaderWorkerHudPageElement.new(overlay, parentHudElement, customMt)
    ---@class CpSiloLoaderWorkerHudPageElement : CpHudPageElement
    ---@field copyButton CpHudButtonElement
    ---@field pasteButton CpHudButtonElement
    ---@field clearCacheBtn CpHudButtonElement
    ---@field copyCacheText CpTextHudElement
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

    CpGuiUtil.addCopyAndPasteButtons(self, baseHud, 
    vehicle, lines, wMargin, hMargin, 1)

    self.copyButton:setCallback("onClickPrimary", vehicle, function (vehicle)
        if not CpBaseHud.copyPasteCache.hasVehicle and vehicle.getCpCombineUnloaderJob then 
            CpBaseHud.copyPasteCache.siloLoaderVehicle = vehicle
            CpBaseHud.copyPasteCache.hasVehicle = true
        end
    end)


    self.pasteButton:setCallback("onClickPrimary", vehicle, function (vehicle)
        if CpBaseHud.copyPasteCache.hasVehicle and not vehicle:getIsCpActive() then 
            if CpBaseHud.copyPasteCache.siloLoaderVehicle then 
                vehicle:applyCpSiloLoaderWorkerJobParameters(CpBaseHud.copyPasteCache.siloLoaderVehicle:getCpSiloLoaderWorkerJob())
            else 
                local parameters = CpBaseHud.copyPasteCache.combineUnloaderVehicle:getCpCombineUnloaderJobParameters()
                vehicle:getCpSiloLoaderWorkerJobParameters().loadPosition:copy(parameters.fieldUnloadPosition)
            end
        end
    end)

    self.clearCacheBtn:setCallback("onClickPrimary", vehicle, function (vehicle)
        CpBaseHud.copyPasteCache.hasVehicle = false
        CpBaseHud.copyPasteCache.siloLoaderVehicle = nil 
        CpBaseHud.copyPasteCache.combineUnloaderVehicle = nil
    end)
end

function CpSiloLoaderWorkerHudPageElement:update(dt)
	CpSiloLoaderWorkerHudPageElement:superClass().update(self, dt)
	
end

function CpSiloLoaderWorkerHudPageElement:updateContent(vehicle, status)
    local workWidth = vehicle:getCpSettings().bunkerSiloWorkWidth
    self.workWidthBtn:setTextDetails(workWidth:getTitle(), workWidth:getString())
    self.workWidthBtn:setVisible(workWidth:getIsVisible())

    --- Update copy and paste buttons
    self:updateCopyButtons(vehicle)
end

function CpSiloLoaderWorkerHudPageElement:updateCopyButtons(vehicle)
    if CpBaseHud.copyPasteCache.hasVehicle then 
        local copyCacheVehicle, arePositionEqual
        if CpBaseHud.copyPasteCache.siloLoaderVehicle then 
            copyCacheVehicle = CpBaseHud.copyPasteCache.siloLoaderVehicle
            arePositionEqual = self:arePositionEqual(vehicle:getCpSiloLoaderWorkerJobParameters(), 
                copyCacheVehicle:getCpSiloLoaderWorkerJobParameters())
        else
            copyCacheVehicle = CpBaseHud.copyPasteCache.combineUnloaderVehicle
            local unloadPosition = copyCacheVehicle:getCpCombineUnloaderJobParameters().fieldUnloadPosition
            local loadPosition = vehicle:getCpSiloLoaderWorkerJobParameters().loadPosition
            arePositionEqual = unloadPosition:isAlmostEqualTo(loadPosition)

        end
        local fieldNum = CpFieldUtil.getFieldNumUnderVehicle(copyCacheVehicle)
        local text = CpUtil.getName(copyCacheVehicle)
        if fieldNum then 
            text = string.format("%s(%s)", text, fieldNum)
        end
        self.copyCacheText:setTextDetails(text)
        self.clearCacheBtn:setVisible(true)
        self.pasteButton:setVisible(true)
        self.copyButton:setVisible(false)
        if vehicle:getIsCpActive() or arePositionEqual then 
            self.copyCacheText:setTextColorChannels(unpack(CpBaseHud.OFF_COLOR))
            self.pasteButton:setColor(unpack(CpBaseHud.OFF_COLOR))
            self.pasteButton:setDisabled(true)
        else 
            self.copyCacheText:setTextColorChannels(unpack(CpBaseHud.WHITE_COLOR))
            self.pasteButton:setColor(unpack(CpBaseHud.ON_COLOR))
            self.pasteButton:setDisabled(false)
        end
    else
        self.copyCacheText:setTextDetails("")
        self.clearCacheBtn:setVisible(false)
        self.pasteButton:setVisible(false)
        self.copyButton:setVisible(true)
    end
end

function CpSiloLoaderWorkerHudPageElement:arePositionEqual(parameters, otherParameters)
    if not parameters.loadPosition:isAlmostEqualTo(otherParameters.loadPosition) then 
        return false
    end 
    if not parameters.startPosition:isAlmostEqualTo(otherParameters.startPosition) then 
        return false
    end
    return true 
end