CpGiantsGuiExtended = {}

--- Adds the course generate button in the ai menu page.
function CpGiantsGuiExtended.onAIFrameLoadMapFinished(aiFrame)

	aiFrame.buttonGenerateCourse = aiFrame.buttonGotoJob:clone(aiFrame.buttonGotoJob.parent)
	aiFrame.buttonGenerateCourse:setText(g_i18n:getText("CP_ai_page_generate_course"))
	aiFrame.buttonGenerateCourse:setVisible(false)
	aiFrame.buttonGenerateCourse:setCallback("onClickCallback", "onClickGenerateFieldWorkCourse")
	aiFrame.buttonGotoJob.parent:invalidateLayout()
	aiFrame.buttonOpenCourseGenerator = aiFrame.buttonGenerateCourse:clone(aiFrame.buttonGotoJob.parent)
	aiFrame.buttonOpenCourseGenerator:setText(g_i18n:getText("CP_ai_page_open_course_generator"))
	aiFrame.buttonOpenCourseGenerator:setVisible(false)
	aiFrame.buttonOpenCourseGenerator:setCallback("onClickCallback", "onClickOpenCloseCourseGenerator")
	aiFrame.buttonOpenCourseGenerator.parent:invalidateLayout()

	local inGameMenu = g_currentMission.inGameMenu
	aiFrame.courseGeneratorLayout = CpGuiUtil.cloneElementWithProfileName(inGameMenu.pageSettingsGeneral,"ingameMenuSettingsBox",aiFrame)
	
	--- Moves the layout slightly to the left
	local x,y = unpack(g_currentMission.inGameMenu.pagingTabList.size)
	aiFrame.courseGeneratorLayout:setAbsolutePosition(x+0.02,aiFrame.courseGeneratorLayout.absPosition[2])

	--- Clears elements from the cloned page.
	aiFrame.courseGeneratorLayoutElements = CpGuiUtil.getFirstElementWithProfileName(aiFrame.courseGeneratorLayout,"ingameMenuSettingsLayout")
	aiFrame.courseGeneratorLayoutElements.elements = {}
	
	--- Creates a background.
	CpGuiUtil.cloneElementWithProfileName(inGameMenu.pageSettingsGeneral,"multiTextOptionSettingsBg",aiFrame.courseGeneratorLayout)
	local color = {0, 0, 0, 0.8}
	CpGuiUtil.changeColorForElementsWithProfileName(aiFrame.courseGeneratorLayout,"multiTextOptionSettingsBg",color)
	CpGuiUtil.executeFunctionForElementsWithProfileName(aiFrame.courseGeneratorLayout,"multiTextOptionSettingsBg",GuiElement.setPosition,aiFrame.courseGeneratorLayout.position[1]-0.01,aiFrame.courseGeneratorLayout.position[2])
	CpGuiUtil.executeFunctionForElementsWithProfileName(aiFrame.courseGeneratorLayout,"multiTextOptionSettingsBg",GuiElement.setSize,aiFrame.courseGeneratorLayout.size[1]*1.01,aiFrame.courseGeneratorLayout.size[2])

	--- Adds Setting elements to the layout.
	local layout = g_currentMission.inGameMenu.pageSettingsGeneral.boxLayout
	local genericSettingElement = CpGuiUtil.getGenericSettingElementFromLayout(layout)
	local genericSubTitleElement = CpGuiUtil.getGenericSubTitleElementFromLayout(layout)
	local settingsBySubTitle,pageTitle = CpCourseGeneratorSettings.getSettingSetup()
	CpSettingsUtil.generateGuiElementsFromSettingsTable(settingsBySubTitle,
	aiFrame.courseGeneratorLayoutElements,genericSettingElement, genericSubTitleElement)
	aiFrame.courseGeneratorLayoutPageTitle = pageTitle

	local function hasText(element)
		return element:isa(TextElement)
	end
	CpGuiUtil.executeFunctionForElements(aiFrame.courseGeneratorLayoutElements,hasText,TextElement.setTextColor,
										CpGuiUtil.getNormalizedRgb(45, 207, 255,1))

	aiFrame.courseGeneratorLayoutElements:invalidateLayout()
	aiFrame.courseGeneratorLayout:setVisible(false)
	
end
InGameMenuAIFrame.onLoadMapFinished = Utils.appendedFunction(InGameMenuAIFrame.onLoadMapFinished,CpGiantsGuiExtended.onAIFrameLoadMapFinished)


--- Updates the generate button visibility in the ai menu page.
function CpGiantsGuiExtended.updateContextInputBarVisibilityIngameMenu(aiFrame)
	if aiFrame.buttonGenerateCourse then
		aiFrame.buttonGenerateCourse:setVisible(CpGiantsGuiExtended.getCanGenerateCourse(aiFrame))
	end
	if aiFrame.buttonOpenCourseGenerator then
		local visible = aiFrame.currentJob and aiFrame.currentJob.getCanGenerateFieldWorkCourse
		aiFrame.buttonOpenCourseGenerator:setVisible(visible)
	end
