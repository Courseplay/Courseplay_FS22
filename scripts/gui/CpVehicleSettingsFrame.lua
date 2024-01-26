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
end

--- Binds the settings of the selected vehicle to the gui elements.
function CpVehicleSettingsFrame:onFrameOpen()
	CpVehicleSettingsFrame:superClass().onFrameOpen(self)
	self.currentVehicle = CpInGameMenuAIFrameExtended.getVehicle()
	--- Changes the page title.
	if self.currentVehicle ~=nil then 
		if self.currentVehicle.getCpSettings then 
			CpUtil.debugVehicle( CpUtil.DBG_HUD,self.currentVehicle, "onFrameOpen CpVehicleSettingsFrame" )
			local settings = self.currentVehicle:getCpSettings()
			local settingsBySubTitle, pageTitle = CpVehicleSettings.getSettingSetup()
			pageTitle = g_i18n:getText(pageTitle)
			for i = #self.boxLayout.elements, 1, -1 do
				self.boxLayout.elements[i]:delete()
			end
			CpSettingsUtil.generateAndBindGuiElementsToSettings(settingsBySubTitle,
				self.boxLayout, self.multiTextOptionPrefab, 
				self.subTitlePrefab, settings)
			CpSettingsUtil.updateGuiElementsBoundToSettings(self.boxLayout, self.currentVehicle)
			local title = string.format(pageTitle, self.currentVehicle:getName())
			self.header:setText(title)	
		end
	end
	self:setSoundSuppressed(true)
	FocusManager:setFocus(self.boxLayout)
	self:setSoundSuppressed(false)
end

function CpVehicleSettingsFrame:onClickCpMultiTextOption(_, guiElement)
	if self.currentVehicle then
		CpSettingsUtil.updateGuiElementsBoundToSettings(self.boxLayout, self.currentVehicle)
	end
end