CpInGameMenuAIFrameExtended = {}
CpInGameMenuAIFrameExtended.MODE_COURSE_GENERATOR = 10
--- Adds the course generate button in the ai menu page.

function CpInGameMenuAIFrameExtended:onAIFrameLoadMapFinished()
	self.buttonGenerateCourse = self.buttonCreateJob:clone(self.buttonCreateJob.parent)
	self.buttonGenerateCourse:setText(g_i18n:getText("CP_ai_page_generate_course"))
	self.buttonGenerateCourse:setVisible(false)
	self.buttonGenerateCourse:setCallback("onClickCallback", "onClickGenerateFieldWorkCourse")
	self.buttonOpenCourseGenerator = self.buttonGotoJob:clone(self.buttonGotoJob.parent)
	self.buttonOpenCourseGenerator:setText(g_i18n:getText("CP_ai_page_open_course_generator"))
	self.buttonOpenCourseGenerator:setVisible(false)
	self.buttonOpenCourseGenerator:setCallback("onClickCallback", "onClickOpenCloseCourseGenerator")
	self.buttonOpenCourseGenerator.parent:invalidateLayout()

	local inGameMenu = g_currentMission.inGameMenu
	self.courseGeneratorLayout = CpGuiUtil.cloneElementWithProfileName(inGameMenu.pageSettingsGeneral,"ingameMenuSettingsBox",self)
	self.courseGeneratorLayout:setSize(self.courseGeneratorLayout.size[1]-0.15,nil)
	--- Moves the layout slightly to the left
	local x,y = unpack(g_currentMission.inGameMenu.pagingTabList.size)
	self.courseGeneratorLayout:setAbsolutePosition(x+0.02,self.courseGeneratorLayout.absPosition[2]-0.1)
	self.courseGeneratorLayoutElements = self.courseGeneratorLayout:getDescendantById("boxLayout")
	for i = #self.courseGeneratorLayoutElements.elements, 1, -1 do
		self.courseGeneratorLayoutElements.elements[i]:delete()
	end
	
	
	--- Creates a background.
	local bgElement = CpGuiUtil.cloneElementWithProfileName(inGameMenu.pageSettingsGeneral,"multiTextOptionSettingsBg")
	local elements = self.courseGeneratorLayout.elements
	table.insert(elements,1,bgElement)
	bgElement.parent = self.courseGeneratorLayout
	self.courseGeneratorLayout.elements = elements

	local color = {0.0111, 0.0276, 0.0377, 0.95}
	CpGuiUtil.changeColorForElementsWithProfileName(self.courseGeneratorLayout,"multiTextOptionSettingsBg",color)
	CpGuiUtil.executeFunctionForElementsWithProfileName(self.courseGeneratorLayout,"multiTextOptionSettingsBg",GuiElement.setPosition,self.courseGeneratorLayout.position[1]-0.01,self.courseGeneratorLayout.position[2])
	CpGuiUtil.executeFunctionForElementsWithProfileName(self.courseGeneratorLayout,"multiTextOptionSettingsBg",GuiElement.setSize,self.courseGeneratorLayout.size[1]*1.01,self.courseGeneratorLayout.size[2])
	
	--- Adds Setting elements to the layout.
	local layout = g_currentMission.inGameMenu.pageSettingsGeneral.boxLayout
	local genericSettingElement = CpGuiUtil.getGenericSettingElementFromLayout(layout)
	local genericSubTitleElement = CpGuiUtil.getGenericSubTitleElementFromLayout(layout)
	local settingsBySubTitle,pageTitle = CpCourseGeneratorSettings.getSettingSetup()
	CpSettingsUtil.generateGuiElementsFromSettingsTable(settingsBySubTitle,
	self.courseGeneratorLayoutElements,genericSettingElement, genericSubTitleElement)
	
	CpGuiUtil.executeFunctionForElementsWithProfileName(self.courseGeneratorLayoutElements,"multiTextOptionSettingsTooltip",function (item) item.textMaxWidth = item.textMaxWidth/2 end)

	self.courseGeneratorLayoutPageTitle = pageTitle
	
	local function hasText(element)
		return element:isa(TextElement)
	end
	CpGuiUtil.executeFunctionForElements(self.courseGeneratorLayoutElements,hasText,TextElement.setTextColor,
										CpGuiUtil.getNormalizedRgb(45, 207, 255,1))

	self.courseGeneratorLayoutElements:invalidateLayout()
