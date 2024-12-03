--[[
	This frame is a page for all global settings in the in game menu.
	All the layout, gui elements are cloned from the general settings page of the in game menu.
]]--

CpCourseGeneratorFrame = {
	CATEGRORIES = {
		BASIC_SETTINGS = 1,
		IN_GAME_MAP = 2,
	},
	INPUT_CONTEXT_NAME = "CP_COURSE_GENERATOR_MENU",
	CATEGRORY_TEXTS = {
		"CP_vehicle_courseGeneratorSetting_subTitle_basic",
		"CP_ingameMenu_map_title",
	},
	CLEAR_INPUT_ACTIONS = {
		InputAction.MENU_ACTIVATE,
		InputAction.MENU_CANCEL,
		InputAction.MENU_EXTRA_1,
		InputAction.MENU_EXTRA_2,
		InputAction.SWITCH_VEHICLE,
		InputAction.SWITCH_VEHICLE_BACK,
		InputAction.CAMERA_ZOOM_IN,
		InputAction.CAMERA_ZOOM_OUT
	},
	CLEAR_CLOSE_INPUT_ACTIONS = {
		InputAction.SWITCH_VEHICLE,
		InputAction.SWITCH_VEHICLE_BACK,
		InputAction.CAMERA_ZOOM_IN,
		InputAction.CAMERA_ZOOM_OUT
	},
	CONTEXT_ACTIONS = {
		ENTER_VEHICLE 	= 1,
		CREATE_JOB		= 2,
		START_JOB		= 3,
		STOP_JOB		= 4,
		GENERATE_COURSE = 5
	},
	AI_MODE_OVERVIEW = 1,
	AI_MODE_CREATE = 2,
	AI_MODE_WORKER_LIST = 3,
	MAP_SELECTOR_HOTSPOT = 1,
	MAP_SELECTOR_CREATE_JOB = 2,
	MAP_SELECTOR_ACTIVE_JOBS = 3,

	-- POSITION_UVS = GuiUtils.getUVs({
	-- 	760,
	-- 	4,
	-- 	100,
	-- 	100
	-- }, AIPlaceableMarkerHotspot.FILE_RESOLUTION)
}
CpCourseGeneratorFrame.NUM_CATEGORIES = #CpCourseGeneratorFrame.CATEGRORY_TEXTS

local CpCourseGeneratorFrame_mt = Class(CpCourseGeneratorFrame, TabbedMenuFrameElement)

function CpCourseGeneratorFrame.new(target, custom_mt)
	local self = TabbedMenuFrameElement.new(target, custom_mt or CpCourseGeneratorFrame_mt)
	self.subCategoryPages = {}
	self.subCategoryTabs = {}
	self.contextActions = {}
	self.contextActionMapping = {}
	self.hasFullScreenMap = true
	self.dataTables = {}
	self.hotspotModeActive = false
	self.currentHotspot = nil
	self.staticUIDeadzone = {0, 0, 0, 0}
	self.selectedVehicle = nil
	self.jobTypeInstances = {}
	self.currentJobTypes = {}
	self.currentJob = nil
	self.currentJobElements = {}
	self.statusMessages = {}
	self.mode = self.AI_MODE_OVERVIEW
	self.lastMousePosX = 0
	self.lastMousePosY = 0

	self.lastInputHelpMode = 0
	self.hotspotFilterState = {}
	self.isInputContextActive = false
	self.driveToAiTargetMapHotspot = AITargetHotspot.new()
	self.fieldSiloAiTargetMapHotspot = AITargetHotspot.new()
	-- self.fieldSiloAiTargetMapHotspot.icon:setUVs(POSITION_UVS) --- TODO_25
	self.unloadAiTargetMapHotspot = AITargetHotspot.new()
	self.loadAiTargetMapHotspot = AITargetHotspot.new()

	self.aiTargetMapHotspot = self.driveToAiTargetMapHotspot

	self.mapSelectorTexts = {
		g_i18n:getText("ui_mapOverviewHotspots"),
		g_i18n:getText("button_createJob"),
		g_i18n:getText("ui_activeAIJobs")}

	return self
end

function CpCourseGeneratorFrame.setupGui()
	local courseGeneratorFrame = CpCourseGeneratorFrame.new()
	g_gui:loadGui(Utils.getFilename("config/gui/pages/CourseGeneratorFrame.xml", Courseplay.BASE_DIRECTORY),
	 			 "CpCourseGeneratorFrame", courseGeneratorFrame, true)
end

function CpCourseGeneratorFrame.createFromExistingGui(gui, guiName)
	local newGui = CpCourseGeneratorFrame.new(nil, nil)

	g_gui.frames[gui.name].target:delete()
	g_gui.frames[gui.name]:delete()
	g_gui:loadGui(gui.xmlFilename, guiName, newGui, true)

	return newGui
