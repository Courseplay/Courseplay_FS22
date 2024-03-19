
---@class CpGuiUtil
CpGuiUtil = {}

--- Adds a new page to the in game menu.
function CpGuiUtil.fixInGameMenuPage(frame, pageName, uvs, position, predicateFunc)
	local inGameMenu = g_gui.screenControllers[InGameMenu]

	-- remove all to avoid warnings
	for k, v in pairs({pageName}) do
		inGameMenu.controlIDs[v] = nil
	end

	inGameMenu:registerControls({pageName})
	inGameMenu[pageName] = frame
	inGameMenu.pagingElement:addElement(inGameMenu[pageName])

	inGameMenu:exposeControlsAsFields(pageName)

	for i = 1, #inGameMenu.pagingElement.elements do
		local child = inGameMenu.pagingElement.elements[i]
		if child == inGameMenu[pageName] then
			table.remove(inGameMenu.pagingElement.elements, i)
			table.insert(inGameMenu.pagingElement.elements, position, child)
			break
		end
	end

	for i = 1, #inGameMenu.pagingElement.pages do
		local child = inGameMenu.pagingElement.pages[i]
		if child.element == inGameMenu[pageName] then
			table.remove(inGameMenu.pagingElement.pages, i)
			table.insert(inGameMenu.pagingElement.pages, position, child)
			break
		end
	end

	inGameMenu.pagingElement:updateAbsolutePosition()
	inGameMenu.pagingElement:updatePageMapping()
	
	inGameMenu:registerPage(inGameMenu[pageName], position, predicateFunc)
	local iconFileName = Utils.getFilename('img/ui_courseplay.dds', g_Courseplay.BASE_DIRECTORY)
	inGameMenu:addPageTab(inGameMenu[pageName], iconFileName, GuiUtils.getUVs(uvs))
	inGameMenu[pageName]:applyScreenAlignment()
	inGameMenu[pageName]:updateAbsolutePosition()

	for i = 1, #inGameMenu.pageFrames do
		local child = inGameMenu.pageFrames[i]
		if child == inGameMenu[pageName] then
			table.remove(inGameMenu.pageFrames, i)
			table.insert(inGameMenu.pageFrames, position, child)
			break
		end
	end

	inGameMenu:rebuildTabList()
end

--- Clones a child element with a given profile name.
---@param rootElement GuiElement Searches in this element children elements.
---@param profileName string 
---@param parent GuiElement New parent element to link the gui element with.
---@return GuiElement
function CpGuiUtil.cloneElementWithProfileName(rootElement, profileName, parent)
	local item = CpGuiUtil.getFirstElementWithProfileName(rootElement, profileName)
	local clone = item and item:clone(item.parent, true)
	if clone then 
		clone:unlinkElement()
		FocusManager:removeElement(clone)
		return clone:clone(parent, true)
	end	
end

--- Gets all children elements with a given profile name.
---@param rootElement GuiElement Searches in this element children elements.
---@param profileName string 
---@return table
function CpGuiUtil.getElementsWithProfileName(rootElement, profileName)
	local function getElement(element)
		return element.profile and element.profile == profileName
	end
	return rootElement:getDescendants(getElement)
end

--- Gets the first children element with a given profile name.
---@param rootElement GuiElement Searches in this element children elements.
---@param profileName string 
---@return GuiElement
function CpGuiUtil.getFirstElementWithProfileName(rootElement, profileName)
	local items = CpGuiUtil.getElementsWithProfileName(rootElement, profileName)
	return items and items[1]
end

--- Executes a function for all children elements with a given profile name.
---@param rootElement GuiElement Searches in this element children elements.
---@param profileName string 
---@param lambda function
---@return GuiElement
function CpGuiUtil.executeFunctionForElementsWithProfileName(rootElement, profileName, lambda, ...)
	local items = CpGuiUtil.getElementsWithProfileName(rootElement, profileName)
	if items then 
		for _, item in ipairs(items) do 
			lambda(item, ...)
		end
	end
end

--- Sets a value for all children elements with a given profile name.
---@param rootElement GuiElement Searches in this element children elements.
---@param profileName string 
---@param valueName string
---@return GuiElement
function CpGuiUtil.setValueForElementsWithProfileName(rootElement, profileName, valueName, ...)
	local items = CpGuiUtil.getElementsWithProfileName(rootElement, profileName)
	if items then 
		for _, item in ipairs(items) do 
			item[valueName](item, ...)
		end
	end
end

