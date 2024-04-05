--- CombineUnloader Hud page
---@class CpCombineUnloaderHudPageElement : CpHudPageElement
CpCombineUnloaderHudPageElement = {
    copyCache = nil
}
local CpCombineUnloaderHudPageElement_mt = Class(CpCombineUnloaderHudPageElement, CpHudPageElement)

function CpCombineUnloaderHudPageElement.new(overlay, parentHudElement, customMt)
    ---@class CpCombineUnloaderHudPageElement : CpHudPageElement
    ---@field copyButton CpHudButtonElement
    ---@field pasteButton CpHudButtonElement
    ---@field clearCacheBtn CpHudButtonElement
    ---@field copyCacheText CpTextHudElement
    local self = CpHudPageElement.new(overlay, parentHudElement, customMt or CpCombineUnloaderHudPageElement_mt)
    return self
end

function CpCombineUnloaderHudPageElement:setupElements(baseHud, vehicle, lines, wMargin, hMargin)
    
    --- Tool offset x
	self.combineOffsetXBtn = baseHud:addLineTextButton(self, 3, CpBaseHud.defaultFontSize, 
												vehicle:getCpSettings().combineOffsetX)

    --- Tool offset z
    self.combineOffsetZBtn = baseHud:addLineTextButton(self, 2, CpBaseHud.defaultFontSize, 
                                                vehicle:getCpSettings().combineOffsetZ)

    --- Full threshold 
    self.fullThresholdBtn = baseHud:addLineTextButton(self, 4, CpBaseHud.defaultFontSize, 
                                                vehicle:getCpSettings().fullThreshold)              

    
    -- --- Giants unloading station
    -- local x, y = unpack(lines[5].left)
    -- self.giantsUnloadStationText = CpTextHudElement.new(self , x , y, CpBaseHud.defaultFontSize)                 
    -- self.giantsUnloadStationText:setCallback("onClickPrimary", vehicle, 
    -- function(vehicle)
    --     vehicle:getCpCombineUnloaderJobParameters().unloadingStation:setNextItem()
    -- end)

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

    CpGuiUtil.addCopyAndPasteButtons(self, baseHud, 
        vehicle, lines, wMargin, hMargin, 1)

    self.copyButton:setCallback("onClickPrimary", vehicle, function (vehicle)
        if not CpBaseHud.copyPasteCache.hasVehicle and vehicle.getCpCombineUnloaderJob then 
            CpBaseHud.copyPasteCache.combineUnloaderVehicle = vehicle
            CpBaseHud.copyPasteCache.hasVehicle = true
        end
    end)


    self.pasteButton:setCallback("onClickPrimary", vehicle, function (vehicle)
        if CpBaseHud.copyPasteCache.hasVehicle and not vehicle:getIsCpActive() then 
            if CpBaseHud.copyPasteCache.combineUnloaderVehicle then 
                vehicle:applyCpCombineUnloaderJobParameters(CpBaseHud.copyPasteCache.combineUnloaderVehicle:getCpCombineUnloaderJob())
            else 
                local parameters = CpBaseHud.copyPasteCache.siloLoaderVehicle:getCpSiloLoaderWorkerJobParameters()
                vehicle:getCpCombineUnloaderJobParameters().fieldUnloadPosition:copy(parameters.loadPosition)
            end
        end
    end)

    self.clearCacheBtn:setCallback("onClickPrimary", vehicle, function (vehicle)
        CpBaseHud.copyPasteCache.hasVehicle = false
        CpBaseHud.copyPasteCache.siloLoaderVehicle = nil 
        CpBaseHud.copyPasteCache.combineUnloaderVehicle = nil
    end)
end

function CpCombineUnloaderHudPageElement:update(dt)
	CpCombineUnloaderHudPageElement:superClass().update(self, dt)
end

