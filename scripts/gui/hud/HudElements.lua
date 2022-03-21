--- Base hud element.
---@class CpHudElement : HUDElement
CpHudElement = {}
local CpHudElement_mt = Class(CpHudElement, HUDElement)

function CpHudElement.new(overlay,parentHudElement,customMt)
    if customMt == nil then
        customMt = CpHudElement_mt
    end
    local self = HUDElement.new(overlay, parentHudElement, customMt)

    self.callbacks = {}
    self.visible = true
    self.disabled = false
    self.hovered = false
    return self
end

function CpHudElement:debug(str,...)
    CpUtil.debugFormat(CpDebug.DBG_HUD, 'Hud element: '..str, ...)
end

function CpHudElement:mouseEvent(posX, posY, isDown, isUp, button,wasUsed)
    if wasUsed == nil then 
        wasUsed = false
    end
        
    if self.visible and not self.disabled and self:isMouseOverArea(posX,posY) then 
        self:setHovered(true)
    else 
        self:setHovered(false)
    end

    for _, child in ipairs(self.children) do
        if child:mouseEvent(posX, posY, isDown, isUp, button,wasUsed) then 
            wasUsed = true
        end
    end
    return wasUsed
end

function CpHudElement:setHovered(hovered)
    if hovered ~= self.hovered then 
        self:debug("hover state changed to %s",tostring(hovered))
        self:raiseCallback("onHoveredChanged",{hovered})
    end
    self.hovered = hovered
end

function CpHudElement:getIsHovered()
    return self.hovered    
end

--- Is the mouse over the element ?
function CpHudElement:isMouseOverArea(posX,posY)
    local x = self.overlay.x
	local y = self.overlay.y
	local width = self.overlay.width
	local height = self.overlay.height
    local offsetX,offsetY = self.overlay.offsetX,self.overlay.offsetY
    return GuiUtils.checkOverlayOverlap(posX, posY, x + offsetX, y + offsetY, width, height)
end

function CpHudElement:setCallback(callbackStr,class,func)
    self.callbacks[callbackStr] = {
        class = class,
        func = func,
    }
end

function CpHudElement:raiseCallback(callbackStr,args)
    if self.callbacks[callbackStr] then 
        local func = self.callbacks[callbackStr].func
        local class = self.callbacks[callbackStr].class
        if args~= nil then
            func(class, self, unpack(args))
        else 
            func(class, self)
        end
    end
end

function CpHudElement:setVisible(visible)
    CpHudElement:superClass().setVisible(self,visible)
    self.visible = visible
end

function CpHudElement:setDisabled(disabled)
    self.disabled = disabled
end

function CpHudElement:getIsDisabled()
    return self.disabled
end

--- Generic Hud button element with overlay.
---@class CpHudButtonElement : CpHudElement
CpHudButtonElement = {}
local CpHudButtonElement_mt = Class(CpHudButtonElement, CpHudElement)
CpHudButtonElement.scrollDelayMs = 10
function CpHudButtonElement.new(overlay,parentHudElement,customMt)
    if customMt == nil then
        customMt = CpHudButtonElement_mt
    end
    local self = CpHudElement.new(overlay, parentHudElement, customMt)
    self.lastScrollTimeStamp = g_time
    return self
end

function CpHudButtonElement:mouseEvent(posX, posY, isDown, isUp, button,wasUsed)
    if self.visible and not self.disabled and self:isMouseOverArea(posX,posY) then 

        if button == Input.MOUSE_BUTTON_LEFT then
            if isDown then 
                self:onClickPrimary(posX,posY)
                wasUsed = true
            end
        end
        if self.lastScrollTimeStamp + self.scrollDelayMs < g_time then
            if Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_UP) then
                self.lastScrollTimeStamp =  g_time
                self:onClickMouseWheel(1,posX,posY)
            elseif Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_DOWN) then
                self.lastScrollTimeStamp =  g_time
                self:onClickMouseWheel(-1,posX,posY)
            end
        end
    end
    
   return CpHudButtonElement:superClass().mouseEvent(self,posX, posY, isDown, isUp, button,wasUsed)