--- Executes a function for all children elements.
---@param rootElement GuiElement Searches in this element children elements.
---@param lambda1 function
---@param lambda2 function
---@return GuiElement
function CpGuiUtil.executeFunctionForElements(rootElement, lambda1, lambda2, ...)
	local items = rootElement:getDescendants(lambda1)
	if items then 
		for _, item in ipairs(items) do 
			lambda2(item, ...)
		end
	end
end

--- Changes the text of children elements with a given profile name.
---@param rootElement GuiElement Searches in this element children elements.
---@param profileName string 
---@param text string
---@return GuiElement
function CpGuiUtil.changeTextForElementsWithProfileName(rootElement, profileName, text)
	CpGuiUtil.executeFunctionForElementsWithProfileName(rootElement, profileName,
														TextElement.setText, text)
end

--- Changes the color of children elements with a given profile name.
---@param rootElement GuiElement Searches in this element children elements.
---@param profileName string 
---@param color table r, g, b, alpha
---@return GuiElement
function CpGuiUtil.changeColorForElementsWithProfileName(rootElement, profileName, color)
	local r, g, b, a = unpack(color)

	CpGuiUtil.executeFunctionForElementsWithProfileName(rootElement, profileName,
													BitmapElement.setImageColor, nil, r, g, b, a)
end

--- Gets the first multi text element for the rootElement.
---@param rootElement GuiElement Searches in this element children elements.
---@return GuiElement
function CpGuiUtil.getGenericSettingElementFromLayout(rootElement)
	return CpGuiUtil.getFirstElementWithProfileName(rootElement, "multiTextOptionSettings")
end

--- Gets the first sub title element for the rootElement.
---@param rootElement GuiElement Searches in this element children elements.
---@return GuiElement
function CpGuiUtil.getGenericSubTitleElementFromLayout(rootElement)
	return CpGuiUtil.getFirstElementWithProfileName(rootElement, "settingsMenuSubtitle")
end

--- Gets the rgb color in 0-1 from 0-255.
---@param r number
---@param g number
---@param b number
---@param alpha number|nil
---@return number
---@return number
---@return number
---@return number
function CpGuiUtil.getNormalizedRgb(r, g, b, alpha)
	return r / 255, g / 255, b / 255, alpha
end
---unit_minutesShort
function CpGuiUtil.getFormatTimeText(seconds)
	local minutes = math.floor(seconds/60)
	local hours = math.floor(minutes/60)
	minutes = minutes %60
	if hours > 0 then 
		return string.format("%dh:%dm", hours, minutes)
	elseif minutes>0 then 
		seconds = seconds %60
		return string.format("%dm:%ds", minutes, seconds)
	else 
		return string.format("%ds", seconds)
	end
end

function CpGuiUtil.debugFocus(element, direction)
	local targetElement = FocusManager.getNestedFocusTarget(element, direction)
	CpUtil.debugFormat(CpDebug.DBG_HUD, "isFocusLocked: %s, canReceiveFocus: %s, targetName: %s, focusElement: %s",
										tostring(FocusManager.isFocusLocked),
										tostring(element:canReceiveFocus()),
										FocusManager.getNestedFocusTarget(element, direction).targetName,
										FocusManager.currentFocusData.focusElement and FocusManager.currentFocusData.focusElement == targetElement and FocusManager.currentFocusData.focusElement.focusActive
										)	
end
function CpGuiUtil.setTarget(element, target)
	for i = 1, #element.elements do
		CpGuiUtil.setTarget(element.elements[i], target)
	end

	element.target = target
	element.targetName = target.name
end

--- Apply the defined filter to the map.
---@param map table ingame menu map
---@param hotspots table
function CpGuiUtil.applyHotspotFilters(map, hotspots)
	for k, v in pairs(hotspots) do
		map:setHotspotFilter(k, v)
	end
end

--- Saves the hotspot filters and disables these on the map.
---@param map table
---@param hotspots table
function CpGuiUtil.saveAndDisableHotspotFilters(map, hotspots)
	for k, v in pairs(map.filter) do
		map:setHotspotFilter(k, false)
		hotspots[k] = v
	end
end

------------------------------------------------
--- Plots 
------------------------------------------------

