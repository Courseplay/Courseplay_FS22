VehicleSettingDisplayDialog = {
	CONTROLS = {
		BLANK_ELEMENT = "blankElement"
	},
}
local VehicleSettingDisplayDialog_mt = Class(VehicleSettingDisplayDialog, ScreenElement)

function VehicleSettingDisplayDialog.new(settings,target, custom_mt)
	local self = ScreenElement.new(target, custom_mt or VehicleSettingDisplayDialog_mt)

	self.layout = g_currentMission.inGameMenu.pageAI.jobMenuLayout:clone(self,true)
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
	self.layout:invalidateLayout()

	return self
end

function VehicleSettingDisplayDialog:setData(vehicle,settings) 
	self.vehicle = vehicle
	self.settings = settings
	CpSettingsUtil.linkGuiElementsAndSettings(settings,self.layout)
end

function VehicleSettingDisplayDialog:onOpen(element)
	VehicleSettingDisplayDialog:superClass().onOpen(self)
	self.layout:setVisible(true)
end

function VehicleSettingDisplayDialog:onClose(element)
	VehicleSettingDisplayDialog:superClass().onClose(self)
	self.layout:setVisible(false)
	if self.settings then
		CpSettingsUtil.unlinkGuiElementsAndSettings(self.settings,self.layout)
	end
end

function VehicleSettingDisplayDialog:draw(...)
	VehicleSettingDisplayDialog:superClass().draw(self,...)
	CpVehicleSettingDisplay.onDraw(self.vehicle)	
end

function VehicleSettingDisplayDialog:keyEvent(unicode, sym, modifier, isDown, eventUsed)
	VehicleSettingDisplayDialog:superClass().keyEvent(self,unicode, sym, modifier, isDown, eventUsed)
	if not isDown then
		if sym == Input.KEY_esc then
			g_gui:showGui("")
		end
	end
end