end

function CpHudButtonElement:onClickPrimary(posX,posY)
    self:debug("onClickPrimary")
    self:raiseCallback("onClickPrimary")
end

function CpHudButtonElement:onClickMouseWheel(dir,posX,posY)
    self:debug("onClickMouseWheel")
    self:raiseCallback("onClickMouseWheel",{dir})
end


--- Generic Hud text element.
---@class CpTextHudElement : CpHudButtonElement
CpTextHudElement = {}
local CpTextHudElement_mt = Class(CpTextHudElement, CpHudButtonElement)
CpTextHudElement.SHADOW_OFFSET_FACTOR = 0.05
CpTextHudElement.highlightedColor = {42 / 255, 193 / 255, 237 / 255, 1}
CpTextHudElement.disabledColor = {64 / 255, 64 / 255, 64 / 255, 0.5}
function CpTextHudElement.new(parentHudElement,posX, posY, textSize, textAlignment, textColor, textBold,customMt)
    if customMt == nil then
        customMt = CpTextHudElement_mt
    end
    --- Not used, but needed for inheritance form HUDElement, similar to HUDDisplayElement
    local backgroundOverlay = Overlay.new(nil, 0, 0, 0, 0)

	backgroundOverlay:setColor(1, 1, 1, 1)
    local self = CpHudButtonElement.new(backgroundOverlay, parentHudElement, customMt)
 
    self.text = ""
	self.textSize = textSize or 0
	self.screenTextSize = self:scalePixelToScreenHeight(self.textSize)
	self.textAlignment = textAlignment or RenderText.ALIGN_LEFT
	self.textColor = textColor or {
		1,
		1,
		1,
		1
	}
	self.textBold = textBold or false
	self.hasShadow = false
	self.shadowColor = {
		0,
		0,
		0,
		1
	}
    if textAlignment == RenderText.ALIGN_RIGHT then 
        self:setAlignment(Overlay.ALIGN_VERTICAL_BOTTOM,Overlay.ALIGN_HORIZONTAL_RIGHT)
    end
    self:setTextDetails("")
    self:setPosition(posX, posY)
    return self
end

function CpTextHudElement:setTextDetails(text, textSize, textAlignment, textColor, textBold)
	self.text = text or self.text
	self.textSize = textSize or self.textSize
	self.screenTextSize = self:scalePixelToScreenHeight(self.textSize)
	self.textAlignment = textAlignment or self.textAlignment
	self.textColor = textColor or self.textColor
	self.textBold = textBold or self.textBold
	local width = getTextWidth(self.screenTextSize, self.text)
	local height = getTextHeight(self.screenTextSize, self.text)

	self:setDimension(width, height)
end

function CpTextHudElement:setHoveredText(text)
    self.hoveredText = text
end

function CpTextHudElement:setScale(uiScale,uiScale)
	CpTextHudElement:superClass().setScale(self, uiScale,uiScale)

	self.screenTextSize = self:scalePixelToScreenHeight(self.textSize)
end

function CpTextHudElement:setVisible(isVisible, animate)
	CpTextHudElement:superClass().setVisible(self, isVisible)

	if animate then
		if not isVisible or not self.animation:getFinished() then
			self.animation:reset()
		end

		if isVisible then
			self.animation:start()
		end
	end
end

function CpTextHudElement:setTextColorChannels(r, g, b, a)
	self.textColor[1] = r
	self.textColor[2] = g
	self.textColor[3] = b
	self.textColor[4] = a
end

function CpTextHudElement:setTextShadow(isShadowEnabled, shadowColor)
	self.hasShadow = isShadowEnabled or self.hasShadow
	self.shadowColor = shadowColor or self.shadowColor
end

function CpTextHudElement:setAnimation(animationTween)
	self:storeOriginalPosition()

	self.animation = animationTween or TweenSequence.NO_SEQUENCE
end

function CpTextHudElement:update(dt)
	if self:getVisible() then
		CpTextHudElement:superClass().update(self, dt)
	end
