CpGiantsGuiExtended = {}

--- Adds the course generate button in the ai menu page.
function CpGiantsGuiExtended.loadFromXmlInGameMenu(self, xmlFile, key)
	if self.buttonGenerateCourse then
		self.buttonGenerateCourse = self.buttonGotoJob:clone(self.buttonGotoJob.parent)
		self.buttonGenerateCourse:setText(g_i18n:getText(AIJobFieldWorkCp.translations.GenerateButton))
		self.buttonGenerateCourse:setVisible(false)
		self.buttonGenerateCourse.onClickCallback = self.onClickGenerateFieldWorkCourse
		self.buttonGotoJob.parent:invalidateLayout()
	end
end
InGameMenuAIFrame.onLoadMapFinished = Utils.appendedFunction(InGameMenuAIFrame.onLoadMapFinished,CpGiantsGuiExtended.loadFromXmlInGameMenu)


--- Updates the generate button visibility in the ai menu page.
function CpGiantsGuiExtended.updateContextInputBarVisibilityIngameMenu(self)
	if self.buttonGenerateCourse then
		local visible = self.currentJob and self.currentJob.getCanGenerateFieldWorkCourse and self.currentJob:getCanGenerateFieldWorkCourse()
		self.buttonGenerateCourse:setVisible(visible)
	end
end

InGameMenuAIFrame.updateContextInputBarVisibility = Utils.appendedFunction(InGameMenuAIFrame.updateContextInputBarVisibility,CpGiantsGuiExtended.updateContextInputBarVisibilityIngameMenu)

--- Button callback of the ai menu button.
function InGameMenuAIFrame:onClickGenerateFieldWorkCourse()
	if self.currentJob and self.currentJob.getCanGenerateFieldWorkCourse and self.currentJob:getCanGenerateFieldWorkCourse() then 
		self.currentJob:onClickGenerateFieldWorkCourse()
	end
end

--- Updates the visibility of the vehicle settings on select/unselect of a vehicle in the ai menu page.
function CpGiantsGuiExtended.setMapSelectionItem(self)
	g_currentMission.inGameMenu:updatePages()
end
InGameMenuAIFrame.setMapSelectionItem = Utils.appendedFunction(InGameMenuAIFrame.setMapSelectionItem,CpGiantsGuiExtended.setMapSelectionItem)