function CpCombineUnloaderHudPageElement:updateContent(vehicle, status)

    local combineOffsetX = vehicle:getCpSettings().combineOffsetX
    self.combineOffsetXBtn:setTextDetails(combineOffsetX:getTitle(), combineOffsetX:getString())
    self.combineOffsetXBtn:setDisabled(combineOffsetX:getIsDisabled())

    local combineOffsetZ = vehicle:getCpSettings().combineOffsetZ
    self.combineOffsetZBtn:setTextDetails(combineOffsetZ:getTitle(), combineOffsetZ:getString())
    self.combineOffsetZBtn:setDisabled(combineOffsetZ:getIsDisabled())

    local fullThreshold = vehicle:getCpSettings().fullThreshold
    self.fullThresholdBtn:setTextDetails(fullThreshold:getTitle(), fullThreshold:getString())
    self.fullThresholdBtn:setDisabled(fullThreshold:getIsDisabled())

    -- local useGiantsUnload = vehicle:getCpCombineUnloaderJobParameters().useGiantsUnload
    -- self.giantsUnloadStationText:setVisible(useGiantsUnload:getValue() and not useGiantsUnload:getIsDisabled())
    -- self.giantsUnloadStationText:setDisabled(not useGiantsUnload:getValue() or vehicle:getIsCpActive())
    -- local giantsUnloadStation = vehicle:getCpCombineUnloaderJobParameters().unloadingStation
    -- self.giantsUnloadStationText:setTextDetails(giantsUnloadStation:getString())

    -- self.activateGiantsUnloadBtn:setColor(useGiantsUnload:getValue() and unpack(CpBaseHud.ON_COLOR) or unpack(CpBaseHud.OFF_COLOR))
    -- self.activateGiantsUnloadBtn:setVisible(not useGiantsUnload:getIsDisabled())
    -- self.activateGiantsUnloadBtn:setDisabled(useGiantsUnload:getIsDisabled() or vehicle:getIsCpActive())

    local fillLevelPercentage = FillLevelManager.getTotalTrailerFillLevelPercentage(vehicle)
    if fillLevelPercentage > 0.01 then 
        self.driveNowBtn:setColor(unpack(CpBaseHud.SEMI_ON_COLOR))    
    else
        self.driveNowBtn:setColor(unpack(CpBaseHud.OFF_COLOR))
    end
    self.driveNowBtn:setDisabled(not vehicle:getIsCpActive())
    self.driveNowBtn:setVisible(vehicle:getIsCpActive())   

    --- Update copy and paste buttons
    self:updateCopyButtons(vehicle)

end

--- Updates the copy, paste and clear buttons.
function CpCombineUnloaderHudPageElement:updateCopyButtons(vehicle)
    if CpBaseHud.copyPasteCache.hasVehicle then 
        self.clearCacheBtn:setVisible(true)
        self.pasteButton:setVisible(true)
        self.copyButton:setVisible(false)
        local copyCacheVehicle = CpBaseHud.copyPasteCache.siloLoaderVehicle or CpBaseHud.copyPasteCache.combineUnloaderVehicle
        local fieldNum = CpFieldUtil.getFieldNumUnderVehicle(copyCacheVehicle)
        local text = CpUtil.getName(copyCacheVehicle)
        if fieldNum then 
            text = string.format("%s(%s)", text, fieldNum)
        end
        self.copyCacheText:setTextDetails(text)
        self.copyCacheText:setTextColorChannels(unpack(CpBaseHud.OFF_COLOR))
        self.pasteButton:setColor(unpack(CpBaseHud.OFF_COLOR))
        self.pasteButton:setDisabled(true)
        if copyCacheVehicle == vehicle or vehicle:getIsCpActive() then 
            --- Paste disabled
            return
        end

        local arePositionEqual
        if CpBaseHud.copyPasteCache.combineUnloaderVehicle then 
            arePositionEqual = self:arePositionEqual(vehicle:getCpCombineUnloaderJobParameters(), 
                copyCacheVehicle:getCpCombineUnloaderJobParameters())
        else
            local loadPosition = copyCacheVehicle:getCpSiloLoaderWorkerJobParameters().loadPosition
            local unloadPosition = vehicle:getCpCombineUnloaderJobParameters().fieldUnloadPosition
            arePositionEqual = unloadPosition:isAlmostEqualTo(loadPosition)
        end
        if arePositionEqual then 
            --- Paste disabled
            return
        end
        self.copyCacheText:setTextColorChannels(unpack(CpBaseHud.WHITE_COLOR))
        self.pasteButton:setColor(unpack(CpBaseHud.ON_COLOR))
        self.pasteButton:setDisabled(false)

    else
        self.copyCacheText:setTextDetails("")
        self.clearCacheBtn:setVisible(false)
        self.pasteButton:setVisible(false)
        self.copyButton:setVisible(true)
    end
end

function CpCombineUnloaderHudPageElement:arePositionEqual(parameters, otherParameters)
    if not parameters.fieldUnloadPosition:isAlmostEqualTo(otherParameters.fieldUnloadPosition) then 
        return false
    end 
    if not parameters.startPosition:isAlmostEqualTo(otherParameters.startPosition) then 
        return false
    end
    if not parameters.fieldPosition:isAlmostEqualTo(otherParameters.fieldPosition) then 
        return false
    end
    return true 
end

function CpCombineUnloaderHudPageElement:isStartingPointBtnVisible()
    return false
end