--- Translates the world coordinates to screen coordinates.
---@param map table
---@param worldX number
---@param worldZ number
---@param isHudMap boolean|nil If the hud minimap is used.
---@return number
---@return number
---@return number
---@return boolean
function CpGuiUtil.worldToScreen(map, worldX, worldZ, isHudMap)
	local objectX = (worldX + map.worldCenterOffsetX) / map.worldSizeX * 0.5 + 0.25
	local objectZ = (worldZ + map.worldCenterOffsetZ) / map.worldSizeZ * 0.5 + 0.25
	local x, y, _, _ = map.fullScreenLayout:getMapObjectPosition(objectX, objectZ, 0, 0, 0, true)
	local rot = 0
	local visible = true
	if isHudMap then 
		--- The plot is displayed in the hud.
		objectX = (worldX + map.worldCenterOffsetX) / map.worldSizeX * map.mapExtensionScaleFactor + map.mapExtensionOffsetX
		objectZ = (worldZ + map.worldCenterOffsetZ) / map.worldSizeZ * map.mapExtensionScaleFactor + map.mapExtensionOffsetZ

		x, y, rot, visible = map.layout:getMapObjectPosition(objectX, objectZ, 0, 0, 0, false)
		if map.state == IngameMap.STATE_MINIMAP_ROUND and map.layout.rotateWithMap then 
			x, y, rot, visible = CpGuiUtil.getMapObjectPositionCircleLayoutFix(map.layout, objectX, objectZ, 0, 0, 0, false)
		end
	end
	return x, y, rot, visible
end

--- Giants was not so kind, as to allow getting the positions even, if the object is outside the map range ...
--- This is a custom version for: IngameMapLayoutCircle:getMapObjectPosition(...)
---@param layout table
---@param objectU number
---@param objectV number
---@param width number
---@param height number
---@param rot number
---@param persistent boolean
---@return number
---@return number
---@return number
---@return boolean
function CpGuiUtil.getMapObjectPositionCircleLayoutFix(layout, objectU, objectV, width, height, rot, persistent)
	local mapWidth, mapHeight = layout:getMapSize()
	local mapX, mapY = layout:getMapPosition()
	local objectX = objectU * mapWidth + mapX
	local objectY = (1 - objectV) * mapHeight + mapY
	objectX, objectY, rot = layout:rotateWithMap(objectX, objectY, rot, persistent)
	objectX = objectX - width * 0.5
	objectY = objectY - height * 0.5

	return objectX, objectY, rot, true
end


------------------------------------------------
--- Hud 
------------------------------------------------

--- Creates a new Overlay
---@param size table x, y
---@param iconData table filename, uvs
---@param color table r, g, b, alpha
---@param alignment table vertical, horizontal alignments
function CpGuiUtil.createOverlay(size, iconData, color, alignment)
	local filename, uvs = unpack(iconData)
	local overlay = Overlay.new(filename, 0, 0, unpack(size))
    overlay:setUVs(uvs)
    overlay:setColor(unpack(color))
    overlay:setAlignment(unpack(alignment))
	return overlay
end

--- Enable/disable camera rotation when a vehicle is selected. We want to disable camera rotation per mouse
--- when we enable the mouse cursor so it can be used click controls on a GUI
---@param vehicle table
---@param enableRotation boolean
---@param savedRotatableInfo boolean[] the caller may want to pass in a variable to save the original isRotatable
--- setting of the camera so it will only enabled again when it was originally enabled
function CpGuiUtil.setCameraRotation(vehicle, enableRotation, savedRotatableInfo)
	if not savedRotatableInfo then
		savedRotatableInfo = {}
	end
	for i, camera in pairs(vehicle.spec_enterable.cameras) do
		local isRotatable
		if enableRotation then
			-- restore original setting if exists
			isRotatable = savedRotatableInfo[camera] or true
			CpUtil.debugVehicle(CpDebug.DBG_HUD, vehicle, '    camera %d restore isRotatable %s', i, isRotatable)
		else
			-- save original rotatable setting
			CpUtil.debugVehicle(CpDebug.DBG_HUD, vehicle, '    camera %d disable rotation, current %s', i, camera.isRotatable)
			savedRotatableInfo[camera] = camera.isRotatable
			camera.isRotatable = false
		end
		camera.isRotatable = isRotatable
	end
end

