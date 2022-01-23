--[[
	This frame is a page for all global settings in the in game menu.
	All the layout, gui elements are cloned from the general settings page of the in game menu.
]]--

CpGlobalSettingsFrame = {
	CONTROLS = {
		HEADER = "header",
		SUB_TITLE_PREFAB = "subTitlePrefab",
		MULTI_TEXT_OPTION_PREFAB = "multiTextOptionPrefab",
		SETTINGS_CONTAINER = "settingsContainer",
		BOX_LAYOUT = "boxLayout"
	},
}

local CpGlobalSettingsFrame_mt = Class(CpGlobalSettingsFrame, TabbedMenuFrameElement)

function CpGlobalSettingsFrame.new(target, custom_mt)
	local self = TabbedMenuFrameElement.new(target, custom_mt or CpGlobalSettingsFrame_mt)
	self:registerControls(CpGlobalSettingsFrame.CONTROLS)

    
	return self
end

function CpGlobalSettingsFrame:onGuiSetupFinished()
	CpGlobalSettingsFrame:superClass().onGuiSetupFinished(self)
	
	self.subTitlePrefab:unlinkElement()
	FocusManager:removeElement(self.subTitlePrefab)
	self.multiTextOptionPrefab:unlinkElement()
	FocusManager:removeElement(self.multiTextOptionPrefab)

	self.settings = g_Courseplay.globalSettings:getSettingsTable()
	local settingsBySubTitle,pageTitle = g_Courseplay.globalSettings:getSettingSetup()
	self.header:setText(pageTitle)	
	CpSettingsUtil.generateGuiElementsFromSettingsTable(settingsBySubTitle,
	self.boxLayout,self.multiTextOptionPrefab, self.subTitlePrefab)
	CpSettingsUtil.linkGuiElementsAndSettings(self.settings,self.boxLayout)
	self.boxLayout:invalidateLayout()
end

function CpGlobalSettingsFrame:onFrameOpen()
	CpGlobalSettingsFrame:superClass().onFrameOpen(self)
	FocusManager:loadElementFromCustomValues(self.boxLayout)
	self.boxLayout:invalidateLayout()
	self:setSoundSuppressed(true)
	FocusManager:setFocus(self.boxLayout)
	self:setSoundSuppressed(false)
end

function CpGlobalSettingsFrame:onFrameClose()
	CpGlobalSettingsFrame:superClass().onFrameClose(self)

end