end

function CpTextHudElement:draw()
    if not self.visible then 
        return
    end

	setTextBold(self.textBold)

	local posX, posY = self:getPosition()

	setTextAlignment(self.textAlignment)
	setTextWrapWidth(0.9)

	if self.hasShadow then
		local offset = self.screenTextSize * CpTextHudElement.SHADOW_OFFSET_FACTOR
		local r, g, b, a = unpack(self.shadowColor)

		setTextColor(r, g, b, a * self.overlay.a)
		renderText(posX + offset, posY - offset, self.screenTextSize, self.text)
	end
    local r, g, b, a
    if self.hovered then 
        r, g, b, a = unpack(CpTextHudElement.highlightedColor)
    elseif self.isDisabled then
        r, g, b, a = unpack(self.disabledColor)
    else 
        r, g, b, a = unpack(self.textColor)
    end
	setTextColor(r, g, b, a * self.overlay.a)
    local text = self.hovered and self.hoveredText or self.text
	renderText(posX, posY, self.screenTextSize, text)
	setTextAlignment(RenderText.ALIGN_LEFT)
	setTextWrapWidth(0)
	setTextBold(false)
	setTextColor(1, 1, 1, 1)
end

function CpTextHudElement:getScreenHeight()
    return self.screenTextSize   
end

--- Moveable Hud element.
---@class CpHudMoveableElement : CpHudElement
CpHudMoveableElement = {
    dragDelayMs = 15
}
local CpHudMoveableElement_mt = Class(CpHudMoveableElement, CpHudElement)

function CpHudMoveableElement.new(overlay,parentHudElement,customMt)
    if customMt == nil then
        customMt = CpHudMoveableElement_mt
    end
    local self = CpHudElement.new(overlay, parentHudElement, customMt)

    self.dragging = false
    self.dragStartX = nil
    self.dragOffsetX = nil
    self.dragStartY = nil
    self.dragOffsetY = nil
    self.lastDragTimeStamp = nil
    self.dragLimit = 2
    return self
end

function CpHudMoveableElement:setPosition(x,y)
    self.x, self.y = x, y 
    CpHudMoveableElement:superClass().setPosition(self,x,y)
end

function CpHudMoveableElement:mouseEvent(posX, posY, isDown, isUp, button,wasUsed)
    if not self.dragging then 
        local wasUsed = CpHudMoveableElement:superClass().mouseEvent(self,posX, posY, isDown, isUp, button,wasUsed)
        if wasUsed then 
            return
        end
        if not self:isMouseOverArea(posX, posY) then 
            return 
        end
    end
    if not self.visible or self.disabled then 
        return
    end
    if button == Input.MOUSE_BUTTON_LEFT then
        --- Handles the start dragging and the end of the dragging.
        if isDown and self:isMouseOverArea(posX, posY) then
            if not self.dragging then
                self.dragStartX = posX
                self.dragOffsetX = posX - self.x
                self.dragStartY = posY
                self.dragOffsetY = posY - self.y
                self.dragging = true
                self.lastDragTimeStamp =  g_time
            end
        elseif isUp then
            if self.dragging and (math.abs(posX - self.dragStartX) > self.dragLimit / g_screenWidth or
                    math.abs(posY - self.dragStartY) > self.dragLimit / g_screenHeight) then
                self:moveTo(posX - self.dragOffsetX, posY - self.dragOffsetY)
            else 

            end
            self.dragging = false
        end
    end
    --- Handles the dragging
    if self.dragging and g_time > (self.lastDragTimeStamp + CpHudMoveableElement.dragDelayMs) then 
        if  math.abs(posX - self.dragStartX) > self.dragLimit / g_screenWidth or
        math.abs(posY - self.dragStartY) > self.dragLimit / g_screenHeight then
            self:moveTo(posX - self.dragOffsetX, posY - self.dragOffsetY)
            self.dragStartX = posX
            self.dragOffsetX = posX - self.x
            self.dragStartY = posY
            self.dragOffsetY = posY - self.y
            self.lastDragTimeStamp = g_time
        end
    end
