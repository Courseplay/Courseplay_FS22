
--[[
	This frame is a page for the course manager.
]]--

CpCourseManagerFrame = {}
CpCourseManagerFrame.translations = {
	["title"] = "CP_courseManager_title",

	["loadCourse"] = "CP_courseManager_course_load",
	["saveCourse"] = "CP_courseManager_course_save",
	["clearCurrentCourse"] = "CP_courseManager_course_clear_current",
	["deleteCourse"] = "CP_courseManager_course_delete",
	["renameCourse"] = "CP_courseManager_course_rename",

	["createFolder"] = "CP_courseManager_folder_create",
	["deleteFolder"] = "CP_courseManager_folder_delete",
	["moveCourse"] = "CP_courseManager_folder_move_course",
	["renameFolder"] = "CP_courseManager_folder_rename",

	["folderDialogTitle"] = "CP_courseManager_folder_dialog",
	["courseDialogTitle"] = "CP_courseManager_course_dialog",
}
CpCourseManagerFrame.MODE_COURSE = 1
CpCourseManagerFrame.MODE_FOLDER = 2
CpCourseManagerFrame.MODE_MOVE_COURSE = 3

---Creates the in game menu page.
function CpCourseManagerFrame.init()

	local inGameMenu = g_gui.screenControllers[InGameMenu]
	local function predicateFunc()
		local inGameMenu = g_gui.screenControllers[InGameMenu]
		local aiPage = inGameMenu.pageAI

		local allowed = inGameMenu.currentPage == inGameMenu.pageCpVehicleSettings or inGameMenu.currentPage == inGameMenu.pageCourseManager or
						aiPage.currentHotspot ~= nil
		return allowed
	end
	local page = CpGuiUtil.getNewInGameMenuFrame(inGameMenu,inGameMenu.pagePrices,CpCourseManagerFrame
												,predicateFunc,3)
	inGameMenu.pageCourseManager = page
end

--- Setup of the gui elements and binds the settings to the gui elements.
function CpCourseManagerFrame:initialize()
	local inGameMenu = g_gui.screenControllers[InGameMenu]
	self.courseList = self.priceList
	self.folderList = self.productList
	--- Changes titles
	self.pageTitle = CpGuiUtil.getFirstElementWithProfileName(self,"ingameMenuFrameHeaderText") 
	local elements = CpGuiUtil.getElementsWithProfileName(self,"ingameCalendarHeaderBox")
	elements[1].elements[1]:setText("Folders")
	elements[1].elements[2]:delete()
	elements[2].elements[1]:setText("Courses")
	elements[2].elements[2]:delete()
	elements[2].elements[2]:delete()
	--- Deletes unused layout.
	self:getDescendantById("fluctuationsColumn"):delete()
	self.noSellpointsText:delete()

	local function clearElementSelection(self,superFunc)
		superFunc(self)
		if self.delegate and self.delegate.onClearElementSelection then 
			self.delegate:onClearElementSelection(self)
		end
	end
	self.courseList.clearElementSelection = Utils.overwrittenFunction(self.courseList.clearElementSelection,clearElementSelection)


	self.courseButtonInfo = {}
	self.folderButtonInfo = {}
	
	--- Course actions
	self.courseButtonInfo.clearCurrentCourseButtonInfo = {
		profile = "buttonActivate",
		inputAction = InputAction.MENU_ACTIVATE,
		text = g_i18n:getText(CpCourseManagerFrame.translations.clearCurrentCourse),
		callback = function ()
			CpCourseManagerFrame.onClickClearCurrentCourse(self)
		end
	}
	self.courseButtonInfo.loadOrSaveButtonInfo = {
		profile = "buttonActivate",
		inputAction = InputAction.MENU_ACTIVATE,
		text = g_i18n:getText(CpCourseManagerFrame.translations.loadCourse),
		callback = function ()
			CpCourseManagerFrame.onClickLoadOrSaveCourse(self)
		end
	}	
	self.courseButtonInfo.deleteCourseButtonInfo = {
		profile = "buttonActivate",
		inputAction = InputAction.MENU_ACTIVATE,
		text = g_i18n:getText(CpCourseManagerFrame.translations.deleteCourse),
		callback = function ()
			CpCourseManagerFrame.onClickDeleteCourse(self)
		end
	}
	self.courseButtonInfo.renameCourseButtonInfo = {
		profile = "buttonActivate",
		inputAction = InputAction.MENU_ACTIVATE,
		text = g_i18n:getText(CpCourseManagerFrame.translations.renameCourse),
		callback = function ()
			CpCourseManagerFrame.onClickRenameCourse(self)
		end
	}
	--- Folder actions
	self.folderButtonInfo.createFolderButtonInfo = {
		profile = "buttonActivate",
		inputAction = InputAction.MENU_ACTIVATE,
		text = g_i18n:getText(CpCourseManagerFrame.translations.createFolder),
		callback = function ()
			CpCourseManagerFrame.onClickCreateFolder(self)
		end
	}
	self.folderButtonInfo.deleteFolderButtonInfo = {
		profile = "buttonActivate",
		inputAction = InputAction.MENU_ACTIVATE,
		text = g_i18n:getText(CpCourseManagerFrame.translations.deleteFolder),
		callback = function ()
			CpCourseManagerFrame.onClickDeleteFolder(self)
		end
	}
	self.folderButtonInfo.renameFolderButtonInfo = {
		profile = "buttonActivate",
		inputAction = InputAction.MENU_ACTIVATE,
		text = g_i18n:getText(CpCourseManagerFrame.translations.renameFolder),
		callback = function ()
			CpCourseManagerFrame.onClickRenameFolder(self)
		end
	}
	self.folderButtonInfo.moveCourseButtonInfo = {
		profile = "buttonActivate",
		inputAction = InputAction.MENU_ACTIVATE,
		text = g_i18n:getText(CpCourseManagerFrame.translations.moveCourse),
		callback = function ()
			CpCourseManagerFrame.onClickMoveCourse(self)
		end
	}
