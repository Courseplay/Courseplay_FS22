CpBinaryOptionElement = {}
local CpBinaryOptionElement_mt = Class(CpBinaryOptionElement, BinaryOptionElement)

function CpBinaryOptionElement.new(target, custom_mt)
	local self = BinaryOptionElement.new(target, custom_mt or CpBinaryOptionElement_mt)
	self.dataSource = nil
	self.toolTipElement = nil
	return self
end

function CpBinaryOptionElement:delete()
	self.dataSource = nil

	CpBinaryOptionElement:superClass().delete(self)
end

function CpBinaryOptionElement:setDataSource(dataSource)
	self.dataSource = dataSource
	self.useYesNoTexts = false
	self:setTexts({self.dataSource.texts[1], self.dataSource.texts[2]})
	if self.dataSource:getValue() then 
		self:setState(BinaryOptionElement.STATE_RIGHT, true)
	else 
		self:setState(BinaryOptionElement.STATE_LEFT, true)
	end	
end

function CpBinaryOptionElement:addElement(element, ...)
	CpBinaryOptionElement:superClass().addElement(self, element, ...)
	-- if self.textElement then
	-- 	self.textElement.forceHighlight = true
	-- 	self.textElement:setHandleFocus(false)
	-- 	self.textElement.target = self
	-- 	self.textElement:setCallback("onClickCallback", "onCenterButtonClicked")
	-- end
	if element.name == "tooltip" then
		self.toolTipElement = element
	end
end

function CpBinaryOptionElement:updateTitle()
	if self.labelElement then 
		self.labelElement:setText(self.dataSource:getTitle())
	end
	if self.toolTipElement then
		self.toolTipElement:setText(self.dataSource:getTooltip())
	end
end

function CpBinaryOptionElement:setState(state, ...)
	if state == BinaryOptionElement.STATE_RIGHT then 
		self.dataSource:setValue(true)
	else 
		self.dataSource:setValue(false)
	end
	self:updateTitle()
	if self.dataSource:getValue() then 
		CpBinaryOptionElement:superClass().setState(self, BinaryOptionElement.STATE_RIGHT, true)
	else
		CpBinaryOptionElement:superClass().setState(self, BinaryOptionElement.STATE_LEFT, true)
	end
end

Gui.registerGuiElement("CpBinaryyOption", CpBinaryOptionElement)
