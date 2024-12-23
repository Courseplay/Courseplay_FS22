--[[
	This frame is a page for all global settings in the in game menu.
	All the layout, gui elements are cloned from the general settings page of the in game menu.
]]--

CpGlobalSettingsFrame = {
	CATEGRORIES = {
		BASIC_SETTINGS = 1,
		USER_SETTINGS = 2
	},
	CATEGRORY_TEXTS = {
		"CP_global_setting_subTitle_general",
		"CP_global_setting_subTitle_userSettings"
	}
}
CpGlobalSettingsFrame.NUM_CATEGORIES = #CpGlobalSettingsFrame.CATEGRORY_TEXTS

local CpGlobalSettingsFrame_mt = Class(CpGlobalSettingsFrame, TabbedMenuFrameElement)

function CpGlobalSettingsFrame.new(target, custom_mt)
	local self = TabbedMenuFrameElement.new(target, custom_mt or CpGlobalSettingsFrame_mt)
	self.subCategoryPages = {}
	self.subCategoryTabs = {}
	self.wasOpened = false
	return self
end

function CpGlobalSettingsFrame.setupGui()
	local globalSettingsFrame = CpGlobalSettingsFrame.new()
	g_gui:loadGui(Utils.getFilename("config/gui/pages/GlobalSettingsFrame.xml", Courseplay.BASE_DIRECTORY),
	 			 "CpGlobalSettingsFrame", globalSettingsFrame, true)
end

function CpGlobalSettingsFrame.createFromExistingGui(gui, guiName)
	local newGui = CpGlobalSettingsFrame.new(nil, nil)

	g_gui.frames[gui.name].target:delete()
	g_gui.frames[gui.name]:delete()
	g_gui:loadGui(gui.xmlFilename, guiName, newGui, true)

	return newGui
end

function CpGlobalSettingsFrame.registerXmlSchema(xmlSchema, xmlKey)
	
end

function CpGlobalSettingsFrame:loadFromXMLFile(xmlFile, baseKey)
   
end

function CpGlobalSettingsFrame:saveToXMLFile(xmlFile, baseKey)
   
end

function CpGlobalSettingsFrame:initialize(menu)
	self.booleanPrefab:unlinkElement()
	FocusManager:removeElement(self.booleanPrefab)
	self.multiTextPrefab:unlinkElement()
	FocusManager:removeElement(self.multiTextPrefab)
	self.sectionHeaderPrefab:unlinkElement()
	FocusManager:removeElement(self.sectionHeaderPrefab)
	self.selectorPrefab:unlinkElement()
	FocusManager:removeElement(self.selectorPrefab)
	self.containerPrefab:unlinkElement()
	FocusManager:removeElement(self.containerPrefab)
	for key = 1, CpGlobalSettingsFrame.NUM_CATEGORIES do 
		self.subCategoryPaging:addText(tostring(key))
		self.subCategoryTabs[key] = self.selectorPrefab:clone(self.subCategoryBox)
		FocusManager:loadElementFromCustomValues(self.subCategoryTabs[key])
		self.subCategoryBox:invalidateLayout()
		self.subCategoryTabs[key]:setText(g_i18n:getText(self.CATEGRORY_TEXTS[key]))
		self.subCategoryTabs[key]:getDescendantByName("background"):setSize(
			self.subCategoryTabs[key].size[1], self.subCategoryTabs[key].size[2])
		self.subCategoryTabs[key].onClickCallback = function ()
			self:updateSubCategoryPages(key)
		end
		self.subCategoryPages[key] = self.containerPrefab:clone(self)
		local layout = self.subCategoryPages[key]:getDescendantByName("layout")
		layout.scrollDirection = "vertical"
		FocusManager:loadElementFromCustomValues(self.subCategoryPages[key])
	end
	local _, pageTitle = g_Courseplay.globalSettings:getSettingSetup()
	self.categoryHeaderText:setText(g_i18n:getText(pageTitle))
end

function CpGlobalSettingsFrame:delete()
	self.booleanPrefab:delete()
	self.multiTextPrefab:delete()
	self.sectionHeaderPrefab:delete()
	self.selectorPrefab:delete()
	self.containerPrefab:delete()
	CpGlobalSettingsFrame:superClass().delete(self)
end

function CpGlobalSettingsFrame:onFrameOpen()
	CpGlobalSettingsFrame:superClass().onFrameOpen(self)
	if not self.wasOpened then 
		self.wasOpened = true
		local settings = g_Courseplay.globalSettings:getSettings()
		local settingsBySubTitle = g_Courseplay.globalSettings:getSettingSetup()
		local ix = 1
		for _, data in pairs(settingsBySubTitle) do 
			local layout = self.subCategoryPages[ix]:getDescendantByName("layout")
			CpSettingsUtil.generateAndBindGuiElements(data, layout, 
				self.multiTextPrefab, self.booleanPrefab, settings)
			CpSettingsUtil.updateGuiElementsBoundToSettings(layout)
			if ix >= 2 then 
				break 
			end
			ix = ix + 1
		end
	end
	self:updateSubCategoryPages(self.CATEGRORIES.BASIC_SETTINGS)
end

function CpGlobalSettingsFrame:onClickCpMultiTextOption(_, guiElement)
	CpSettingsUtil.updateGuiElementsBoundToSettings(guiElement.parent.parent)
end

function CpGlobalSettingsFrame:updateSubCategoryPages(state)
	for i, _ in ipairs(self.subCategoryPages) do
		self.subCategoryPages[i]:setVisible(false)
		self.subCategoryTabs[i]:setSelected(false)
	end
	self.subCategoryPages[state]:setVisible(true)
	self.subCategoryTabs[state]:setSelected(true)
	local layout = self.subCategoryPages[state]:getDescendantByName("layout")
	CpSettingsUtil.updateGuiElementsBoundToSettings(layout)
	self.settingsSlider:setDataElement(layout)
	FocusManager:setFocus(layout)
end