end

function CpCourseManagerFrame:onGuiSetupFinished()
	InGameMenuPricesFrame:superClass().onGuiSetupFinished(self)
	self.folderList:setDataSource(self)
	self.folderList.delegate = self
	self.courseList:setDataSource(self)
	self.courseList.delegate = self
end

function CpCourseManagerFrame:onFrameOpen()
	InGameMenuPricesFrame:superClass().onFrameOpen(self)
	self.mode = CpCourseManagerFrame.MODE_FOLDER
	local currentHotspot = g_currentMission.inGameMenu.pageAI.currentHotspot
	self.currentVehicle =  InGameMenuMapUtil.getHotspotVehicle(currentHotspot)
--	self:setSoundSuppressed(true)
--	FocusManager:setFocus(self.boxLayout)
--	self:setSoundSuppressed(false)
	self.folderList:reloadData()
	self.courseList:reloadData()
	self:updateMenuButtons()
	self.movedCourseSelectedIx = nil
	self.initialized = true
end
	
function CpCourseManagerFrame:onFrameClose()
	InGameMenuPricesFrame:superClass().onFrameClose(self)
	self.initialized = false
end

function CpCourseManagerFrame:getNumberOfItemsInSection(list, section)
	local entries = g_courseManager:getEntries()
	if list == self.folderList then
		return 3
	else
		return #entries
	end
end

function CpCourseManagerFrame:populateCellForItemInSection(list, section, index, cell)
	if list == self.folderList then

		cell:getAttribute("icon"):setVisible(false)
		cell:getAttribute("title"):setText("folder: "..index)

	else
		local entry = g_courseManager:getEntryByIndex(index)
	
		cell:getAttribute("hotspot"):setVisible(false)

		cell:getAttribute("title"):setText(entry:getName())

		cell:getAttribute("price"):setVisible(false)
		cell:getAttribute("buyPrice"):setVisible(false)
		cell:getAttribute("priceTrend"):setVisible(false)

	end
end