--- Adds the copy/paste button line to the hud layout with copy,paste and clear button.
---@param layout table
---@param baseHud CpBaseHud
---@param vehicle table
---@param lines table
---@param wMargin number
---@param hMargin number
---@param line number
function CpGuiUtil.addCopyAndPasteButtons(layout, baseHud, vehicle, lines, wMargin, hMargin, line)
	local imageFilename = Utils.getFilename('img/ui_courseplay.dds', g_Courseplay.BASE_DIRECTORY)
    local imageFilename2 = Utils.getFilename('img/iconSprite.dds', g_Courseplay.BASE_DIRECTORY)
                                      
	local leftX, leftY = unpack(lines[line].left)
    local rightX, rightY = unpack(lines[line].right)
    local btnYOffset = hMargin*0.2
	local width, height = getNormalizedScreenValues(22, 22)

	local copyOverlay = CpGuiUtil.createOverlay({width, height},
	{imageFilename, GuiUtils.getUVs(unpack(CpBaseHud.uvs.copySymbol))}, 
	CpBaseHud.OFF_COLOR,
	CpBaseHud.alignments.bottomRight)

	local pasteOverlay = CpGuiUtil.createOverlay({width, height},
		{imageFilename, GuiUtils.getUVs(unpack(CpBaseHud.uvs.pasteSymbol))}, 
		CpBaseHud.OFF_COLOR,
		CpBaseHud.alignments.bottomRight)

	local clearCourseOverlay = CpGuiUtil.createOverlay({width, height},
		{imageFilename2, GuiUtils.getUVs(unpack(CpBaseHud.uvs.clearCourseSymbol))}, 
		CpBaseHud.OFF_COLOR,
		CpBaseHud.alignments.bottomRight)

	layout.copyButton = CpHudButtonElement.new(copyOverlay, layout)
	layout.copyButton:setPosition(rightX, rightY-btnYOffset)

	layout.pasteButton = CpHudButtonElement.new(pasteOverlay, layout)
    layout.pasteButton:setPosition(rightX, rightY-btnYOffset)

	layout.clearCacheBtn = CpHudButtonElement.new(clearCourseOverlay, layout)
    layout.clearCacheBtn:setPosition(rightX - width - wMargin/2, rightY - btnYOffset)

	layout.copyCacheText = CpTextHudElement.new(layout, leftX, leftY, CpBaseHud.defaultFontSize)
end

--- Setup for the copy course btn.
---@param layout table
---@param baseHud CpBaseHud
---@param vehicle table
---@param lines table
---@param wMargin number
---@param hMargin number
---@param line number
function CpGuiUtil.addCopyCourseBtn(layout, baseHud, vehicle, lines, wMargin, hMargin, line)    
    
	CpGuiUtil.addCopyAndPasteButtons(layout, baseHud, vehicle, lines, wMargin, hMargin, line)

    layout.copyButton:setCallback("onClickPrimary", vehicle, function (vehicle)
        if not CpBaseHud.courseCache and vehicle:hasCpCourse() then 
            CpBaseHud.courseCache = vehicle:getFieldWorkCourse()
        end
    end)

    layout.pasteButton:setCallback("onClickPrimary", vehicle, function (vehicle)
        if CpBaseHud.courseCache and not vehicle:hasCpCourse() then 
            vehicle:cpCopyCourse(CpBaseHud.courseCache)
        end
    end)

    layout.clearCacheBtn:setCallback("onClickPrimary", vehicle, function (vehicle)
        CpBaseHud.courseCache = nil
    end)

end

--- Updates the copy buttons
---@param layout CpHudPageElement
---@param vehicle table
---@param status CpStatus
function CpGuiUtil.updateCopyBtn(layout, vehicle, status)
    if CpBaseHud.courseCache then 
        local courseName =  CpCourseManager.getCourseName(CpBaseHud.courseCache)
        layout.copyCacheText:setTextDetails(CpBaseHud.copyText .. courseName)
        layout.clearCacheBtn:setVisible(true)
        layout.pasteButton:setVisible(true)
        layout.copyButton:setVisible(false)
        if vehicle:hasCpCourse() then 
            layout.copyCacheText:setTextColorChannels(unpack(CpBaseHud.OFF_COLOR))
            layout.pasteButton:setColor(unpack(CpBaseHud.OFF_COLOR))
        else 
            layout.copyCacheText:setTextColorChannels(unpack(CpBaseHud.WHITE_COLOR))
            layout.pasteButton:setColor(unpack(CpBaseHud.ON_COLOR))
        end
        layout.copyButton:setDisabled(false)
        layout.pasteButton:setDisabled(false)
        layout.clearCacheBtn:setDisabled(false)
    else
        layout.copyCacheText:setTextDetails("")
        layout.clearCacheBtn:setVisible(false)
        layout.pasteButton:setVisible(false)
        layout.copyButton:setVisible(vehicle:hasCpCourse())
    end
end