end

function CpHudMoveableElement:moveTo(x, y)
    self:setPosition(x, y)
    self:raiseCallback("onMove", {x, y})
end


--- Hud element for setting list settings.
---@class CpHudSettingElement : CpTextHudElement
CpHudSettingElement = {}
local CpHudSettingElement_mt = Class(CpHudSettingElement, CpHudButtonElement)
function CpHudSettingElement.new(parentHudElement, posX, posY, maxPosX, maxPosY, incrementalOverlay, decrementalOverlay, 
                                    textSize, textAlignment, textColor, textBold, customMt)
    if customMt == nil then
        customMt = CpHudSettingElement_mt
    end
    --- Not used, but needed for inheritance form HUDElement, similar to HUDDisplayElement
    local backgroundOverlay = Overlay.new(nil, 0, 0, 0, 0)

	backgroundOverlay:setColor(1, 1, 1, 1)
    local self = CpHudButtonElement.new(backgroundOverlay, parentHudElement, customMt)
    self:setPosition(posX, posY)
    self.labelElement = CpTextHudElement.new(parentHudElement, posX, posY, textSize)
    self.labelElement:setTextDetails("Label")

    self.incrementalElement = CpHudButtonElement.new(incrementalOverlay, parentHudElement)
    self.incrementalElement:setPosition(maxPosX,maxPosY)
    local w = self.incrementalElement:getWidth()
    local x = maxPosX - w*1.5
    self.textElement = CpTextHudElement.new(parentHudElement, x, posY, textSize-2,RenderText.ALIGN_RIGHT)
    self.textElement:setTextDetails("100.00")
    w = self.textElement:getWidth()
    self.decrementalElement = CpHudButtonElement.new(decrementalOverlay, parentHudElement)
    self.decrementalElement:setPosition(x-w*1.5, posY)

    return self
end

function CpHudSettingElement:setTextDetails(labelText, text, labelTextDetails, textDetails)
    labelTextDetails = labelTextDetails or {}
    textDetails = textDetails or {}
    self.textElement:setTextDetails(text, textDetails.textSize, textDetails.textAlignment,
                                     textDetails.textColor, textDetails.textBold)
    self.labelElement:setTextDetails(labelText, labelTextDetails.textSize, labelTextDetails.textAlignment,
                                     labelTextDetails.textColor, labelTextDetails.textBold)
    
end

function CpHudSettingElement:setCallback(callbackLabel,callbackText,callbackIncremental,callbackDecremental)
    if callbackLabel then
        self.labelElement:setCallback(callbackLabel.callbackStr, 
                                    callbackLabel.class,
                                    callbackLabel.func
                                 --   unpack(callbackLabel.args)
                                )
    end
    if callbackText then
        self.textElement:setCallback(callbackText.callbackStr, 
                                    callbackText.class,
                                    callbackText.func
                                --    unpack(callbackText.args)
                            )
    end                 
    if callbackIncremental then                        
        self.incrementalElement:setCallback(callbackIncremental.callbackStr, 
                                        callbackIncremental.class,
                                        callbackIncremental.func
                                   --     unpack(callbackIncremental.args)
                                    )
    end                 
    if callbackDecremental then  
        self.decrementalElement:setCallback(callbackDecremental.callbackStr, 
                                        callbackDecremental.class,
                                        callbackDecremental.func
                                    --    unpack(callbackDecremental.args)
                                    )
    end
end

function CpHudSettingElement:setDisabled(disabled)
    if disabled then 
        self.incrementalElement:setVisible(false)
        self.decrementalElement:setVisible(false)
        self.textElement:setDisabled(true)
        self.labelElement:setDisabled(true)
    else 
        self.incrementalElement:setVisible(true)
        self.decrementalElement:setVisible(true)
        self.textElement:setDisabled(false)
        self.labelElement:setDisabled(false)
    end
    CpHudSettingElement:superClass().setDisabled(self, disabled)
end