end

function CpCourseGeneratorFrame:setInGameMap(ingameMap, terrainSize, hud)
	self.ingameMapBase = ingameMap
	self.ingameMap:setIngameMap(ingameMap)
	self.ingameMap:setTerrainSize(terrainSize)
	self.hud = hud
end

function CpCourseGeneratorFrame:initialize(menu)
	self.onClickBackCallback = menu.clickBackCallback
	self:initializeContextActions()

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

	self.createMultiOptionTemplate:unlinkElement()
	FocusManager:removeElement(self.createMultiOptionTemplate)
	self.createTextTemplate:unlinkElement()
	FocusManager:removeElement(self.createTextTemplate)
	self.createTitleTemplate:unlinkElement()
	FocusManager:removeElement(self.createTitleTemplate)
	self.createPositionTemplate:unlinkElement()
	FocusManager:removeElement(self.createPositionTemplate)
	self.createPositionRotationTemplate:unlinkElement()
	FocusManager:removeElement(self.createPositionRotationTemplate)

	for key = 1, CpCourseGeneratorFrame.NUM_CATEGORIES do 
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
		if key == 2 then
			self.subCategoryPages[key] = self.containerMap
		else
			self.subCategoryPages[key] = self.containerPrefab:clone(self)
			self.subCategoryPages[key]:getDescendantByName("layout").scrollDirection = "vertical"
			FocusManager:loadElementFromCustomValues(self.subCategoryPages[key])
		end
	end
	self:resetUIDeadzones()
	self.mapOverviewSelector:setTexts(self.mapSelectorTexts)
	self.mapOverviewSelector:setState(1, true)

	self.hotspotFilterCategories = InGameMenuMapFrame.HOTSPOT_FILTER_CATEGORIES
	self.hotspotStateFilter = {}
	for i, data in ipairs(self.hotspotFilterCategories) do 
		self.hotspotStateFilter[i] = {}
		for j, _ in ipairs(data) do 
			self.hotspotStateFilter[i][j] = false
		end

	end

	self.currentContextBox = self.contextBox 
	self.currentHotspot = nil
end

function CpCourseGeneratorFrame:onFrameOpen()
	local vehicle = CpUtil.getCurrentVehicle()
	if not vehicle then 
		return
	end
	local settings = vehicle:getCourseGeneratorSettings()
	local settingsBySubTitle, pageTitle = CpCourseGeneratorSettings.getSettingSetup()
	local title = string.format(g_i18n:getText(pageTitle), vehicle:getName())
	self.categoryHeaderText:setText(title)

	local layout = self.subCategoryPages[1]:getDescendantByName("layout")
	for i = #layout.elements, 1, -1 do
		layout.elements[i]:delete()
	end
	CpSettingsUtil.generateAndBindGuiElementsToSettings(settingsBySubTitle,
		layout, self.multiTextPrefab, self.booleanPrefab, 
		self.sectionHeaderPrefab, settings)
	CpSettingsUtil.updateGuiElementsBoundToSettings(layout, vehicle)

	self:updateSubCategoryPages(self.CATEGRORIES.BASIC_SETTINGS)
	FocusManager:setFocus(self.subCategoryPages[self.CATEGRORIES.BASIC_SETTINGS]:getDescendantByName("layout"))
	
	
	-- g_messageCenter:subscribe(MessageType.AI_VEHICLE_STATE_CHANGE, self.onAIVehicleStateChanged, self)
	self.activeWorkerList:reloadData()
	g_messageCenter:subscribe(MessageType.AI_JOB_STARTED, function(self)
		self.activeWorkerList:reloadData()
	end, self)
	-- g_messageCenter:subscribe(MessageType.AI_JOB_STOPPED, function()
		
	-- end, self)
	g_messageCenter:subscribe(MessageType.AI_JOB_REMOVED, function()
		self.activeWorkerList:reloadData()
	end, self)
	-- g_messageCenter:subscribe(MessageType.AI_TASK_SKIPPED, self.onAITaskSkipped, self)
	local hotspotValue = g_gameSettings:getValue(GameSettings.SETTING.INGAME_MAP_HOTSPOT_FILTER)
	for i, hotspotCategory in pairs(self.hotspotFilterCategories[1]) do 
		local isBitSet = Utils.isBitSet(hotspotValue, hotspotCategory.id)
		self.hotspotStateFilter[1][i] = isBitSet
		self.ingameMapBase:setDefaultFilterValue(hotspotCategory.id, isBitSet)
	end
	for i, hotspotCategory in pairs(self.hotspotFilterCategories[2]) do 
		local isBitSet = Utils.isBitSet(hotspotValue, hotspotCategory.id)
		self.hotspotStateFilter[2][i] = isBitSet
		self.ingameMapBase:setDefaultFilterValue(hotspotCategory.id, isBitSet)
	end
	local allDeactivated = true
	for _, filter in pairs(self.hotspotStateFilter) do 
		for i, state in pairs(filter) do
			allDeactivated = allDeactivated and not state
		end
	end
	if allDeactivated then 
		self.buttonDeselectAllText:setText(g_i18n:getText(InGameMenuMapFrame.L10N_SYMBOL.SELECT_ALL))
	else 
		self.buttonDeselectAllText:setText(g_i18n:getText(InGameMenuMapFrame.L10N_SYMBOL.DESELECT_ALL))
	end
	self.filterList:reloadData()
	self.ingameMapBase:restoreDefaultFilter()

	self:generateJobTypes()


	self.mode = self.AI_MODE_OVERVIEW
	self.currentJob = nil
	self.currentJobVehicle = nil
	self.currentHotspot = nil
	self:setMapSelectionItem(nil)
	self:setJobMenuVisible(false)