function CpGuiUtil.movesMapCenterTo(map, worldX, worldZ)
    local width, height = map.ingameMap.fullScreenLayout:getMapSize()
    local oldTargetX, oldTargetZ =  map:localToWorldPos(map:getLocalPointerTarget())
    local diffX = worldX - oldTargetX
    local diffZ = worldZ - oldTargetZ
    local dx = diffX /  map.terrainSize * 0.5 * width
    local dy = -diffZ /  map.terrainSize * 0.5 * height
    map:moveCenter(-dx, -dy)
end

function CpGuiUtil.preOpeningInGameMenu(vehicle)
    local inGameMenu =  g_currentMission.inGameMenu
    inGameMenu.pageAI.hudVehicle = vehicle
    if g_gui.currentGuiName ~= "InGameMenu" then
		g_gui:showGui("InGameMenu")
	end
    return inGameMenu
end

function CpGuiUtil.openCourseManagerGui(vehicle)
    local inGameMenu = CpGuiUtil.preOpeningInGameMenu(vehicle)
	inGameMenu:goToPage(inGameMenu.pageCpCourseManager)
end

function CpGuiUtil.openCourseGeneratorGui(vehicle)
    local inGameMenu = CpGuiUtil.preOpeningInGameMenu(vehicle)
    local pageAI = inGameMenu.pageAI
    --- Opens the ai inGame menu
    inGameMenu:goToPage(pageAI)
    local hotspot = vehicle:getMapHotspot()
    pageAI:setMapSelectionItem(hotspot)
    CpUtil.debugVehicle(CpDebug.DBG_HUD, vehicle, "opened ai inGame menu.")
    if vehicle:getIsCpActive() or not g_currentMission:getHasPlayerPermission("hireAssistant") then 
        pageAI:updateParameterValueTexts()
		return
    end
	CpUtil.debugVehicle(CpDebug.DBG_HUD, vehicle, "opened ai inGame job creation.")
    vehicle:updateAIFieldWorkerImplementData()
    pageAI.currentJobTypes = {}
	local currentJobTypesTexts = {}
	local currentJobTypeIndex, currentIndex = nil, nil
	for index, jobType in ipairs(g_currentMission.aiJobTypeManager.jobTypes) do
		if pageAI.jobTypeInstances[index]:getIsAvailableForVehicle(vehicle) then
			table.insert(pageAI.currentJobTypes, index)
			table.insert(currentJobTypesTexts, jobType.title)
			if pageAI.jobTypeInstances[index]:isa(CpAIJob) then 
				currentJobTypeIndex = currentJobTypeIndex or index
				currentIndex = currentIndex or #pageAI.currentJobTypes
			end
		end
	end
	if #pageAI.currentJobTypes == 0 then
		return
	end

	pageAI.jobTypeElement:setTexts(currentJobTypesTexts)
	pageAI.jobTypeElement:setState(currentIndex or 1)

	pageAI.mode = InGameMenuAIFrame.MODE_CREATE
	pageAI.currentJobVehicle = vehicle
	pageAI.currentJob = nil

	pageAI:setJobMenuVisible(true)
	pageAI:setActiveJobTypeSelection(currentJobTypeIndex or 1)
	if not vehicle:hasCpCourse() then 
		if pageAI.currentJob:getCanGenerateFieldWorkCourse() then 
			CpUtil.debugVehicle(CpDebug.DBG_HUD, vehicle, "opened ai inGame menu course generator.")
			pageAI:onClickOpenCloseCourseGenerator()
		end
	end
    --- Moves the map, so the selected vehicle is directly visible.
    local worldX, _, worldZ = getWorldTranslation(vehicle.rootNode)
    CpGuiUtil.movesMapCenterTo(pageAI.ingameMap, worldX, worldZ)
end

function CpGuiUtil.openVehicleSettingsGui(vehicle)
    local inGameMenu = CpGuiUtil.preOpeningInGameMenu(vehicle)
    inGameMenu:goToPage(inGameMenu.pageCpVehicleSettings)
end

function CpGuiUtil.openGlobalSettingsGui(vehicle)
    local inGameMenu = CpGuiUtil.preOpeningInGameMenu(vehicle)
    inGameMenu:goToPage(inGameMenu.pageCpGlobalSettings)
end

CpGuiUtil.UNIT_EXTENSIONS = {
	"k",
	"M",
	"G",
	"T"
}
--- Converts the number into kilo, mega, giga or tera units with the correct symbol.
---@param num number
---@return number
---@return string
function CpGuiUtil.getFixedUnitValueWithUnitSymbol(num)
	for i=4, 1, -1 do 
		local delta = math.pow(10, 3 * i)
		if num >= delta then 
			return num / delta, CpGuiUtil.UNIT_EXTENSIONS[i]
		end
	end
	return num, ""
end