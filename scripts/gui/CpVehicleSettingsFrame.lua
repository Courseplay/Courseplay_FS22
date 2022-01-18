--[[
	This frame is a page for all vehicle settings in the in game menu.
	This page is visible once a vehicle is selected in the ai menu.
	The selected vehicle settings are then automatically bound to the gui on opening of the page.
	All the layout, gui elements are cloned from the general settings page of the in game menu.
]]--

--VehicleSettingFrame

CpVehicleSettingsFrame = {
	CONTROLS = {
		HEADER = "header",
		SUB_TITLE_PREFAB = "subTitlePrefab",
		MULTI_TEXT_OPTION_PREFAB = "multiTextOptionPrefab",
		SETTINGS_CONTAINER = "settingsContainer",
		BOX_LAYOUT = "boxLayout"
	},
}

local CpVehicleSettingsFrame_mt = Class(CpVehicleSettingsFrame, TabbedMenuFrameElement)

function CpVehicleSettingsFrame.new(target, custom_mt)
	local self = TabbedMenuFrameElement.new(target, custom_mt or CpVehicleSettingsFrame_mt)
	self:registerControls(CpVehicleSettingsFrame.CONTROLS)
	return self
end

function CpVehicleSettingsFrame:onGuiSetupFinished()
	CpVehicleSettingsFrame:superClass().onGuiSetupFinished(self)
	
	self.subTitlePrefab:unlinkElement()
	FocusManager:removeElement(self.subTitlePrefab)
	self.multiTextOptionPrefab:unlinkElement()
	FocusManager:removeElement(self.multiTextOptionPrefab)

	for i = #self.boxLayout.elements, 1, -1 do
		self.boxLayout.elements[i]:delete()
	end
	local settingsBySubTitle,pageTitle = CpVehicleSettings.getSettingSetup()
	self.pageTitle = pageTitle
	CpSettingsUtil.generateGuiElementsFromSettingsTable(settingsBySubTitle,
	self.boxLayout,self.multiTextOptionPrefab, self.subTitlePrefab)
	self.boxLayout:invalidateLayout()
end

--- Binds the settings of the selected vehicle to the gui elements.
function CpVehicleSettingsFrame:onFrameOpen()
	CpVehicleSettingsFrame:superClass().onFrameOpen(self)
	local pageAI = g_currentMission.inGameMenu.pageAI
	local currentHotspot = pageAI.currentHotspot
	self.currentVehicle =  pageAI.controlledVehicle or InGameMenuMapUtil.getHotspotVehicle(currentHotspot)
	self.header:setText()
	--- Changes the page title.
	local title = string.format(self.pageTitle,self.currentVehicle:getName())
	self.header:setText(title)	
	if self.currentVehicle ~=nil then 
		if self.currentVehicle.getCpSettings then 
			CpUtil.debugVehicle( CpUtil.DBG_HUD,self.currentVehicle, "onFrameOpen CpVehicleSettingsFrame" )
			self.settings = self.currentVehicle:getCpSettingsTable()
			local settingsBySubTitle = CpVehicleSettings.getSettingSetup()
			CpSettingsUtil.linkGuiElementsAndSettings(self.settings,self.boxLayout,settingsBySubTitle,self.currentVehicle)
		end
	end
	FocusManager:loadElementFromCustomValues(self.boxLayout)
	self.boxLayout:invalidateLayout()
	self:setSoundSuppressed(true)
	FocusManager:setFocus(self.boxLayout)
	self:setSoundSuppressed(false)
end

--- Unbinds the settings of the selected vehicle to the gui elements.
function CpVehicleSettingsFrame:onFrameClose()
	CpVehicleSettingsFrame:superClass().onFrameClose(self)
	if self.settings then
		local currentHotspot = g_currentMission.inGameMenu.pageAI.currentHotspot
		local vehicle = InGameMenuMapUtil.getHotspotVehicle(currentHotspot)
		CpUtil.debugVehicle( CpUtil.DBG_HUD,vehicle, "onFrameClose CpVehicleSettingsFrame" )
		CpSettingsUtil.unlinkGuiElementsAndSettings(self.settings,self.boxLayout)
	end
	self.settings = nil
	self.boxLayout:invalidateLayout()
	g_currentMission.inGameMenu:updatePages()
end