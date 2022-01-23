
--- Generic Hud element with overlay.

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
    return self
end

function CpHudElement:debug(str,...)
    CpUtil.debugFormat(CpDebug.DBG_HUD, 'Hud element: '..str, ...)
end

function CpHudElement:mouseEvent(posX, posY, isDown, isUp, button,wasUsed)
    if wasUsed == nil then 
        wasUsed = false
    end
    
    if self:isMouseOverArea(posX,posY) then 
        self.hovered = true
    else 
        self.hovered = false
    end

    for _, child in ipairs(self.children) do
        if child:mouseEvent(posX, posY, isDown, isUp, button,wasUsed) then 
            wasUsed = true
        end
    end
    return wasUsed
end

--- WIP: Not working for the on/off overlay
function CpHudElement:isMouseOverArea(posX,posY)
    local x = self.overlay.x
	local y = self.overlay.y
	local width = self.overlay.width
	local height = self.overlay.height
    local offsetX,offsetY = self.overlay.offsetX,self.overlay.offsetY
    return GuiUtils.checkOverlayOverlap(posX, posY, x + offsetX, y + offsetY, width, height)
end

function CpHudElement:setCallback(callbackStr,class,func,...)
    self.callbacks[callbackStr] = {
        class = class,
        func = func,
        args = ...
    }
end

function CpHudElement:raiseCallback(callbackStr)
    if self.callbacks[callbackStr] then 
        local func = self.callbacks[callbackStr].func
        local class = self.callbacks[callbackStr].class
        local args = self.callbacks[callbackStr].args
        if args~= nil then
            func(class,unpack(args))
        else 
            func(class)
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

--- Generic Hud button element with overlay.
---@class CpHudButtonElement : CpHudElement
CpHudButtonElement = {}
local CpHudButtonElement_mt = Class(CpHudButtonElement, CpHudElement)

function CpHudButtonElement.new(overlay,parentHudElement,customMt)
    if customMt == nil then
        customMt = CpHudButtonElement_mt
    end
    local self = CpHudElement.new(overlay, parentHudElement, customMt)
    return self
end

--- WIP: not working
function CpHudButtonElement:mouseEvent(posX, posY, isDown, isUp, button,wasUsed)
    if self:isMouseOverArea(posX,posY) then 
        if button == Input.MOUSE_BUTTON_LEFT then
            if isDown then 
                self:onClickPrimary(posX,posY)
                wasUsed = true
            end
        end
    end
    
   return CpHudButtonElement:superClass().mouseEvent(self,posX, posY, isDown, isUp, button,wasUsed)
end

function CpHudButtonElement:onClickPrimary(posX,posY)
    self:debug("onClickPrimary")
    self:raiseCallback("onClickPrimary")
end

--- Generic Hud text element.
---@class CpTextHudElement : CpHudButtonElement
CpTextHudElement = {}
local CpTextHudElement_mt = Class(CpTextHudElement, CpHudButtonElement)
CpTextHudElement.SHADOW_OFFSET_FACTOR = 0.05
CpTextHudElement.highlightedColor = {42 / 255, 193 / 255, 237 / 255, 1}
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

function CpTextHudElement:setScale(uiScale)
	CpTextHudElement:superClass().setScale(self, uiScale)

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
    else 
        r, g, b, a = unpack(self.textColor)
    end
	setTextColor(r, g, b, a * self.overlay.a)
	renderText(posX, posY, self.screenTextSize, self.text)
	setTextAlignment(RenderText.ALIGN_LEFT)
	setTextWrapWidth(0)
	setTextBold(false)
	setTextColor(1, 1, 1, 1)
end
