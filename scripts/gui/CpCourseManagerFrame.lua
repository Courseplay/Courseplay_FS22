
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

	["deleteWarning"] = "CP_courseManager_deleteWarning",

	["changeMode"] = "CP_courseManager_change_mode"
}
CpCourseManagerFrame.mods = {
	course = 1,
	move = 2,
	delete = 3,
	rename = 4,
}
CpCourseManagerFrame.minMode = CpCourseManagerFrame.mods.course
CpCourseManagerFrame.maxMode = CpCourseManagerFrame.mods.rename

CpCourseManagerFrame.moveStates = {
	disabled = 0,
	active = 1
}

CpCourseManagerFrame.colors = {
	move = {0, 0, 0, 0.35},
	default = {0.3140, 0.8069, 1.0000, 0.02}
}

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

	self.modeButton = {
		profile = "buttonActivate",
		inputAction = InputAction.MENU_ACTIVATE,
		text = g_i18n:getText(CpCourseManagerFrame.translations.changeMode),
		callback = function ()
			CpCourseManagerFrame.onClickChangeMode(self)
		end
	}

	self.modes = {
		{
			{
				profile = "buttonActivate",
				inputAction = InputAction.MENU_ACTIVATE,
				text = g_i18n:getText(CpCourseManagerFrame.translations.clearCurrentCourse),
				callback = function ()
					CpCourseManagerFrame.onClickClearCurrentCourse(self)
				end,
				callbackDisabled = CpCourseManagerFrame.hasNoCurrentCourse
			},
			{
				profile = "buttonActivate",
				inputAction = InputAction.MENU_ACTIVATE,
				text = g_i18n:getText(CpCourseManagerFrame.translations.loadCourse),
				callback = function ()
					CpCourseManagerFrame.onClickLoadOrSaveCourse(self)
				end,
				callbackDisabled = CpCourseManagerFrame.loadSaveDisabled,
				callbackChangeText = CpCourseManagerFrame.getLoadSaveText
			},
		},
		{
			{
				profile = "buttonActivate",
				inputAction = InputAction.MENU_ACTIVATE,
				text = g_i18n:getText(CpCourseManagerFrame.translations.createFolder),
				callback = function ()
					CpCourseManagerFrame.onClickCreateFolder(self)
				end
			},
			{
				profile = "buttonActivate",
				inputAction = InputAction.MENU_ACTIVATE,
				text = g_i18n:getText(CpCourseManagerFrame.translations.moveCourse),
				callback = function ()
					CpCourseManagerFrame.onClickMoveCourse(self)
				end,
				callbackDisabled = CpCourseManagerFrame.moveButtonDisabled
			},
		},
		{
			{
				profile = "buttonActivate",
				inputAction = InputAction.MENU_ACTIVATE,
				text = g_i18n:getText(CpCourseManagerFrame.translations.deleteFolder),
				callback = function ()
					CpCourseManagerFrame.onClickDeleteFolder(self)
				end,
				callbackDisabled = CpCourseManagerFrame.hasNoFolders
			},
			{
				profile = "buttonActivate",
				inputAction = InputAction.MENU_ACTIVATE,
				text = g_i18n:getText(CpCourseManagerFrame.translations.deleteCourse),
				callback = function ()
					CpCourseManagerFrame.onClickDeleteCourse(self)
				end,
				callbackDisabled = CpCourseManagerFrame.hasNoCourses
			}
		},
		{
			{
				profile = "buttonActivate",
				inputAction = InputAction.MENU_ACTIVATE,
				text = g_i18n:getText(CpCourseManagerFrame.translations.renameFolder),
				callback = function ()
					CpCourseManagerFrame.onClickRenameFolder(self)
				end,
				callbackDisabled = CpCourseManagerFrame.hasNoFolders
			},
			{
				profile = "buttonActivate",
				inputAction = InputAction.MENU_ACTIVATE,
				text = g_i18n:getText(CpCourseManagerFrame.translations.renameCourse),
				callback = function ()
					CpCourseManagerFrame.onClickRenameCourse(self)
				end,
				callbackDisabled = CpCourseManagerFrame.hasNoCourses
			}
		}
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
	self.curMode = CpCourseManagerFrame.minMode
	self.moveState = CpCourseManagerFrame.moveStates.disabled
	local currentHotspot = g_currentMission.inGameMenu.pageAI.currentHotspot
	self.currentVehicle =  InGameMenuMapUtil.getHotspotVehicle(currentHotspot)
--	self:setSoundSuppressed(true)
--	FocusManager:setFocus(self.boxLayout)
--	self:setSoundSuppressed(false)
	CpCourseManagerFrame.updateLists(self)
	self.moveElementSelected = nil
	self.initialized = true
end
	
function CpCourseManagerFrame:onFrameClose()
	if self.moveElementSelected then
		self.moveElementSelected.element:setAlternating(false)
	end
	InGameMenuPricesFrame:superClass().onFrameClose(self)
	self.initialized = false
end

function CpCourseManagerFrame:updateLists()
	self.folderList:reloadData()
	self.courseList:reloadData()
	self:updateMenuButtons()
end

function CpCourseManagerFrame:getNumberOfItemsInSection(list, section)
	local numOfDirs = g_courseManager:getNumberOfDirectories()
	
	if list == self.folderList then
		return numOfDirs
	else
		if numOfDirs <=0 then 
			return 0
		end
		local folderIx = self.folderList:getSelectedIndexInSection()
		return g_courseManager:getNumberOfEntriesForDirectory(folderIx)
	end
end

function CpCourseManagerFrame:populateCellForItemInSection(list, section, index, cell)
	if list == self.folderList then
		local directory =  g_courseManager:getDirectoryByIndex(index)
		cell:getAttribute("icon"):setVisible(false)
		cell:getAttribute("title"):setText(directory:getName())

	else
		cell.alternateBackgroundColor =  CpCourseManagerFrame.colors.move
		local folderIx = self.folderList:getSelectedIndexInSection()
		local entry = g_courseManager:getEntryForDirectory(folderIx,index)
	
		cell:getAttribute("hotspot"):setVisible(false)

		cell:getAttribute("title"):setText(entry:getName())

		cell:getAttribute("price"):setVisible(false)
		cell:getAttribute("buyPrice"):setVisible(false)
		cell:getAttribute("priceTrend"):setVisible(false)

	end
end

function CpCourseManagerFrame:getLoadSaveText()
	return self.currentVehicle:hasCourse() and g_i18n:getText(CpCourseManagerFrame.translations.saveCourse) or g_i18n:getText(CpCourseManagerFrame.translations.loadCourse)
end

function CpCourseManagerFrame:hasNoCurrentCourse()
	return not self.currentVehicle:hasCourse()	
end

function CpCourseManagerFrame:moveButtonDisabled()
	local numOfDirs = g_courseManager:getNumberOfDirectories()
	return self.moveState == CpCourseManagerFrame.moveStates.active or numOfDirs <= 1
end

function CpCourseManagerFrame:hasNoCourses()
	local numOfDirs = g_courseManager:getNumberOfDirectories()
	if numOfDirs <= 0 then return true end
	local folderIx = self.folderList:getSelectedIndexInSection()
	return  g_courseManager:getNumberOfEntriesForDirectory(folderIx) <= 0
end

function CpCourseManagerFrame:hasNoFolders()
	local numOfDirs = g_courseManager:getNumberOfDirectories()
	return numOfDirs <= 0 
end

function CpCourseManagerFrame:loadSaveDisabled()
	return not self.currentVehicle:hasCourse() and CpCourseManagerFrame.hasNoCourses(self)
end

function CpCourseManagerFrame:onListSelectionChanged(list, section, index)
	if list == self.folderList then 
		self.courseList:reloadData()
		CpUtil.debugFormat(CpUtil.DBG_HUD,"folderList -> onListSelectionChanged")
		if self.moveElementSelected ~= nil then 
			local element = self.moveElementSelected
			CpUtil.debugFormat(CpUtil.DBG_HUD,"Moved course(%s) to folder(%d)",element.ix,index)
			self.moveElementSelected.element:setAlternating(false)
			self.moveState = CpCourseManagerFrame.moveStates.disabled
			g_courseManager:moveCourse(element.folderIx,element.ix,self.folderList:getSelectedIndexInSection())
			self.moveElementSelected = nil
			self.courseList:reloadData()
		end
	else
		CpUtil.debugFormat(CpUtil.DBG_HUD,"courseList -> onListSelectionChanged")
		if self.moveState == CpCourseManagerFrame.moveStates.active then
			if self.moveElementSelected then 
				self.moveElementSelected:setAlternating(false)
				self.moveElementSelected = nil
				self.moveState = CpCourseManagerFrame.moveStates.disabled
			else 
				local element = self.courseList:getSelectedElement()
				element:setAlternating(true)
				self.moveElementSelected = {element = element,ix = index,folderIx = self.folderList:getSelectedIndexInSection()}
				self.courseList:clearElementSelection()
			end
		end
	end
	self:updateMenuButtons()
end

function CpCourseManagerFrame:updateMenuButtons()
	local courseName = self.currentVehicle:getCurrentCourseName()
	local title = string.format(g_i18n:getText(CpCourseManagerFrame.translations.title),courseName)
	self.pageTitle:setText(title)

	self.menuButtonInfo = {
		{
			inputAction = InputAction.MENU_BACK
		}
	}
	table.insert(self.menuButtonInfo,self.modeButton)
	for i,data in pairs(self.modes[self.curMode]) do 
		if data.callbackChangeText then 
			data.text = data.callbackChangeText(self)
		end	
		if data.callbackDisabled == nil or not data.callbackDisabled(self) then
			table.insert(self.menuButtonInfo,data)
		end
	end	
	self:setMenuButtonInfoDirty()
end

function CpCourseManagerFrame:onClickLoadOrSaveCourse()
	local hasCourse = self.currentVehicle:hasCourse()
	CpUtil.debugFormat(CpUtil.DBG_HUD,"onClickLoadOrSaveCourse")
	local courseIx = self.courseList:getSelectedIndexInSection()
	local folderIx = self.folderList:getSelectedIndexInSection()
	if not hasCourse then -- only allow saving if it not already saved!
		self.currentVehicle:loadCourse(folderIx,courseIx)
		self:updateMenuButtons()
	else 
		CpCourseManagerFrame.showInputTextDialog(self,CpCourseManagerFrame.translations.courseDialogTitle,
												CpCourseManagerFrame.onClickSaveCourseDialog)
	end
end

function CpCourseManagerFrame:onClickSaveCourseDialog(text,clickOk)
	if clickOk then 
		CpUtil.debugFormat(CpUtil.DBG_HUD,"onClickSaveCourseDialog- > %s",text)
		local folderIx = self.folderList:getSelectedIndexInSection()
		self.currentVehicle:saveCourse(folderIx,text)
	end
end

function CpCourseManagerFrame:onClickClearCurrentCourse()
	CpUtil.debugFormat(CpUtil.DBG_HUD,"onClickClearCurrentCourse")
	local hasCourse,isSaved = self.currentVehicle:hasCourse()
	if hasCourse then 
		self.currentVehicle:resetCourses()
	end
	CpCourseManagerFrame.updateLists(self)
end

function CpCourseManagerFrame:onClickDeleteCourse()
	CpUtil.debugFormat(CpUtil.DBG_HUD,"onClickDeleteCourse")
	local folderIx = self.folderList:getSelectedIndexInSection()
	local courseIx = self.courseList:getSelectedIndexInSection()
	g_courseManager:deleteEntityInDirectory(folderIx,courseIx)
	CpCourseManagerFrame.updateLists(self)
end

function CpCourseManagerFrame:onClickRenameCourse()
	CpUtil.debugFormat(CpUtil.DBG_HUD,"onClickRenameCourse")
	CpCourseManagerFrame.showInputTextDialog(self,CpCourseManagerFrame.translations.courseDialogTitle,
											CpCourseManagerFrame.onClickRenameCourseDialog,courseIx)
end

function CpCourseManagerFrame:onClickRenameCourseDialog(text,clickOk)
	if clickOk then 
		CpUtil.debugFormat(CpUtil.DBG_HUD,"onClickRenameCourseDialog - > %s",text)
		local folderIx = self.folderList:getSelectedIndexInSection()
		local courseIx = self.courseList:getSelectedIndexInSection()
		g_courseManager:renameCourse(folderIx,courseIx,text)
		self.courseList:reloadData()
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
	local folderIx = self.folderList:getSelectedIndexInSection()
	g_courseManager:deleteDirectory(folderIx)
	CpCourseManagerFrame.updateLists(self)
end

function CpCourseManagerFrame:onClickRenameFolder()
	CpUtil.debugFormat(CpUtil.DBG_HUD,"onClickRenameFolder")
	CpCourseManagerFrame.showInputTextDialog(self,CpCourseManagerFrame.translations.folderDialogTitle,
											CpCourseManagerFrame.onClickRenameFolderDialog,folderIx)
end

function CpCourseManagerFrame:onClickRenameFolderDialog(text,clickOk)
	if clickOk then 
		CpUtil.debugFormat(CpUtil.DBG_HUD,"onClickRenameFolderDialog - > %s",text)
		local folderIx = self.folderList:getSelectedIndexInSection()
		g_courseManager:renameFolder(folderIx,text)
		CpCourseManagerFrame.updateLists(self)
	end
end


function CpCourseManagerFrame:onClickMoveCourse()
	CpUtil.debugFormat(CpUtil.DBG_HUD,"onClickMoveCourse")
	self.moveState = self.moveState == CpCourseManagerFrame.moveStates.disabled and CpCourseManagerFrame.moveStates.active or CpCourseManagerFrame.moveStates.disabled
	self:updateMenuButtons()
end

function CpCourseManagerFrame:onClickChangeMode()
	self.curMode = self.curMode + 1
	if self.curMode > CpCourseManagerFrame.maxMode then 
		self.curMode = CpCourseManagerFrame.minMode
	end
	CpCourseManagerFrame.updateLists(self)
end

function CpCourseManagerFrame:showInputTextDialog(title,callback,ix)
	g_gui:showTextInputDialog({
		disableFilter = true,
		callback = function (text,clickOk,args)
			callback(text,clickOk,args)
			CpCourseManagerFrame.updateLists(self)
		end,
		target = self,
		defaultText = "",
		imePrompt = g_i18n:getText(title),
		confirmText = g_i18n:getText("button_ok"),
		args = ix
	})
end
