--- Adds additional setting features to the OptionToggleElement Gui element.
--- Mainly a direct button/key press for text input or similar actions.
CpOptionToggleElement = {}
local CpOptionToggleElement_mt = Class(CpOptionToggleElement, OptionToggleElement)

function CpOptionToggleElement.new(target, custom_mt)
	local self = OptionToggleElement.new(target, custom_mt or CpOptionToggleElement_mt)

	return self
end

function CpOptionToggleElement:loadFromXML(xmlFile, key)
	CpOptionToggleElement:superClass().loadFromXML(self, xmlFile, key)
	self:addCallback(xmlFile, key .. "#onClickCenter", "onClickCenterCallback")
end

function CpOptionToggleElement:copyAttributes(src)
	CpOptionToggleElement:superClass().copyAttributes(self, src)
	self.onClickCenterCallback = src.onClickCenterCallback
end


function CpOptionToggleElement:onCenterButtonClicked()
	self:raiseCallback("onClickCenterCallback", self)
	if self.dataSource ~= nil then
		self.dataSource:onClickCenter(self)
	end
	self:setSoundSuppressed(true)
	FocusManager:setFocus(self)
	self:setSoundSuppressed(false)
end

function CpOptionToggleElement:addElement(...)
	CpOptionToggleElement:superClass().addElement(self, ...)
	if self.textElement then
		self.textElement.forceHighlight = true
		self.textElement:setHandleFocus(false)
		self.textElement.target = self
		self.textElement:setCallback("onClickCallback", "onCenterButtonClicked")
	end
end

function CpOptionToggleElement:updateTitle()
	CpOptionToggleElement:superClass().updateTitle(self)
	if self.labelElement and self.labelElement.setText then 
		self.labelElement:setText(self.dataSource:getTitle())
	end
end

function CpOptionToggleElement:setLabelElement(element)
	self.labelElement = element
	self:updateTitle()
end

function CpOptionToggleElement:inputEvent(action, value, eventUsed)
	eventUsed = CpOptionToggleElement:superClass().inputEvent(self, action, value, eventUsed)
	if not eventUsed then
		if action == InputAction.MENU_ACCEPT then
			if self.focusActive then
				self:onCenterButtonClicked()
				eventUsed = true
			end
		end
	end
	return eventUsed
end

function CpOptionToggleElement:onRightButtonClicked(steps, noFocus)
	CpOptionToggleElement:superClass().onRightButtonClicked(self, steps, noFocus)
	if noFocus == nil or not noFocus then
		if self.textElement ~= nil then
			self.textElement:onFocusEnter()
		end
	end
end

-- Lines 44-51
function CpOptionToggleElement:onLeftButtonClicked(steps, noFocus)
	CpOptionToggleElement:superClass().onLeftButtonClicked(self, steps, noFocus)
	if noFocus == nil or not noFocus then
		if self.textElement ~= nil then
			self.textElement:onFocusEnter()
		end
	end
end

function CpOptionToggleElement:onFocusEnter()
	CpOptionToggleElement:superClass().onFocusEnter(self)

	if self.textElement ~= nil and self.textElement.state ~= GuiOverlay.STATE_FOCUSED then
		self.textElement:onFocusEnter()
	end
end

function CpOptionToggleElement:onFocusLeave()
	CpOptionToggleElement:superClass().onFocusLeave(self)
	
	if self.textElement ~= nil and self.textElement.state ~= GuiOverlay.STATE_NORMAL then
		self.textElement:onFocusLeave()
	end
end


-- Lines 521-531
function CpOptionToggleElement:onHighlight()
	CpOptionToggleElement:superClass().onHighlight(self)

	if self.textElement ~= nil and self.textElement:getOverlayState() == GuiOverlay.STATE_NORMAL then
		self.textElement:setOverlayState(GuiOverlay.STATE_HIGHLIGHTED)
	end
end

-- Lines 535-545
function CpOptionToggleElement:onHighlightRemove()
	CpOptionToggleElement:superClass().onHighlightRemove(self)

	if self.textElement ~= nil and self.textElement:getOverlayState() == GuiOverlay.STATE_HIGHLIGHTED then
		self.textElement:setOverlayState(GuiOverlay.STATE_NORMAL)
	end
end


Gui.CONFIGURATION_CLASS_MAPPING.cpOptionToggle = CpOptionToggleElement 