end

function CpCourseGeneratorFrame:saveHotspotFilter()
	local hotspotValue = 0
	for i, state in pairs(self.hotspotStateFilter[1]) do 
		if state then
			hotspotValue = Utils.setBit(hotspotValue, i)
		end
	end
	for i, state in pairs(self.hotspotStateFilter[2]) do 
		if state then
			hotspotValue = Utils.setBit(hotspotValue, i + #self.hotspotStateFilter[1])
		end
	end
	g_gameSettings:setValue(GameSettings.SETTING.INGAME_MAP_HOTSPOT_FILTER, hotspotValue, true)
	local allDeactivated = true
	for _, filter in pairs(self.hotspotStateFilter) do 
		for i, state in pairs(filter) do
			allDeactivated = allDeactivated and not state
		end
	end
	if allDeactivated then 
		self.buttonDeselectAllText:setText(g_i18n:getText(InGameMenuMapFrame.L10N_SYMBOL.SELECT_ALL))
	else 
		self.buttonDeselectAllText:setText(g_i18n:getText(InGameMenuMapFrame.L10N_SYMBOL.DESELECT_ALL))
	end
end

function CpCourseGeneratorFrame:onFrameClose()
	self:closeMap()
	g_messageCenter:unsubscribeAll(self)
	self.jobTypeInstances = {}
	g_currentMission:removeMapHotspot(self.driveToAiTargetMapHotspot)
	g_currentMission:removeMapHotspot(self.fieldSiloAiTargetMapHotspot)
	g_currentMission:removeMapHotspot(self.unloadAiTargetMapHotspot)
	g_currentMission:removeMapHotspot(self.loadAiTargetMapHotspot)

	self.ingameMapBase:restoreDefaultFilter()
	-- self.isOpen = false
	self.mode = self.AI_MODE_OVERVIEW
	self:setJobMenuVisible(false)
	self:setMapSelectionItem(nil)
end

function CpCourseGeneratorFrame:requestClose()
	if self.mode == self.AI_MODE_CREATE then 
		if self:getIsPicking() then
			self:executePickingCallback(false)
			self:updateContextActions()
			return false
		end 
		self.mode = self.AI_MODE_OVERVIEW
		self:setJobMenuVisible(false)
		FocusManager:setFocus(self.activeWorkerList)
		self:setMapSelectionItem(nil)
		return false
	elseif self.currentHotspot then 
		self:setMapSelectionItem(nil)
		return false
	end
	return true
end

function CpCourseGeneratorFrame:onClickCpMultiTextOption(_, guiElement)
	local vehicle = CpUtil.getCurrentVehicle()
	local layout = self.subCategoryPages[self.subCategoryPaging:getState()]:getDescendantByName("layout")
	if layout then 
		CpSettingsUtil.updateGuiElementsBoundToSettings(layout, vehicle)
	end
end

function CpCourseGeneratorFrame:isMapVisible()
	return self.ingameMap:getIsVisible()
end

function CpCourseGeneratorFrame:updateSubCategoryPages(state)
	for i, _ in ipairs(self.subCategoryPages) do
		self.subCategoryPages[i]:setVisible(false)
		self.subCategoryTabs[i]:setSelected(false)
	end
	self.subCategoryPages[state]:setVisible(true)
	self.subCategoryTabs[state]:setSelected(true)
	local layout = self.subCategoryPages[state]:getDescendantByName("layout")
	if layout then
		self.settingsSliderBox:setVisible(true)
		self.ingameMap:setVisible(false)
		layout:invalidateLayout()
		self.settingsSlider:setDataElement(layout)
		self:closeMap()
	else
		self.settingsSliderBox:setVisible(false)
		self.ingameMap:setVisible(true)
		self:openMap()
	end 
end

function CpCourseGeneratorFrame:delete()
	g_messageCenter:unsubscribeAll(self)
	self.booleanPrefab:delete()
	self.multiTextPrefab:delete()
	self.sectionHeaderPrefab:delete()
	self.selectorPrefab:delete()
	self.containerPrefab:delete()
	self.driveToAiTargetMapHotspot:delete()
	self.fieldSiloAiTargetMapHotspot:delete()
	self.unloadAiTargetMapHotspot:delete()
	self.loadAiTargetMapHotspot:delete()
	CpCourseGeneratorFrame:superClass().delete(self)
end
-------------------------------
-- InGameMap
-------------------------------

function CpCourseGeneratorFrame:onDrawPostIngameMapHotspots()
	if self.currentContextBox ~= nil then
		InGameMenuMapUtil.updateContextBoxPosition(self.currentContextBox, self.currentHotspot)
	end
end

function CpCourseGeneratorFrame:onDrawPostIngameMap()
	
end

function CpCourseGeneratorFrame:onClickMap()
	if self.isPickingLocation then 
		
		return
	end
	if self.isPickingRotation then 

		return
	end
	self:setMapSelectionItem(nil)
end

function CpCourseGeneratorFrame:onClickHotspot(element, hotspot)
	if self.isPickingLocation then 
		--- g_inGameMenu.pageMapOverview.executePickingCallback(self, true, hotspot.worldX, hotspot.worldZ)
		return 
	end 
	if self.isPickingRotation then 
		--- g_inGameMenu.pageMapOverview.executePickingCallback(self, true, worldX, worldZ)
		--- g_inGameMenu.pageMapOverview.executePickingCallback(self, true, math.atan2(hotspot.worldX - self.pickingRotationOrigin[0], hotspot.worldZ - self.pickingRotationOrigin[1]))
		return
	end
	self:setMapSelectionItem(hotspot)
	-- self:refreshContextInput()
end

function CpCourseGeneratorFrame:showMapHotspot(self, hotspot) 
	self:onClickHotspot(nil, hotspot)
	self.ingameMap:panToHotspot(hotspot)
end

function CpCourseGeneratorFrame:onClickMapOverviewSelector(state)
	self.filterListContainer:setVisible(false)
	self.createJobContainer:setVisible(false)
	self.workerListContainer:setVisible(false)
	for i = 1, #self.mapSelectorTexts do
		self.subCategoryDotBox.elements[i]:setSelected(false)
	end
	self.subCategoryDotBox.elements[state]:setSelected(true)
	if state == self.MAP_SELECTOR_HOTSPOT then
		self.filterListContainer:setVisible(true)
	elseif state == self.MAP_SELECTOR_CREATE_JOB then
		self.createJobContainer:setVisible(true)
		-- self.subCategoryDotBox:invalidateLayout()
	elseif state == self.MAP_SELECTOR_ACTIVE_JOBS then
		self.workerListContainer:setVisible(true)
	end
end

function CpCourseGeneratorFrame:onClickDeselectAll()
	local allDeactivated = true
	for _, filter in pairs(self.hotspotStateFilter) do 
		for i, state in pairs(filter) do
			allDeactivated = allDeactivated and not state
		end
	end
	for i, filter in pairs(self.hotspotStateFilter) do 
		for j, state in pairs(filter) do
			self.ingameMapBase:setDefaultFilterValue(self.hotspotFilterCategories[i][j].id, allDeactivated)
			self.hotspotStateFilter[i][j] = allDeactivated
		end
	end
	self.ingameMapBase:restoreDefaultFilter()
	self:saveHotspotFilter()
	self.filterList:reloadData()
end

function CpCourseGeneratorFrame:onJobTypeChanged()
	
end

function CpCourseGeneratorFrame:onClickMultiTextOptionParameter()
	
end

function CpCourseGeneratorFrame:onClickPositionParameter(element)
	local parameter = element.aiParameter

	g_inGameMenu.pageMapOverview.startPickPosition(self, parameter, function (success, x, z)
		if success then
			element:setText(parameter:getString())
		end
	end)
end

function CpCourseGeneratorFrame:onClickPositionRotationParameter(element)
	local parameter = element.aiParameter

	g_inGameMenu.pageMapOverview.startPickPositionAndRotation(self, parameter, function (success, x, z, angle)
		if success then
			element:setText(parameter:getString())
		end
	end)
end

function CpCourseGeneratorFrame:getIsPicking()
	return self.isPickingRotation or self.isPickingLocation
end

function CpCourseGeneratorFrame:validateParameters()
	
end

function CpCourseGeneratorFrame:updateParameterValueTexts()
	
end

function CpCourseGeneratorFrame:showActionMessage()
	
end

function CpCourseGeneratorFrame:onStartCancelJob()
	
end

function CpCourseGeneratorFrame:getNumberOfSections(list)
	if list == self.filterList then
		return 2
	end
	return 1	
end

function CpCourseGeneratorFrame:getTitleForSectionHeader(list, section)
	if list == self.filterList then 
		if section == 1 then 
			return g_i18n:getText("ui_mapHotspotFilter_vehicles")
		end 
		return g_i18n:getText("construction_category_buildings")
	end
end

function CpCourseGeneratorFrame:getNumberOfItemsInSection(list, section) 
	if list == self.filterList then 
		return #self.hotspotFilterCategories[section]
	end
	if list == self.contextButtonList then 
		if self.mode == self.AI_MODE_CREATE then  
			return 0
		end
		self.contextActionMapping = {}
		for index, action in pairs(self.contextActions) do 
			if action.isActive then 
				table.insert(self.contextActionMapping, index)
			end
		end
		return #self.contextActionMapping
	end
	if list == self.activeWorkerList then 
		local farmId = 1
		if g_localPlayer then 
			farmId = g_localPlayer.farmId
		end
		local count = 0
		for _, job in ipairs(g_currentMission.aiSystem:getActiveJobs()) do 
			if job.startedFarmId == farmId then 
				count = count + 1
			end
		end
		self.activeWorkerListEmpty:setVisible(count == 0)
		return count
	end
	return 0
end

function CpCourseGeneratorFrame:populateCellForItemInSection(list, section, index, cell)
	if list == self.filterList then 
		local status = self.hotspotFilterCategories[section][index]
		cell:getAttribute("name"):setText(g_i18n:getText(status.name))
		cell:getAttribute("icon"):setImageSlice(nil, status.sliceId)
		cell:getAttribute("icon").getIsSelected = function ()
			return true
		end
		cell:getAttribute("iconBg").getIsSelected = function ()
			return self.hotspotStateFilter[section][index]
		end
		g_inGameMenu.pageMapOverview.assignItemColors(self, cell:getAttribute("iconBg"), status.color, cell:getAttribute("colorTemplate")) 
	elseif list == self.contextButtonList then 
		local buttonInfo = self.contextActions[self.contextActionMapping[index]]
		cell:getAttribute("text"):setText(buttonInfo.text)
		cell.onClickCallback = buttonInfo.callback
	elseif list == self.activeWorkerList then 
		local count = 0
		local currentJob = nil
		local farmId = 1
		if g_localPlayer then
			farmId = g_localPlayer.farmId
		end
		for _, job in ipairs(g_currentMission.aiSystem:getActiveJobs()) do 
			if job.startedFarmId == farmId then
				count = count + 1	
				currentJob = job
				break
			end
		end
		if currentJob then 
			cell:getAttribute("text"):setText(currentJob:getDescription())
			cell:getAttribute("title"):setText(currentJob:getTitle())
			cell:getAttribute("helper"):setText(currentJob:getHelperName())
		end
	end
end

function CpCourseGeneratorFrame:onClickList(list, section, index, listElement)
	if list == self.filterList then 
		self.ingameMapBase:toggleDefaultFilter(self.hotspotFilterCategories[section][index].id)
		self.hotspotStateFilter[section][index] = not self.hotspotStateFilter[section][index]
		self.ingameMapBase:restoreDefaultFilter()
		self:saveHotspotFilter()
	elseif list == self.activeWorkerList then
		local job = g_currentMission.aiSystem:getJobByIndex(index)
		if job ~= nil and not job.vehicleParameter then
			local vehicle = job.vehicleParameter:getVehicle()
			if vehicle ~= nil then
				local hotspot = vehicle:getMapHotspot()
				self:showMapHotspot(hotspot)
			end
		end
	elseif list == self.contextButtonList then
		listElement.onClickCallback(self)	
	end
end

function CpCourseGeneratorFrame:onListSelectionChanged(list, section, index)
	
end

function CpCourseGeneratorFrame:updateInputGlyphs()
	local moveActions, moveText = nil

	if self.lastInputHelpMode == GS_INPUT_HELP_MODE_GAMEPAD then
		moveText = self.moveCursorText
		moveActions = {
			InputAction.AXIS_MAP_SCROLL_LEFT_RIGHT,
			InputAction.AXIS_MAP_SCROLL_UP_DOWN
		}
	else
		moveText = self.panMapText
		moveActions = {
			InputAction.AXIS_LOOK_LEFTRIGHT_DRAG,
			InputAction.AXIS_LOOK_UPDOWN_DRAG
		}
	end

	self.mapMoveGlyph:setActions(moveActions, nil, nil, moveActions)
	self.mapZoomGlyph:setActions({
		InputAction.AXIS_MAP_ZOOM_IN,
		InputAction.AXIS_MAP_ZOOM_OUT
	}, nil, nil, self)
	self.mapMoveGlyphText:setText(moveText)
	self.mapZoomGlyphText:setText(self.zoomText)

end

-- Lines 992-1005
function CpCourseGeneratorFrame:registerInput()
	self:unregisterInput()
	-- g_inputBinding:registerActionEvent(InputAction.MENU_ACTIVATE, self, self.onStartCancelJob, false, true, false, true)
	-- g_inputBinding:registerActionEvent(InputAction.MENU_CANCEL, self, self.onStartGoToJob, false, true, false, true)
	-- g_inputBinding:registerActionEvent(InputAction.MENU_ACCEPT, self, self.onCreateJob, false, true, false, true)
	-- g_inputBinding:registerActionEvent(InputAction.MENU_EXTRA_1, self, self.onSkipJobTask, false, true, false, true)

	-- local _, switchVehicleId = g_inputBinding:registerActionEvent(InputAction.SWITCH_VEHICLE, self, self.onSwitchVehicle, false, true, false, true, 1)
	-- self.eventIdSwitchVehicle = switchVehicleId
	-- local _, switchVehicleBackId = g_inputBinding:registerActionEvent(InputAction.SWITCH_VEHICLE_BACK, self, self.onSwitchVehicle, false, true, false, true, -1)
	-- self.eventIdSwitchVehicleBack = switchVehicleBackId
end

-- Lines 1008-1017
function CpCourseGeneratorFrame:unregisterInput(customOnly)
	local list = customOnly and self.CLEAR_CLOSE_INPUT_ACTIONS or self.CLEAR_INPUT_ACTIONS

	for _, actionName in pairs(list) do
		g_inputBinding:removeActionEventsByActionName(actionName)
	end
end

function CpCourseGeneratorFrame:generateJobTypes()
	for name, jobType in pairs(AIJobType) do
		if string.match(name, "CP$") then
			self.jobTypeInstances[jobType] = g_currentMission.aiJobTypeManager:createJob(jobType)
		end
	end
end


function CpCourseGeneratorFrame:initializeContextActions()
	self.contextActions = {
		[self.CONTEXT_ACTIONS.ENTER_VEHICLE] = {
			text = "button_enterVehicle",
			callback = function()
				if self.currentHotspot then 
					local vehicle = self.currentHotspot:getVehicle()
					if vehicle then 
						if vehicle.getIsEnterableFromMenu ~= nil and vehicle:getIsEnterableFromMenu() then
							self:onClickBackCallback()
							g_localPlayer:requestToEnterVehicle(vehicle)
						end
					end
				end
			end,
			isActive = false
		},
		[self.CONTEXT_ACTIONS.CREATE_JOB] = {
			text = "button_createJob",
			callback = function()
				if self.currentHotspot then 
					local vehicle = self.currentHotspot:getVehicle()
					if vehicle then 
						local currentJobTypesTexts = {}
						for index, job in pairs(self.jobTypeInstances) do 
							if job:getIsAvailableForVehicle(vehicle, true) then 
								table.insert(self.currentJobTypes, index)
								table.insert(currentJobTypesTexts, g_currentMission.aiJobTypeManager:getJobTypeByIndex(index).title)
							end
						end
						self.jobTypeElement:setTexts(currentJobTypesTexts)
						self.jobTypeElement:setState(1)
						self.mode = self.AI_MODE_CREATE
						self.currentJobVehicle = vehicle
						self.currentJob = nil
						self:setJobMenuVisible(true)
						FocusManager:setFocus(self.jobTypeElement)
						self:setActiveJobTypeSelection(self.currentJobTypes[1])
					end
				end
			end,
			isActive = false
		},
		[self.CONTEXT_ACTIONS.START_JOB] = {
			text = "button_startJob",
			callback = function()
				if self.currentHotspot then 
					local vehicle = InGameMenuMapUtil.getHotspotVehicle(self.currentHotspot)
					if vehicle then 
						if vehicle.getIsEnterableFromMenu ~= nil and not vehicle:getIsEnterableFromMenu() then
							self:onClickBackCallback()
							g_localPlayer:requestToEnterVehicle(vehicle)
						end
					end
				end
			end,
			isActive = false
		},
		[self.CONTEXT_ACTIONS.STOP_JOB] = {
			text = "button_cancelJob",
			callback = function()
				if self.currentHotspot then 
					local vehicle = InGameMenuMapUtil.getHotspotVehicle(self.currentHotspot)
					if vehicle and vehicle:getIsAIActive() then 
						vehicle:stopCurrentAIJob()
					end
				end
			end,
			isActive = false
		},
		[self.CONTEXT_ACTIONS.GENERATE_COURSE] = {
			text = "CP_ai_page_generate_course",
			callback = function()
				if self.currentHotspot then 
					local vehicle = InGameMenuMapUtil.getHotspotVehicle(self.currentHotspot)
					if vehicle then 
						if vehicle.getIsEnterableFromMenu ~= nil and not vehicle:getIsEnterableFromMenu() then
							self:onClickBackCallback()
							g_localPlayer:requestToEnterVehicle(vehicle)
						end
					end
				end
			end,
			isActive = false
		}
	}
end

function CpCourseGeneratorFrame:updateContextActions()
	local vehicle = self.currentHotspot and self.currentHotspot:getVehicle()
	self.contextActions[self.CONTEXT_ACTIONS.ENTER_VEHICLE].isActive = vehicle and vehicle:getIsEnterableFromMenu()
	local canCreateJob = false
	if not canCreateJob and not self.currentJobVehicle then
		for _, job in pairs(self.jobTypeInstances) do 
			if job:getIsAvailableForVehicle(vehicle, true) then 
				canCreateJob = true
			end
		end
	end
	self.contextActions[self.CONTEXT_ACTIONS.CREATE_JOB].isActive = canCreateJob 
	self.contextActions[self.CONTEXT_ACTIONS.START_JOB].isActive = false
	self.contextActions[self.CONTEXT_ACTIONS.STOP_JOB].isActive = false
	self.contextActions[self.CONTEXT_ACTIONS.GENERATE_COURSE].isActive = false 


	self.contextButtonList:reloadData()
end

function CpCourseGeneratorFrame:toggleMapInput(isActive)
	if self.isInputContextActive ~= isActive then
		self.isInputContextActive = isActive

		self:toggleCustomInputContext(isActive, self.INPUT_CONTEXT_NAME)

		if not isActive then
			self:registerInput()
		else
			self:unregisterInput(true)
		end
	end
end

function CpCourseGeneratorFrame:setMapSelectionItem(hotspot)
	if hotspot ~= nil then
		
		local x, _ = hotspot:getWorldPosition()
		if x == nil then
			hotspot = nil
		end
	end
	self.ingameMapBase:setSelectedHotspot(nil)
	self.selectedFarmland = nil

	g_currentMission:removeMapHotspot(self.driveToAiTargetMapHotspot)
	g_currentMission:removeMapHotspot(self.fieldSiloAiTargetMapHotspot)
	g_currentMission:removeMapHotspot(self.unloadAiTargetMapHotspot)
	g_currentMission:removeMapHotspot(self.loadAiTargetMapHotspot)

	local playerName = nil
	local farmId = 1
	local name = nil
	local imageFilename = nil
	local uvs = Overlay.DEFAULT_UVS

	local showContextBox = false
	self.currentHotspot = nil
	if hotspot ~= nil then 
		local vehicle = InGameMenuMapUtil.getHotspotVehicle(hotspot)
		if vehicle ~= nil and not vehicle.spec_rideable then
			playerName = nil
			farmId = vehicle:getOwnerFarmId()
			name = vehicle:getName()
			imageFilename = vehicle:getImageFilename()
			uvs = Overlay.DEFAULT_UVS
			self.currentHotspot = hotspot
			if hotspot:isa(PlayerHotspot) then
				local player = hotspot:getPlayer()
				if player then 
					playerName = player:getNickname()
					farmId = player:getFarmId()
				end
			end
			if vehicle.getJob ~= nil then
				local job = vehicle:getJob()					
				if job ~= nil then
					-- TODO_25
				end
			end
			showContextBox = true
		end
	end
	if showContextBox then
		InGameMenuMapUtil.showContextBox(self.contextBox, hotspot, name, imageFilename, uvs, farmId, playerName, false, true, false)
		self:updateContextActions()
	else
		InGameMenuMapUtil.hideContextBox(self.contextBox)
	end
end

function CpCourseGeneratorFrame:setAIVehicle(vehicle)
	local hotspot = vehicle:getMapHotspot()
	self:setMapSelectionItem(hotspot)
	self.ingameMap:panToHotspot(hotspot)
	-- self:onCreateJob()
	self.createJobEmptyText:setVisible(false)
end

function CpCourseGeneratorFrame:resetUIDeadzones()
	self.ingameMap:clearCursorDeadzones()
	self.ingameMap:addCursorDeadzone(self.rightBackground.absPosition[1], self.rightBackground.absPosition[2], self.rightBackground.size[1], self.rightBackground.size[2])
	self.ingameMap:addCursorDeadzone(self.topBackground.absPosition[1], self.topBackground.absPosition[2], self.topBackground.size[1], self.topBackground.size[2])
	self.ingameMap:addCursorDeadzone(self.bottomBackground.absPosition[1], self.bottomBackground.absPosition[2], self.bottomBackground.size[1], self.bottomBackground.size[2])
	self.ingameMap:addCursorDeadzone(0, 0, self.leftBox.absPosition[1] + self.leftBox.absSize[1], 1)
end

function CpCourseGeneratorFrame:setJobMenuVisible(isVisible)
	-- g_inputBinding:setActionEventActive(self.eventIdSwitchVehicle, not isVisible)
	-- g_inputBinding:setActionEventActive(self.eventIdSwitchVehicleBack, not isVisible)
	-- g_inputBinding:setContextEventsActive(InGameMenuAIFrame.INPUT_CONTEXT_NAME, InputAction.MENU_AXIS_LEFT_RIGHT, isVisible)
	self.errorMessage:setText("")
	self.actionMessage:setText("")
	self.createJobEmptyText:setVisible(not isVisible)
	self.jobTypeElement:setVisible(isVisible)
	self.jobMenuLayout:setVisible(isVisible)
	if not isVisible then
		self:setMapSelectionItem(self.currentHotspot)		
		FocusManager:setFocus(self.mapOverviewSelector)
		self.mapOverviewSelector:setState(self.MAP_SELECTOR_ACTIVE_JOBS, true)
	else
		self.mapOverviewSelector:setState(self.MAP_SELECTOR_CREATE_JOB, true)
		self.mapOverviewSelector:setDisabled(true)
	end
end

function CpCourseGeneratorFrame:setActiveJobTypeSelection(jobTypeIndex)
	if self.currentJob == nil or jobTypeIndex ~= self.currentJob.jobTypeIndex then
		for i = #self.jobMenuLayout.elements, 1, -1 do
			self.jobMenuLayout.elements[i]:delete()
		end
		self.currentJob = g_currentMission.aiJobTypeManager:createJob(jobTypeIndex)
		local farmId = 1
		if g_localPlayer then
			farmId = g_localPlayer.farmId
		end
		self.currentJob:applyCurrentState(self.currentJobVehicle, g_currentMission, farmId, false)
		self.currentJobElements = {}
		for _, group in ipairs(self.currentJob:getGroupedParameters()) do
			local titleElement = self.createTitleTemplate:clone(self.jobMenuLayout)

			titleElement:setText(group:getTitle())

			for _, item in ipairs(group:getParameters()) do
				local element = nil
				local parameterType = item:getType()

				if parameterType == AIParameterType.TEXT then
					element = self.createTextTemplate:clone(self.jobMenuLayout)
				elseif parameterType == AIParameterType.POSITION then
					element = self.createPositionTemplate:clone(self.jobMenuLayout)
				elseif parameterType == AIParameterType.POSITION_ANGLE then
					element = self.createPositionRotationTemplate:clone(self.jobMenuLayout)
				elseif parameterType == AIParameterType.SELECTOR or parameterType == AIParameterType.UNLOADING_STATION or parameterType == AIParameterType.LOADING_STATION or parameterType == AIParameterType.FILLTYPE then
					element = self.createMultiOptionTemplate:clone(self.jobMenuLayout)

					element:setDataSource(item)
				end
				if element then 
					FocusManager:loadElementFromCustomValues(element)

					element.aiParameter = item
					if element.updateTitle then 
						element:updateTitle()
					end
					element:setDisabled(not item:getCanBeChanged())
					table.insert(self.currentJobElements, element)
				end
			end
		end
		self:updateParameterValueTexts()
		self:validateParameters()
		self.jobMenuLayout:invalidateLayout()
		FocusManager:setFocus(self.jobTypeElement)
	end
	self:updateContextActions()
end

function CpCourseGeneratorFrame:openMap()
		----------------------
	--- Ingame map 
	----------------------
	---
	-- self:setJobMenuVisible(false)

	-- self.activeWorkerList:reloadData()
	self:toggleMapInput(true)
	self.ingameMap:onOpen()
	self.ingameMap:registerActionEvents()
	self.ingameMapBase:restoreDefaultFilter()
	-- if g_localPlayer ~= nil then
	-- 	local x, _, z = g_localPlayer:getPosition()
	-- 	self.ingameMap:setCenterToWorldPosition(x, z)
	-- end
end

function CpCourseGeneratorFrame:closeMap()
	self.ingameMap:onClose()
	self:toggleMapInput(false)

	-- self.startJobPending = false

	-- if self:getIsPicking() then
	-- 	self:executePickingCallback(false)
	-- 	self:refreshContextInput()
	-- end

	-- g_inputBinding:setContextEventsActive(self.INPUT_CONTEXT_NAME, InputAction.MENU_AXIS_LEFT_RIGHT, true)

	-- self.statusMessages = {}
	-- self:updateStatusMessages()
end