function CpCourseManagerFrame:onListSelectionChanged(list, section, index)
	if list == self.folderList then 
	--	self.courseList:reloadData()
		CpUtil.debugFormat(CpUtil.DBG_HUD,"folderList -> onListSelectionChanged")
		if self.movedCourseSelectedIx ~= nil then 
			CpUtil.debugFormat(CpUtil.DBG_HUD,"Moved course(%d) to folder(%d)",self.movedCourseSelectedIx,index)
			self.movedCourseSelectedIx = nil
			self.mode = CpCourseManagerFrame.MODE_FOLDER
			self:updateMenuButtons()
		end
	else
		CpUtil.debugFormat(CpUtil.DBG_HUD,"courseList -> onListSelectionChanged")
		if self.mode == CpCourseManagerFrame.MODE_FOLDER and self.initialized then 
			self.mode = CpCourseManagerFrame.MODE_COURSE
			self:updateMenuButtons()
		elseif self.mode == CpCourseManagerFrame.MODE_MOVE_COURSE then 
			self.movedCourseSelectedIx = index
		end
	end
end

function CpCourseManagerFrame:onClearElementSelection(list)
	CpUtil.debugFormat(CpUtil.DBG_HUD,"courseList -> onClearElementSelection")
	if self.mode == CpCourseManagerFrame.MODE_COURSE then 
		self.mode = CpCourseManagerFrame.MODE_FOLDER 
		self:updateMenuButtons()
	end
end

function CpCourseManagerFrame:updateMenuButtons()
	local courseName = self.currentVehicle:getCourseName()
	local title = string.format(g_i18n:getText(CpCourseManagerFrame.translations.title),courseName)
	self.pageTitle:setText(title)

	self.menuButtonInfo = {
		{
			inputAction = InputAction.MENU_BACK
		}
	}
	local hasCourse,isSaved = g_courseManager:hasCourse(self.currentVehicle)
	self.courseButtonInfo.loadOrSaveButtonInfo.text = not hasCourse and g_i18n:getText(CpCourseManagerFrame.translations.loadCourse) or 
													  	g_i18n:getText(CpCourseManagerFrame.translations.saveCourse)
	if self.mode == CpCourseManagerFrame.MODE_COURSE then 
		if hasCourse then
			table.insert(self.menuButtonInfo, self.courseButtonInfo.clearCurrentCourseButtonInfo)
		end
		table.insert(self.menuButtonInfo, self.courseButtonInfo.loadOrSaveButtonInfo)
	--	table.insert(self.menuButtonInfo, self.courseButtonInfo.deleteCourseButtonInfo)
	--	table.insert(self.menuButtonInfo, self.courseButtonInfo.renameCourseButtonInfo)
	elseif self.mode == CpCourseManagerFrame.MODE_FOLDER then 
		if hasCourse then
			table.insert(self.menuButtonInfo, self.courseButtonInfo.clearCurrentCourseButtonInfo)
		end
	--	table.insert(self.menuButtonInfo, self.folderButtonInfo.moveCourseButtonInfo)
		table.insert(self.menuButtonInfo, self.courseButtonInfo.loadOrSaveButtonInfo)
	--	table.insert(self.menuButtonInfo, self.folderButtonInfo.createFolderButtonInfo)
	--	table.insert(self.menuButtonInfo, self.folderButtonInfo.deleteFolderButtonInfo)
	--	table.insert(self.menuButtonInfo, self.folderButtonInfo.renameFolderButtonInfo)
	elseif self.mode == CpCourseManagerFrame.MODE_MOVE_COURSE then 
		
	end
	
	self:setMenuButtonInfoDirty()
end

function CpCourseManagerFrame:onClickLoadOrSaveCourse()
	local hasCourse = self.currentVehicle:hasCourse()
	CpUtil.debugFormat(CpUtil.DBG_HUD,"onClickLoadOrSaveCourse")
	local courseIx = self.courseList:getSelectedIndexInSection()
	if not hasCourse then -- only allow saving if it not already saved!
		self.currentVehicle:loadCourse(courseIx)
	else 
		CpCourseManagerFrame.showInputTextDialog(self,CpCourseManagerFrame.translations.courseDialogTitle,
												CpCourseManagerFrame.onClickSaveCourseDialog)
	end
