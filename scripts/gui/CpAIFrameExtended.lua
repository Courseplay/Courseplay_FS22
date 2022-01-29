CpInGameMenuAIFrameExtended = {}
CpInGameMenuAIFrameExtended.MODE_COURSE_GENERATOR = 10
--- Adds the course generate button in the ai menu page.

CpInGameMenuAIFrameExtended.positionUvs = GuiUtils.getUVs({
	768,
	4,
	100,
	100
}, AITargetHotspot.FILE_RESOLUTION)

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
	self.courseGeneratorLayout:setVisible(false)
	--- Disables button, if they are outside of the visible scroll layout box.
	local function validateElements(layout)
		for i,element in pairs(layout.elements) do 
			local x,y = element.absPosition[1]+element.absSize[1]/2,element.absPosition[2]+element.absSize[2]/2
			local valid = GuiUtils.checkOverlayOverlap(x,y, layout.absPosition[1], layout.absPosition[2], layout.absSize[1], layout.absSize[2])
			element:setDisabled(not valid)
		end
	end
	self.courseGeneratorLayoutElements.smoothScrollTo = Utils.appendedFunction(self.courseGeneratorLayoutElements.smoothScrollTo,validateElements)
	self.courseGeneratorLayoutElements.invalidateLayout = Utils.appendedFunction(self.courseGeneratorLayoutElements.invalidateLayout,validateElements)
	self.courseGeneratorLayoutElements:invalidateLayout()
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
	
	--- Adds a second map hotspot for field position.
	self.secondAiTargetMapHotspot = AITargetHotspot.new()
	self.secondAiTargetMapHotspot.icon:setUVs(CpInGameMenuAIFrameExtended.positionUvs)
	self.createPositionTemplate.onClickCallback = Utils.prependedFunction(self.createPositionTemplate.onClickCallback,
															CpInGameMenuAIFrameExtended.onClickPositionParameter)

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
--- Also updates the field position map hotspot.
function CpInGameMenuAIFrameExtended:setMapSelectionItem(hotspot)
	g_currentMission.inGameMenu:updatePages()
	g_currentMission:removeMapHotspot(self.secondAiTargetMapHotspot)
	if hotspot ~= nil then
		local vehicle = InGameMenuMapUtil.getHotspotVehicle(hotspot)
		if vehicle then 
			if vehicle.getJob ~= nil and vehicle.getCanGenerateFieldWorkCourse then
				local job = vehicle:getJob()

				if job ~= nil and job.getFieldPositionTarget ~= nil then
					local x, z = job:getFieldPositionTarget()

					self.secondAiTargetMapHotspot:setWorldPosition(x, z)

					g_currentMission:addMapHotspot(self.secondAiTargetMapHotspot)
				end
			end
		end
	end

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
	g_currentMission:removeMapHotspot(self.secondAiTargetMapHotspot)
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
		local vehicles = g_assignedCoursesManager:getRegisteredVehicles()
		for i,v in pairs(vehicles) do 
			v:drawCpCoursePlot(self)
		end
	elseif vehicle and vehicle.drawCpCoursePlot  then 
		vehicle:drawCpCoursePlot(self)
	end
end

function CpInGameMenuAIFrameExtended:delete()
	if self.secondAiTargetMapHotspot ~= nil then
		self.secondAiTargetMapHotspot:delete()

		self.secondAiTargetMapHotspot = nil
	end
end
InGameMenuAIFrame.delete = Utils.appendedFunction(InGameMenuAIFrame.delete,CpInGameMenuAIFrameExtended.delete)

--- Ugly hack to swap the main AI hotspot with the field position hotspot,
--- as only the main hotspot can be moved by the player.
function CpInGameMenuAIFrameExtended:onClickPositionParameter(element,...)
	local parameter = element.aiParameter
	if parameter and parameter.isCpFieldPositionTarget then 
		local x, z = self.aiTargetMapHotspot:getWorldPosition()
		local rot = self.aiTargetMapHotspot:getWorldRotation()
		local dx, dz = self.secondAiTargetMapHotspot:getWorldPosition()
		self.aiTargetMapHotspot:setWorldPosition(dx, dz)
		self.aiTargetMapHotspot.icon:setUVs(CpInGameMenuAIFrameExtended.positionUvs)
		self.secondAiTargetMapHotspot:setWorldPosition(x, z)
		self.secondAiTargetMapHotspot:setWorldRotation(rot)
		self.secondAiTargetMapHotspot.icon:setUVs(AITargetHotspot.UVS)
	end
end

--- Custom version of InGameMenuAIFrame:updateParameterValueTexts(), as 
--- there is no support for our field position hotspot.
function CpInGameMenuAIFrameExtended:updateParameterValueTexts(superFunc)
	g_currentMission:removeMapHotspot(self.aiTargetMapHotspot)
	g_currentMission:removeMapHotspot(self.secondAiTargetMapHotspot)
	local addedPositionHotspot = false
	for _, element in ipairs(self.currentJobElements) do
		local parameter = element.aiParameter
		local parameterType = parameter:getType()

		if parameterType == AIParameterType.TEXT then
			local title = element:getDescendantByName("title")

			title:setText(parameter:getString())
		elseif parameterType == AIParameterType.POSITION or parameterType == AIParameterType.POSITION_ANGLE then
			element:setText(parameter:getString())

			if parameter.isCpFieldPositionTarget then
				g_currentMission:addMapHotspot(self.secondAiTargetMapHotspot)
				local x, z = parameter:getPosition()

				self.secondAiTargetMapHotspot:setWorldPosition(x, z)
				self.secondAiTargetMapHotspot.icon:setUVs(CpInGameMenuAIFrameExtended.positionUvs)
			else
				g_currentMission:addMapHotspot(self.aiTargetMapHotspot)

				local x, z = parameter:getPosition()

				self.aiTargetMapHotspot:setWorldPosition(x, z)
				self.aiTargetMapHotspot.icon:setUVs(AITargetHotspot.UVS)
				if parameterType == AIParameterType.POSITION_ANGLE then
					local angle = parameter:getAngle() + math.pi

					self.aiTargetMapHotspot:setWorldRotation(angle)
				end
			end
		else
			element:updateTitle()
		end
	end

end
InGameMenuAIFrame.updateParameterValueTexts = Utils.overwrittenFunction(InGameMenuAIFrame.updateParameterValueTexts,
															CpInGameMenuAIFrameExtended.updateParameterValueTexts)

--- After the position of the hotspot is set, makes sure the positions of the hot spots are correct.
function CpInGameMenuAIFrameExtended:executePickingCallback(...)
	if not self:getIsPicking() then
		self:updateParameterValueTexts()
	end
end
InGameMenuAIFrame.executePickingCallback = Utils.appendedFunction(InGameMenuAIFrame.executePickingCallback,
															CpInGameMenuAIFrameExtended.executePickingCallback)