end

InGameMenuAIFrame.updateContextInputBarVisibility = Utils.appendedFunction(InGameMenuAIFrame.updateContextInputBarVisibility,CpGiantsGuiExtended.updateContextInputBarVisibilityIngameMenu)

--- Button callback of the ai menu button.
function InGameMenuAIFrame.onClickGenerateFieldWorkCourse(aiFrame)
	if aiFrame.currentJob and aiFrame.currentJob.getCanGenerateFieldWorkCourse and aiFrame.currentJob:getCanGenerateFieldWorkCourse() then 
		aiFrame.currentJob:onClickGenerateFieldWorkCourse()
	end
end

function CpGiantsGuiExtended.getCanStartJob(aiFrame,superFunc,...)
	if aiFrame.currentJob and aiFrame.currentJob.getCanGenerateFieldWorkCourse then 
		return aiFrame.courseGeneratorScreenVisible == false and aiFrame.currentJob:hasGeneratedCourse() and superFunc(aiFrame,...)
	end 
	return superFunc(aiFrame,...)
end
InGameMenuAIFrame.getCanStartJob = Utils.overwrittenFunction(InGameMenuAIFrame.getCanStartJob,CpGiantsGuiExtended.getCanStartJob)

function CpGiantsGuiExtended.getCanGenerateCourse(aiFrame)
	return aiFrame.courseGeneratorScreenVisible and aiFrame.currentJob and aiFrame.currentJob.getCanGenerateFieldWorkCourse and aiFrame.currentJob:getCanGenerateFieldWorkCourse()
end

function InGameMenuAIFrame.onClickOpenCloseCourseGenerator(aiFrame)
	if aiFrame.courseGeneratorScreenVisible then 
		aiFrame.courseGeneratorScreenVisible = false
		aiFrame.courseGeneratorLayout:setVisible(false)
		aiFrame:setJobMenuVisible(true)
		aiFrame.ingameMap:setDisabled(false)
		aiFrame.contextBox:setVisible(true)
		CpGiantsGuiExtended.unbindCourseGeneratorSettings(aiFrame)
	else
		aiFrame.courseGeneratorScreenVisible = true
		aiFrame.courseGeneratorLayout:setVisible(true)
		aiFrame:setJobMenuVisible(false)
		aiFrame.ingameMap:setDisabled(true)
		aiFrame.contextBox:setVisible(false)
		CpGiantsGuiExtended.bindCourseGeneratorSettings(aiFrame)
	end
end

function CpGiantsGuiExtended.bindCourseGeneratorSettings(aiFrame)
	local vehicle = InGameMenuMapUtil.getHotspotVehicle(aiFrame.currentHotspot)
	local title = string.format(aiFrame.courseGeneratorLayoutPageTitle,vehicle:getName())
	CpGuiUtil.changeTextForElementsWithProfileName(aiFrame,"settingsMenuSubtitle",title)
	if vehicle ~=nil then 
		if vehicle.getCourseGeneratorSettings then 
			CpUtil.debugVehicle( CpUtil.DBG_HUD,vehicle, "binding course generator settings." )
			aiFrame.settings = vehicle:getCourseGeneratorSettings()
			CpSettingsUtil.linkGuiElementsAndSettings(aiFrame.settings,aiFrame.courseGeneratorLayoutElements)
		end
	end
	aiFrame.courseGeneratorLayoutElements:invalidateLayout()
end

function CpGiantsGuiExtended.unbindCourseGeneratorSettings(aiFrame)
	local vehicle = InGameMenuMapUtil.getHotspotVehicle(aiFrame.currentHotspot)
	if aiFrame.settings then
		CpUtil.debugVehicle( CpUtil.DBG_HUD,vehicle, "unbinding course generator settings." )
		CpSettingsUtil.unlinkGuiElementsAndSettings(aiFrame.settings,aiFrame.courseGeneratorLayoutElements)
	end
	aiFrame.courseGeneratorLayoutElements:invalidateLayout()
end


--- Updates the visibility of the vehicle settings on select/unselect of a vehicle in the ai menu page.
function CpGiantsGuiExtended.setMapSelectionItem(aiFrame)
	g_currentMission.inGameMenu:updatePages()
end
InGameMenuAIFrame.setMapSelectionItem = Utils.appendedFunction(InGameMenuAIFrame.setMapSelectionItem,CpGiantsGuiExtended.setMapSelectionItem)


function CpGiantsGuiExtended.onAIFrameOpen(aiFrame)
	if aiFrame.courseGeneratorScreenVisible then 
		aiFrame.contextBox:setVisible(false)
	end
end
InGameMenuAIFrame.onFrameOpen = Utils.appendedFunction(InGameMenuAIFrame.onFrameOpen,CpGiantsGuiExtended.onAIFrameOpen)

function CpGiantsGuiExtended.onAIFrameClose(aiFrame)
	
end
InGameMenuAIFrame.onFrameClose = Utils.appendedFunction(InGameMenuAIFrame.onFrameClose,CpGiantsGuiExtended.onAIFrameClose)

