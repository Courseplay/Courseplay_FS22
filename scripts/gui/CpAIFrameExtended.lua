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


	self:registerControls({"multiTextOptionPrefab","subTitlePrefab","courseGeneratorLayoutElements","courseGeneratorLayout","courseGeneratorHeader"})


	local element = self:getDescendantByName("ingameMenuAI")

	local xmlFile = loadXMLFile("Temp", Utils.getFilename("config/gui/CourseGeneratorSettingsFrame.xml",Courseplay.BASE_DIRECTORY))
	g_gui:loadGuiRec(xmlFile, "CourseGeneratorLayout", element, self)
	element:updateAbsolutePosition()
	delete(xmlFile)
	self:exposeControlsAsFields()


	self.subTitlePrefab:unlinkElement()
	FocusManager:removeElement(self.subTitlePrefab)
	self.multiTextOptionPrefab:unlinkElement()
	FocusManager:removeElement(self.multiTextOptionPrefab)

	local settingsBySubTitle,pageTitle = CpCourseGeneratorSettings.getSettingSetup()
	CpSettingsUtil.generateGuiElementsFromSettingsTable(settingsBySubTitle,
	self.courseGeneratorLayoutElements,self.multiTextOptionPrefab, self.subTitlePrefab)
	self.courseGeneratorLayoutPageTitle = pageTitle
	self.courseGeneratorLayoutElements:invalidateLayout()
	self.courseGeneratorLayout:setVisible(false)
	
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
	--- Reloads the current vehicle on opening the in game menu.
	local function onOpenInGameMenu(mission)
		local pageAI = mission.inGameMenu.pageAI
		pageAI.controlledVehicle = g_currentMission.controlledVehicle
		pageAI.currentHotspot = nil
	end
	g_currentMission.onToggleMenu = Utils.prependedFunction(g_currentMission.onToggleMenu,onOpenInGameMenu)	

	--- Closes the course generator settings with the back button.
	local function onClickBack(pageAI,superFunc)
		if pageAI.mode == CpInGameMenuAIFrameExtended.MODE_COURSE_GENERATOR then 
			pageAI:onClickOpenCloseCourseGenerator()
			return
		end
		return superFunc(pageAI)
	end 
	self.buttonBack.onClickCallback = Utils.overwrittenFunction(self.buttonBack.onClickCallback,onClickBack)
	self.ingameMapBase.drawHotspotsOnly = Utils.appendedFunction(self.ingameMapBase.drawHotspotsOnly , CpInGameMenuAIFrameExtended.draw)
end
InGameMenuAIFrame.onLoadMapFinished = Utils.appendedFunction(InGameMenuAIFrame.onLoadMapFinished,CpInGameMenuAIFrameExtended.onAIFrameLoadMapFinished)


--- Updates the generate button visibility in the ai menu page.
function CpInGameMenuAIFrameExtended:updateContextInputBarVisibility()
	local isPaused = g_currentMission.paused
	
	if self.buttonGenerateCourse then
		self.buttonGenerateCourse:setVisible(CpInGameMenuAIFrameExtended.getCanGenerateCourse(self))
--		self.buttonGenerateCourse:setDisabled(isPaused)
	end
	if self.buttonOpenCourseGenerator then
		self.buttonOpenCourseGenerator:setVisible(CpInGameMenuAIFrameExtended.getCanOpenCloseCourseGenerator(self))
--		self.buttonOpenCourseGenerator:setDisabled(isPaused)
	end
	self.buttonBack:setVisible(self:getCanGoBack() or self.mode == CpInGameMenuAIFrameExtended.MODE_COURSE_GENERATOR)
	self.buttonGotoJob.parent:invalidateLayout()
end

InGameMenuAIFrame.updateContextInputBarVisibility = Utils.appendedFunction(InGameMenuAIFrame.updateContextInputBarVisibility,CpInGameMenuAIFrameExtended.updateContextInputBarVisibility)

--- Button callback of the ai menu button.
function InGameMenuAIFrame:onClickGenerateFieldWorkCourse()
	if CpInGameMenuAIFrameExtended.getCanGenerateCourse(self) then 
		self.currentJob:onClickGenerateFieldWorkCourse()
		--CpSettingsUtil.updateAiParameters(self.currentJobElements)
	end
end

function CpInGameMenuAIFrameExtended:getCanStartJob(superFunc,...)
	local vehicle = InGameMenuMapUtil.getHotspotVehicle(self.currentHotspot)
	if vehicle and vehicle.getIsCpActive and vehicle:getIsCpActive() then
		return self.currentJob and self.currentJob.getCanStartJob and self.currentJob:getCanStartJob() and superFunc(self,...)
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
			self.currentJob:getCpJobParameters():validateSettings()
			CpSettingsUtil.updateAiParameters(self.currentJobElements)
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
	self.courseGeneratorHeader:setText(title)
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
	self.controlledVehicle = nil
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
	local vehicle = InGameMenuMapUtil.getHotspotVehicle(self.selectedHotspot)
	if CoursePlotAlwaysVisible then
		local vehicles = CpCourseManager.getValidVehicles()
		for i,v in pairs(vehicles) do 
			v:drawCpCoursePlot(self)
		end
	elseif vehicle and vehicle.drawCpCoursePlot  then 
		vehicle:drawCpCoursePlot(self)
	end
end