--	self.courseGeneratorLayoutElements.targetName = self.jobTypeElement.targetName
	self.courseGeneratorLayout:setVisible(false)
	CpGuiUtil.setTarget(self.courseGeneratorLayout,self)
	--- Makes the last selected hotspot is not sold before reopening.
	local function validateCurrentHotspot(currentMission,hotspot)
		local page = currentMission.inGameMenu.pageAI
		if page and hotspot then 
			if hotspot == page.currentHotspot or hotspot == page.lastHotspot then 
				page.currentHotspot = nil
				page.lastHotspot = nil
				page:setMapSelectionItem(nil)
				currentMission.inGameMenu:updatePages()
			end
		end
	end
	g_currentMission.removeMapHotspot = Utils.appendedFunction(g_currentMission.removeMapHotspot,validateCurrentHotspot)
	
end
InGameMenuAIFrame.onLoadMapFinished = Utils.appendedFunction(InGameMenuAIFrame.onLoadMapFinished,CpInGameMenuAIFrameExtended.onAIFrameLoadMapFinished)


--- Updates the generate button visibility in the ai menu page.
function CpInGameMenuAIFrameExtended:updateContextInputBarVisibilityIngameMenu()
	local isPaused = g_currentMission.paused
	
	if self.buttonGenerateCourse then
		self.buttonGenerateCourse:setVisible(CpInGameMenuAIFrameExtended.getCanGenerateCourse(self))
--		self.buttonGenerateCourse:setDisabled(isPaused)
	end
	if self.buttonOpenCourseGenerator then
		self.buttonOpenCourseGenerator:setVisible(CpInGameMenuAIFrameExtended.getCanOpenCloseCourseGenerator(self))
--		self.buttonOpenCourseGenerator:setDisabled(isPaused)
	end
	self.buttonGotoJob.parent:invalidateLayout()
end

InGameMenuAIFrame.updateContextInputBarVisibility = Utils.appendedFunction(InGameMenuAIFrame.updateContextInputBarVisibility,CpInGameMenuAIFrameExtended.updateContextInputBarVisibilityIngameMenu)

--- Button callback of the ai menu button.
function InGameMenuAIFrame:onClickGenerateFieldWorkCourse()
	if CpInGameMenuAIFrameExtended.getCanGenerateCourse(self) then 
		self.currentJob:onClickGenerateFieldWorkCourse()
	end
end

function CpInGameMenuAIFrameExtended:getCanStartJob(superFunc,...)
	local vehicle = InGameMenuMapUtil.getHotspotVehicle(self.currentHotspot)
	if vehicle and self.currentJob and self.currentJob.getCanGenerateFieldWorkCourse then 
		return vehicle:hasCpCourse() and superFunc(self,...)
	end 
	return superFunc(self,...)
end
InGameMenuAIFrame.getCanStartJob = Utils.overwrittenFunction(InGameMenuAIFrame.getCanStartJob,CpInGameMenuAIFrameExtended.getCanStartJob)

function CpInGameMenuAIFrameExtended:getCanGenerateCourse()
	return self.mode == CpInGameMenuAIFrameExtended.MODE_COURSE_GENERATOR and self.currentJob and self.currentJob.getCanGenerateFieldWorkCourse and self.currentJob:getCanGenerateFieldWorkCourse() and not self:getIsPicking()
end

function CpInGameMenuAIFrameExtended:getCanOpenCloseCourseGenerator()
	local vehicle = InGameMenuMapUtil.getHotspotVehicle(self.currentHotspot)
	local visible = vehicle ~= nil and self.currentJob and self.currentJob.getCanGenerateFieldWorkCourse
	return visible and self.mode ~= InGameMenuAIFrame.MODE_OVERVIEW and not self:getIsPicking()
end

function InGameMenuAIFrame:onClickOpenCloseCourseGenerator()
	if CpInGameMenuAIFrameExtended.getCanOpenCloseCourseGenerator(self) then 
		if self.mode == CpInGameMenuAIFrameExtended.MODE_COURSE_GENERATOR then 
			self.courseGeneratorLayout:setVisible(false)
			self.contextBox:setVisible(true)
			self:toggleMapInput(true)
			self.ingameMap:onOpen()
			self.ingameMap:registerActionEvents()
			self.mode = InGameMenuAIFrame.MODE_CREATE
			self:setJobMenuVisible(true)
			FocusManager:setFocus(self.jobTypeElement)
			CpInGameMenuAIFrameExtended.unbindCourseGeneratorSettings(self)
		else
			self.mode = CpInGameMenuAIFrameExtended.MODE_COURSE_GENERATOR
			self.courseGeneratorLayout:setVisible(true)
			self:toggleMapInput(false)
			self:setJobMenuVisible(false)
			self.contextBox:setVisible(false)
			CpInGameMenuAIFrameExtended.bindCourseGeneratorSettings(self)
			FocusManager:loadElementFromCustomValues(self.courseGeneratorLayoutElements)
			self.courseGeneratorLayoutElements:invalidateLayout()
			CpGuiUtil.debugFocus(self.courseGeneratorLayoutElements,nil)
			FocusManager:setFocus(self.courseGeneratorLayoutElements)
		end
	end