end

function CpCourseManagerFrame:onClickSaveCourseDialog(text,clickOk)
	if clickOk then 
		CpUtil.debugFormat(CpUtil.DBG_HUD,"onClickSaveCourseDialog- > %s",text)
		self.currentVehicle:saveCourse(nil,text)
		self.courseList:reloadData()
	end
end

function CpCourseManagerFrame:onClickClearCurrentCourse()
	CpUtil.debugFormat(CpUtil.DBG_HUD,"onClickClearCurrentCourse")
	local hasCourse,isSaved = self.currentVehicle:hasCourse()
	if hasCourse then 
		self.currentVehicle:resetCourse()
		self:updateMenuButtons()
	end
end

function CpCourseManagerFrame:onClickDeleteCourse()
	CpUtil.debugFormat(CpUtil.DBG_HUD,"onClickDeleteCourse")
end

function CpCourseManagerFrame:onClickRenameCourse()
	CpUtil.debugFormat(CpUtil.DBG_HUD,"onClickRenameCourse")
	local courseIx = self.courseList:getSelectedIndexInSection()
	CpCourseManagerFrame.showInputTextDialog(self,CpCourseManagerFrame.translations.courseDialogTitle,
											CpCourseManagerFrame.onClickRenameCourseDialog,courseIx)
end

function CpCourseManagerFrame:onClickRenameCourseDialog(text,clickOk,ix)
	if clickOk then 
		CpUtil.debugFormat(CpUtil.DBG_HUD,"onClickRenameCourseDialog(%d) - > %s",ix,text)
	end
end

function CpCourseManagerFrame:onClickCreateFolder()
	CpUtil.debugFormat(CpUtil.DBG_HUD,"onClickCreateFolder")
	CpCourseManagerFrame.showInputTextDialog(self,CpCourseManagerFrame.translations.folderDialogTitle,
											CpCourseManagerFrame.onClickCreateFolderDialog)
end

function CpCourseManagerFrame:onClickCreateFolderDialog(text,clickOk)
	if clickOk then 
		CpUtil.debugFormat(CpUtil.DBG_HUD,"onClickCreateFolderDialog - > %s",text)
		g_courseManager:createDirectory(nil, text)
	end
end

function CpCourseManagerFrame:onClickDeleteFolder()
	CpUtil.debugFormat(CpUtil.DBG_HUD,"onClickDeleteFolder")
end

function CpCourseManagerFrame:onClickRenameFolder()
	CpUtil.debugFormat(CpUtil.DBG_HUD,"onClickRenameFolder")
	local folderIx = self.folderList:getSelectedIndexInSection()
	CpCourseManagerFrame.showInputTextDialog(self,CpCourseManagerFrame.translations.folderDialogTitle,
											CpCourseManagerFrame.onClickRenameFolderDialog,folderIx)
end

function CpCourseManagerFrame:onClickRenameFolderDialog(text,clickOk,ix)
	if clickOk then 
		CpUtil.debugFormat(CpUtil.DBG_HUD,"onClickRenameFolderDialog(%d) - > %s",ix,text)
	end
end


function CpCourseManagerFrame:onClickMoveCourse()
	CpUtil.debugFormat(CpUtil.DBG_HUD,"onClickMoveCourse")
	if self.mode == CpCourseManagerFrame.MODE_FOLDER then 
		self.mode = CpCourseManagerFrame.MODE_MOVE_COURSE
	elseif self.mode == CpCourseManagerFrame.MODE_MOVE_COURSE then 
		self.mode = CpCourseManagerFrame.MODE_FOLDER
	end
	self:updateMenuButtons()
end

function CpCourseManagerFrame:showInputTextDialog(title,callback,ix)
	g_gui:showTextInputDialog({
		disableFilter = true,
		callback = callback,
		target = self,
		defaultText = "",
		imePrompt = g_i18n:getText(title),
		confirmText = g_i18n:getText("button_ok"),
		args = ix
	})
end
