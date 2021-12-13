--[[
	This frame is a page for all vehicle settings in the in game menu.
	This page is visible once a vehicle is selected in the ai menu.
	The selected vehicle settings are then automatically bound to the gui on opening of the page.
	All the layout, gui elements are cloned from the general settings page of the in game menu.
]]--

CpVehicleSettingsFrame = {}

function CpVehicleSettingsFrame.init()
	local inGameMenu = g_gui.screenControllers[InGameMenu]
	local function predicateFunc()
		local inGameMenu = g_gui.screenControllers[InGameMenu]
		local aiPage = inGameMenu.pageAI

		local allowed = inGameMenu.currentPage == inGameMenu.pageCpVehicleSettings or 
						aiPage.currentHotspot ~= nil
		return allowed
	end

	local page = CpGuiUtil.getNewInGameMenuFrame(inGameMenu,CpVehicleSettingsFrame
									,predicateFunc,3)
	inGameMenu.pageCpVehicleSettings = page
end

function CpVehicleSettingsFrame:initialize()
	local genericSettingElement = CpGuiUtil.getGenericSettingElementFromLayout(self.boxLayout)
	local genericSubTitleElement = CpGuiUtil.getGenericSubTitleElementFromLayout(self.boxLayout)
	for i = #self.boxLayout.elements, 1, -1 do
		self.boxLayout.elements[i]:delete()
	end
	local settingsBySubTitle,pageTitle = CpVehicleSettings.getSettingSetup()
	self.pageTitle = pageTitle
	CpSettingsUtil.generateGuiElementsFromSettingsTable(settingsBySubTitle,
	self.boxLayout,genericSettingElement, genericSubTitleElement)

	self.boxLayout:invalidateLayout()
end

--- Binds the settings of the selected vehicle to the gui elements.
function CpVehicleSettingsFrame:onFrameOpen()
	InGameMenuGeneralSettingsFrame:superClass().onFrameOpen(self)
	local currentHotspot = g_currentMission.inGameMenu.pageAI.currentHotspot
	local vehicle = InGameMenuMapUtil.getHotspotVehicle(currentHotspot)
	
	--- Changes the page title.
	local title = string.format(self.pageTitle,vehicle:getName())
	CpGuiUtil.changeTextForElementsWithProfileName(self,"ingameMenuFrameHeaderText",title)
	
	if vehicle ~=nil then 
		if vehicle.getCpSettings then 
			CpUtil.debugVehicle( CpUtil.DBG_HUD,vehicle, "onFrameOpen CpVehicleSettingsFrame" )
			self.settings = vehicle:getCpSettings()
			CpSettingsUtil.linkGuiElementsAndSettings(self.settings,self.boxLayout)
		end
	end
	self.boxLayout:invalidateLayout()
	self:setSoundSuppressed(true)
	FocusManager:setFocus(self.boxLayout)
	self:setSoundSuppressed(false)
end

--- Unbinds the settings of the selected vehicle to the gui elements.
function CpVehicleSettingsFrame:onFrameClose()
	InGameMenuGeneralSettingsFrame:superClass().onFrameClose(self)
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