end

function CpInGameMenuAIFrameExtended:bindCourseGeneratorSettings()
	local vehicle = InGameMenuMapUtil.getHotspotVehicle(self.currentHotspot)
	local title = string.format(self.courseGeneratorLayoutPageTitle,vehicle:getName())
	CpGuiUtil.changeTextForElementsWithProfileName(self,"settingsMenuSubtitle",title)
	if vehicle ~=nil then 
		if vehicle.getCourseGeneratorSettings then 
			CpUtil.debugVehicle( CpUtil.DBG_HUD,vehicle, "binding course generator settings." )
			self.settings = vehicle:getCourseGeneratorSettingsTable()
			CpSettingsUtil.linkGuiElementsAndSettings(self.settings,self.courseGeneratorLayoutElements)
		end
	end
end

function CpInGameMenuAIFrameExtended:unbindCourseGeneratorSettings()
	local vehicle = InGameMenuMapUtil.getHotspotVehicle(self.currentHotspot)
	if self.settings then
		CpUtil.debugVehicle( CpUtil.DBG_HUD,vehicle, "unbinding course generator settings." )
		CpSettingsUtil.unlinkGuiElementsAndSettings(self.settings,self.courseGeneratorLayoutElements)
	end
	self.courseGeneratorLayoutElements:invalidateLayout()
end


--- Updates the visibility of the vehicle settings on select/unselect of a vehicle in the ai menu page.
function CpInGameMenuAIFrameExtended:setMapSelectionItem()
	g_currentMission.inGameMenu:updatePages()
end
InGameMenuAIFrame.setMapSelectionItem = Utils.appendedFunction(InGameMenuAIFrame.setMapSelectionItem,CpInGameMenuAIFrameExtended.setMapSelectionItem)


function CpInGameMenuAIFrameExtended:onAIFrameOpen()
	if self.mode == CpInGameMenuAIFrameExtended.MODE_COURSE_GENERATOR then 
		self.contextBox:setVisible(false)
	end
	--- Select the last vehicle after reopening of the page.
	if self.lastHotspot then 
		local vehicle = InGameMenuMapUtil.getHotspotVehicle(self.lastHotspot)
		if vehicle ~=nil then 
			local hotspot = vehicle:getMapHotspot()

			self:setMapSelectionItem(hotspot)
		end
	end
end
InGameMenuAIFrame.onFrameOpen = Utils.appendedFunction(InGameMenuAIFrame.onFrameOpen,CpInGameMenuAIFrameExtended.onAIFrameOpen)

function CpInGameMenuAIFrameExtended:onAIFrameClose()
	self.courseGeneratorLayout:setVisible(false)
	self.contextBox:setVisible(true)
	self.lastHotspot = self.currentHotspot
end
InGameMenuAIFrame.onFrameClose = Utils.appendedFunction(InGameMenuAIFrame.onFrameClose,CpInGameMenuAIFrameExtended.onAIFrameClose)

function CpInGameMenuAIFrameExtended:onCreateJob()
	if not g_currentMission.paused then
		if CpInGameMenuAIFrameExtended.getCanGenerateCourse(self) then 
			self:onClickGenerateFieldWorkCourse()
		end
	end
end
InGameMenuAIFrame.onCreateJob = Utils.appendedFunction(InGameMenuAIFrame.onCreateJob,CpInGameMenuAIFrameExtended.onCreateJob)

function CpInGameMenuAIFrameExtended:onStartGoToJob()
	if not g_currentMission.paused then
		if CpInGameMenuAIFrameExtended.getCanOpenCloseCourseGenerator(self) then
			self:onClickOpenCloseCourseGenerator()
		end
	end
end
InGameMenuAIFrame.onStartGoToJob = Utils.appendedFunction(InGameMenuAIFrame.onStartGoToJob,CpInGameMenuAIFrameExtended.onStartGoToJob)

function CpInGameMenuAIFrameExtended:draw()	
	local CoursePlotAlwaysVisible = g_Courseplay.globalSettings:getSettings().showsAllActiveCourses:getValue()
	local vehicle = InGameMenuMapUtil.getHotspotVehicle(self.currentHotspot)
	if CoursePlotAlwaysVisible then
		local vehicles = CpCourseManager.getValidVehicles()
		for i,v in pairs(vehicles) do 
			v:drawCpCoursePlot(self.ingameMapBase)
		end
	elseif vehicle and vehicle.drawCpCoursePlot  then 
		vehicle:drawCpCoursePlot(self.ingameMapBase)
	end
end
InGameMenuAIFrame.draw = Utils.appendedFunction(InGameMenuAIFrame.draw, CpInGameMenuAIFrameExtended.draw)