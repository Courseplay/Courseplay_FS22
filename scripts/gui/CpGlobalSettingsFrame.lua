--[[
	This frame is a page for all global settings in the in game menu.
	All the layout, gui elements are cloned from the general settings page of the in game menu.
]]--

CpGlobalSettingsFrame = {}

---Creates the in game menu page.
function CpGlobalSettingsFrame.init()
	local inGameMenu = g_gui.screenControllers[InGameMenu]
	local page = CpGuiUtil.getNewInGameMenuFrame(inGameMenu,inGameMenu.pageSettingsGeneral,CpGlobalSettingsFrame
												,function () return true end,3,{768, 0, 128, 128})
	inGameMenu.pageCpGlobalSettings = page
end

--- Setup of the gui elements and binds the settings to the gui elements.
function CpGlobalSettingsFrame:initialize()
	local genericSettingElement = CpGuiUtil.getGenericSettingElementFromLayout(self.boxLayout)
	local genericSubTitleElement = CpGuiUtil.getGenericSubTitleElementFromLayout(self.boxLayout)
	for i = #self.boxLayout.elements, 1, -1 do
		self.boxLayout.elements[i]:delete()
	end
--	self.boxLayout:reloadFocusHandling(true)
	self.settings = g_Courseplay.globalSettings:getSettingsTable()
	local settingsBySubTitle,pageTitle = g_Courseplay.globalSettings:getSettingSetup()
	CpSettingsUtil.generateGuiElementsFromSettingsTable(settingsBySubTitle,
	self.boxLayout,genericSettingElement, genericSubTitleElement)
	CpGuiUtil.changeTextForElementsWithProfileName(self,"ingameMenuFrameHeaderText",pageTitle)
	CpSettingsUtil.linkGuiElementsAndSettings(self.settings,self.boxLayout)
	self.boxLayout:invalidateLayout()

end

function CpGlobalSettingsFrame:onFrameOpen()
	InGameMenuGeneralSettingsFrame:superClass().onFrameOpen(self)
	self.boxLayout:invalidateLayout()
	self:setSoundSuppressed(true)
	FocusManager:setFocus(self.boxLayout)
	self:setSoundSuppressed(false)
	
end
	
function CpGlobalSettingsFrame:onFrameClose()
	InGameMenuGeneralSettingsFrame:superClass().onFrameClose(self)
end