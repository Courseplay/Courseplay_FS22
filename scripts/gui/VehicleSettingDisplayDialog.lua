VehicleSettingDisplayDialog = {
	CONTROLS = {
		BLANK_ELEMENT = "blankElement",
		BUTTON_BACK = "backButton"
	},
}
local VehicleSettingDisplayDialog_mt = Class(VehicleSettingDisplayDialog, ScreenElement)

function VehicleSettingDisplayDialog.new(settings,target, custom_mt)
	local self = ScreenElement.new(target, custom_mt or VehicleSettingDisplayDialog_mt)
	self:registerControls(VehicleSettingDisplayDialog.CONTROLS)


	local clone = g_currentMission.inGameMenu.pageAI.jobMenuLayout:clone(nil,true)
	clone:unlinkElement()
	FocusManager:removeElement(clone)
	self.layout = clone:clone(self,true)
	for i = #self.layout.elements, 1, -1 do
		self.layout.elements[i]:delete()
	end
	self.settingElement = g_currentMission.inGameMenu.pageAI.createMultiOptionTemplate --:clone(self.layout)
	self.titleElement = g_currentMission.inGameMenu.pageAI.createTitleTemplate
	local invalidElement = self.settingElement:getDescendantByName("invalid")

	if invalidElement ~= nil then
		invalidElement:setVisible(false)
	end
	CpSettingsUtil.generateGuiElementsFromSettingsTableAlternating(settings,self.layout,self.titleElement,self.settingElement)
	
	return self
end

function VehicleSettingDisplayDialog:onGuiSetupFinished()
	self.backButton:unlinkElement()
	FocusManager:removeElement(self.backButton)
	self.layout:addElement(self.backButton)
	self.layout:invalidateLayout()
	CpGuiUtil.setTarget(self.layout,self)
	VehicleSettingDisplayDialog:superClass().onGuiSetupFinished(self)
end

function VehicleSettingDisplayDialog:setData(vehicle,settings) 
	self.vehicle = vehicle
	self.settings = settings
	CpSettingsUtil.linkGuiElementsAndSettings(settings,self.layout)
end

function VehicleSettingDisplayDialog:onOpen(element)
	VehicleSettingDisplayDialog:superClass().onOpen(self)
	self.layout:invalidateLayout()
	self.layout:setVisible(true)
	FocusManager:loadElementFromCustomValues(self.layout)
	self.layout:invalidateLayout()
	FocusManager:setFocus(self.layout)
end

function VehicleSettingDisplayDialog:onClose(element)
	VehicleSettingDisplayDialog:superClass().onClose(self)
	self.layout:setVisible(false)
	if self.settings then
		CpSettingsUtil.unlinkGuiElementsAndSettings(self.settings,self.layout)
	end
end

function VehicleSettingDisplayDialog:onClickBack()
	g_gui:showGui("")
end

function VehicleSettingDisplayDialog:draw(...)
	VehicleSettingDisplayDialog:superClass().draw(self,...)
	CpVehicleSettingDisplay.onDraw(self.vehicle)	
end

function CpGuiUtil.setTarget(element,target)
	for i = 1, #element.elements do
		CpGuiUtil.setTarget(element.elements[i],target)
	end

	element.target = target
	element.targetName = target.name
end 