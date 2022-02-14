
--- Global class
Courseplay = CpObject()
Courseplay.MOD_NAME = g_currentModName
Courseplay.BASE_DIRECTORY = g_currentModDirectory
Courseplay.baseXmlKey = "Courseplay"
Courseplay.xmlKey = Courseplay.baseXmlKey.."."

function Courseplay:init()
	self:registerConsoleCommands()
	g_gui:loadProfiles( Utils.getFilename("config/gui/GUIProfiles.xml",Courseplay.BASE_DIRECTORY) )

	--- Base cp folder
	self.baseDir = getUserProfileAppPath() .. "modSettings/" .. Courseplay.MOD_NAME ..  "/"
	createFolder(self.baseDir)
	--- Base cp folder
	self.cpFilePath = self.baseDir.."courseplay.xml"
end

function Courseplay:registerXmlSchema()
	self.xmlSchema = XMLSchema.new("Courseplay")
	self.xmlSchema:register(XMLValueType.STRING,self.baseXmlKey.."#lastVersion")
	self.globalSettings:registerXmlSchema(self.xmlSchema,self.xmlKey)
	CpBaseHud.registerXmlSchema(self.xmlSchema,self.xmlKey)
end

--- Loads data not tied to a savegame.
function Courseplay:loadUserSettings()
	local xmlFile = XMLFile.loadIfExists("cpXmlFile",self.cpFilePath,self.xmlSchema)
	if xmlFile then
		self:showUserInformation(xmlFile,self.baseXmlKey)
		self.globalSettings:loadFromXMLFile(xmlFile,self.xmlKey)
		CpBaseHud.loadFromXmlFile(xmlFile,self.xmlKey)
		xmlFile:save()
		xmlFile:delete()
	end
end

--- Saves data not tied to a savegame.
function Courseplay:saveUserSettings()
	local xmlFile = XMLFile.create("cpXmlFile",self.cpFilePath,self.baseXmlKey,self.xmlSchema)
	if xmlFile then 
		self.globalSettings:saveUserSettingsToXmlFile(xmlFile,self.xmlKey)
		CpBaseHud.saveToXmlFile(xmlFile,self.xmlKey)
		if self.currentVersion then
			xmlFile:setValue(self.baseXmlKey.."#lastVersion",self.currentVersion)
		end
		xmlFile:save()
		xmlFile:delete()
	end
end

------------------------------------------------------------------------------------------------------------------------
-- User info with github reference and update notification.
------------------------------------------------------------------------------------------------------------------------

function Courseplay:showUserInformation(xmlFile,key)
	local showInfoDialog = true
	local currentVersion = g_modManager:getModByName(self.MOD_NAME).version
	local lastLoadedVersion = xmlFile:getValue(key.."#lastVersion")
	if lastLoadedVersion then 
		if currentVersion == lastLoadedVersion then 
			showInfoDialog = false
		end
	end
	if showInfoDialog then
		g_gui:showInfoDialog({
			text = string.format(g_i18n:getText("CP_infoText"), currentVersion)

		})
		self.currentVersion = currentVersion
		xmlFile:setValue(key.."#lastVersion",currentVersion)
	end
end

------------------------------------------------------------------------------------------------------------------------
-- Global Giants functions listener 
------------------------------------------------------------------------------------------------------------------------

--- This function is called on loading a savegame.
---@param filename string
function Courseplay:loadMap(filename)
	self.globalSettings = CpGlobalSettings()
	self:registerXmlSchema()
	self:loadUserSettings()
	self:load()
	self:setupGui()
	if g_currentMission.missionInfo.savegameDirectory ~= nil then
		local saveGamePath = g_currentMission.missionInfo.savegameDirectory .."/"
		local filePath = saveGamePath .. "Courseplay.xml"
		self.xmlFile = XMLFile.load("cpXml", filePath , self.xmlSchema)
		if self.xmlFile == nil then return end
		self.globalSettings:loadFromXMLFile(self.xmlFile,g_Courseplay.xmlKey)
		self.xmlFile:delete()

		g_assignedCoursesManager:loadAssignedCourses(saveGamePath)
	end

	--- Ugly hack to get access to the global AutoDrive table, as this global is dependent on the auto drive folder name.
	self.autoDrive = FS22_AutoDrive and FS22_AutoDrive.AutoDrive
	CpUtil.info("Auto drive found: %s",tostring(self.autoDrive~=nil))
end

function Courseplay:setupGui()
	local vehicleSettingsFrame = CpVehicleSettingsFrame.new()
	local globalSettingsFrame = CpGlobalSettingsFrame.new()
	local courseManagerFrame = CpCourseManagerFrame.new(self.courseStorage)
	g_gui:loadGui(Utils.getFilename("config/gui/VehicleSettingsFrame.xml",Courseplay.BASE_DIRECTORY),
				 "CpVehicleSettingsFrame", vehicleSettingsFrame,true)
	g_gui:loadGui(Utils.getFilename("config/gui/GlobalSettingsFrame.xml",Courseplay.BASE_DIRECTORY),
				 "CpGlobalSettingsFrame", globalSettingsFrame,true)
	g_gui:loadGui(Utils.getFilename("config/gui/CourseManagerFrame.xml",Courseplay.BASE_DIRECTORY),
				 "CpCourseManagerFrame", courseManagerFrame,true)
	local function predicateFunc()
		local inGameMenu = g_gui.screenControllers[InGameMenu]
		local aiPage = inGameMenu.pageAI
		return aiPage.currentHotspot ~= nil or aiPage.controlledVehicle ~= nil 
	end
	
	CpGuiUtil.fixInGameMenu(vehicleSettingsFrame,"pageCpVehicleSettings",
			{896, 0, 128, 128},3, predicateFunc)
	CpGuiUtil.fixInGameMenu(globalSettingsFrame,"pageCpGlobalSettings",
			{768, 0, 128, 128},4,function () return true end)
	CpGuiUtil.fixInGameMenu(courseManagerFrame,"pageCpCourseManager",
			{256,0,128,128},5, predicateFunc)
	
end

--- Adds cp help info to the in game help menu.
function Courseplay:loadMapDataHelpLineManager(xmlFile, missionInfo)
	self:loadFromXML(Utils.getFilename("config/HelpMenu.xml",Courseplay.BASE_DIRECTORY))
end
HelpLineManager.loadMapData = Utils.appendedFunction( HelpLineManager.loadMapData,Courseplay.loadMapDataHelpLineManager)

--- Saves all global data, for example global settings.
function Courseplay.saveToXMLFile(missionInfo)
	if missionInfo.isValid then 
		local saveGamePath = missionInfo.savegameDirectory .."/"
		local xmlFile = XMLFile.create("cpXml",saveGamePath.. "Courseplay.xml", 
				"Courseplay", g_Courseplay.xmlSchema)
		if xmlFile then	
			g_Courseplay.globalSettings:saveToXMLFile(xmlFile,g_Courseplay.xmlKey)
			xmlFile:save()
			xmlFile:delete()
		end
		g_Courseplay:saveUserSettings()
		g_assignedCoursesManager:saveAssignedCourses(saveGamePath)
	end
end
FSCareerMissionInfo.saveToXMLFile = Utils.prependedFunction(FSCareerMissionInfo.saveToXMLFile,Courseplay.saveToXMLFile)

function Courseplay:update(dt)
	g_devHelper:update()
end

function Courseplay:draw()
	g_devHelper:draw()
	CpDebug:draw()
end

---@param posX number
---@param posY number
---@param isDown boolean
---@param isUp boolean
---@param button number
function Courseplay:mouseEvent(posX, posY, isDown, isUp, button)
	if not g_gui:getIsGuiVisible() then
		local vehicle = g_currentMission.controlledVehicle
		local hud = vehicle and vehicle.getCpHud and vehicle:getCpHud()
		if hud then
			hud:mouseEvent(posX, posY, isDown, isUp, button)
		end
	end
end

---@param unicode number
---@param sym number
---@param modifier number
---@param isDown boolean
function Courseplay:keyEvent(unicode, sym, modifier, isDown)
	g_devHelper:keyEvent(unicode, sym, modifier, isDown)
end

function Courseplay:load()
	--- Sub folder for debug information
	self.debugDir = self.baseDir .. "Debug/"
	createFolder(self.debugDir) 
	--- Sub folder for debug prints
	self.debugPrintDir = self.debugDir .. "DebugPrints/"
	createFolder(self.debugPrintDir) 
	--- Default path to save prints without an explicit name.
	self.defaultDebugPrintPath = self.debugDir .. "DebugPrint.xml"

	self.courseDir = self.baseDir .. "Courses"
	createFolder(self.courseDir) 
	self.courseStorage = FileSystem(self.courseDir, g_currentMission.missionInfo.mapId)
	self.courseStorage:fixCourseStorageRoot()

	self.customFieldDir = self.baseDir .. "CustomFields"
	createFolder(self.customFieldDir)
	g_customFieldManager = CustomFieldManager(FileSystem(self.customFieldDir, g_currentMission.missionInfo.mapId))

	g_courseDisplay = CourseDisplay()
	g_vehicleConfigurations:loadFromXml()
	g_assignedCoursesManager:registerXmlSchema()

	--- Register additional AI messages.
	g_currentMission.aiMessageManager:registerMessage("ERROR_FULL", AIMessageErrorIsFull)
end

function Courseplay:registerConsoleCommands()
	addConsoleCommand( 'cpAddMoney', 'adds money', 'addMoney',self)
	addConsoleCommand( 'cpRestartSaveGame', 'Load and start a savegame', 'restartSaveGame',self)
	addConsoleCommand( 'print', 'Print a variable', 'printVariable', self )
	addConsoleCommand( 'printGlobalCpVariable', 'Print a global cp variable', 'printGlobalCpVariable', self )
	addConsoleCommand( 'printVehicleVariable', 'Print g_currentMission.controlledVehicle.variable', 'printVehicleVariable', self )
	addConsoleCommand( 'printImplementVariable', 'printImplementVariable <implement index> <variable>', 'printImplementVariable', self )
	addConsoleCommand( 'printStrategyVariable', 'Print a CP drive strategy variable', 'printStrategyVariable', self )
	addConsoleCommand( 'cpLoadFile', 'Load a lua file', 'loadFile', self )
	addConsoleCommand( 'cpToggleDevHelper', 'Toggle development helper visual debug info', 'toggleDevHelper', self )
	addConsoleCommand( 'cpSaveAllFields', 'Save all fields of the map to an XML file for offline debugging', 'saveAllFields', self )
	addConsoleCommand( 'cpReadVehicleConfigurations', 'Read custom vehicle configurations', 'loadFromXml', g_vehicleConfigurations)
end

---@param saveGameNumber number
function Courseplay:restartSaveGame(saveGameNumber)
	if g_server then
		doRestart(true, " -autoStartSavegameId " .. saveGameNumber)
		Courseplay.info('Restarting savegame %d', saveGameNumber)
	end
end

---@param amount number
function Courseplay:addMoney(amount)
	g_currentMission:addMoney(amount ~= nil and tonumber(amount) or 0, g_currentMission.player.farmId, MoneyType.OTHER)	
end

---Prints a variable to the console or a xmlFile.
---@param variableName string name of the variable, can be multiple levels
---@param maxDepth number maximum depth, 1 by default
---@param printToXML number should the variable be printed to an xml file ? (optional)
---@param printToSeparateXmlFiles number should the variable be printed to an xml file named after the variable ? (optional)
function Courseplay:printVariable(variableName, maxDepth, printToXML, printToSeparateXmlFiles)
	if printToXML and tonumber(printToXML) and tonumber(printToXML)>0 then
		CpUtil.printVariableToXML(variableName, maxDepth, printToSeparateXmlFiles)
		return
	end
	CpUtil.printVariable(variableName, maxDepth)
end

function Courseplay:printVariableInternal(prefix, variableName, maxDepth, printToXML, printToSeparateXmlFiles)
	if not string.startsWith(variableName, ':') and not string.startsWith(variableName, '.') then
		-- allow to omit the . at the beginning of the variable name.
		prefix = prefix .. '.'
	end
	self:printVariable(prefix .. variableName, maxDepth, printToXML, printToSeparateXmlFiles)
end

-- make sure variableName is syntactically correct (can be appended to another variable)
function Courseplay:ensureVariableNameSyntax(variableName)
	if not variableName then
		return ''
	elseif not string.startsWith(variableName, ':') and not string.startsWith(variableName, '.') then
		return '.' .. variableName
	else
		return variableName
	end
end

--- Print the variable in the selected vehicle's namespace
-- You can omit the dot for data members but if you want to call a function, you must start the variable name with a colon
function Courseplay:printVehicleVariable(variableName, maxDepth, printToXML, printToSeparateXmlFiles)
	local prefix = variableName and 'g_currentMission.controlledVehicle' or 'g_currentMission'
	variableName = variableName or 'controlledVehicle'
	self:printVariableInternal( prefix, variableName, maxDepth, printToXML, printToSeparateXmlFiles)
end

--- Print an implement variable. If implement.object.variable exists, print that, otherwise implement.variable
---@param implementIndex number index in getAttachedImplements()
function Courseplay:printImplementVariable(implementIndex, variableName, maxDepth, printToXML, printToSeparateXmlFiles)
	local prefix = string.format('g_currentMission.controlledVehicle:getAttachedImplements()[%d]', implementIndex)
	local objectVariableName = string.format('%s.object%s', prefix, self:ensureVariableNameSyntax(variableName))
	local var = CpUtil.getVariable(objectVariableName)
	if var then
		self:printVariable(objectVariableName, maxDepth, printToXML, printToSeparateXmlFiles)
	else
		local implementVariableName = string.format('%s%s', prefix, self:ensureVariableNameSyntax(variableName))
		self:printVariable(implementVariableName, maxDepth, printToXML, printToSeparateXmlFiles)
	end
end

function Courseplay:printStrategyVariable(variableName, maxDepth, printToXML, printToSeparateXmlFiles)
	local prefix = 'g_currentMission.controlledVehicle:getCpDriveStrategy()'
	self:printVariableInternal( prefix, variableName, maxDepth, printToXML, printToSeparateXmlFiles)
end

function Courseplay:printGlobalCpVariable(variableName, maxDepth, printToXML, printToSeparateXmlFiles)
	if variableName then 
		self:printVariableInternal( 'g_Courseplay', variableName, maxDepth, printToXML, printToSeparateXmlFiles)
	else 
		self:printVariable('g_Courseplay', maxDepth, printToXML, printToSeparateXmlFiles)
	end
end

--- Load a Lua file
--- This is to reload scripts without restarting the game.
function Courseplay:loadFile(fileName)
	fileName = fileName or 'reload.xml'
	local path = Courseplay.BASE_DIRECTORY .. '/' .. fileName
	if fileExists(path) then
		g_xmlFile = loadXMLFile('loadFile', path)
	end
	if not g_xmlFile then
		return 'Could not load ' .. path
	else
		local code = getXMLString(g_xmlFile, 'code')
		local f = getfenv(0).loadstring('setfenv(1, '.. Courseplay.MOD_NAME .. '); ' .. code)
		if f then
			f()
			return 'OK: ' .. path .. ' loaded.'
		else
			return 'ERROR: ' .. path .. ' could not be compiled.'
		end
	end
end

function Courseplay:toggleDevHelper()
	g_devHelper:toggle()
end

function Courseplay:saveAllFields()
	CpFieldUtil.saveAllFields()
end

function Courseplay.info(...)
	local updateLoopIndex = g_updateLoopIndex and g_updateLoopIndex or 0
	local timestamp = getDate( ":%S")
	print(string.format('%s [info lp%d] %s', timestamp, updateLoopIndex, string.format( ... )))
end

function Courseplay.infoVehicle(vehicle, ...)
	local vehicleName = vehicle and vehicle:getName() or "Unknown vehicle"
	local updateLoopIndex = g_updateLoopIndex and g_updateLoopIndex or 0
	local timestamp = getDate( ":%S")
	print(string.format('%s [info lp%d] %s: %s', timestamp, updateLoopIndex, vehicleName, string.format( ... )))
end

function Courseplay.error(str,...)
	Courseplay.info("error: "..str,...)
end

--- Fixes global translations.
function Courseplay.getText(i18n,superFunc,name,customEnv)
	return superFunc(i18n,name,customEnv or Courseplay.MOD_NAME)
end
I18N.getText = Utils.overwrittenFunction(I18N.getText,Courseplay.getText)

--- Registers all cp specializations.
---@param typeManager TypeManager
function Courseplay.register(typeManager)
	--- TODO: make this function async. 
	for typeName, typeEntry in pairs(typeManager.types) do	
		if CourseplaySpec.prerequisitesPresent(typeEntry.specializations) then
			typeManager:addSpecialization(typeName, Courseplay.MOD_NAME .. ".courseplaySpec")	
		end
		if CpVehicleSettings.prerequisitesPresent(typeEntry.specializations) then
			typeManager:addSpecialization(typeName, Courseplay.MOD_NAME .. ".cpVehicleSettings")	
		end
		if CpCourseGeneratorSettings.prerequisitesPresent(typeEntry.specializations) then
			typeManager:addSpecialization(typeName, Courseplay.MOD_NAME .. ".cpCourseGeneratorSettings")	
		end
		if CpCourseManager.prerequisitesPresent(typeEntry.specializations) then
			typeManager:addSpecialization(typeName, Courseplay.MOD_NAME .. ".cpCourseManager")	
		end
		CpAIWorker.register(typeManager,typeName,typeEntry.specializations)
		CpAIFieldWorker.register(typeManager,typeName,typeEntry.specializations)
		CpAIBaleFinder.register(typeManager,typeName,typeEntry.specializations)
		CpVehicleSettingDisplay.register(typeManager,typeName,typeEntry.specializations)
		CpHud.register(typeManager,typeName,typeEntry.specializations)
    end
end
TypeManager.finalizeTypes = Utils.prependedFunction(TypeManager.finalizeTypes, Courseplay.register)

g_Courseplay = Courseplay()
addModEventListener(g_Courseplay)

--- Adds possibility to use giants gui functionality with custom image filenames.
--- Every special filename needs to start with CP_ as prefix, with will be ignored for the path.
local function getFilename(filename,superFunc, baseDir)
	if Courseplay and string.startsWith(filename,"CP_") then 
		filename = string.gsub(filename, "CP_", "")
		return superFunc(filename,g_Courseplay.BASE_DIRECTORY)
	else
		return superFunc(filename,baseDir)
	end
end
Utils.getFilename = Utils.overwrittenFunction(Utils.getFilename,getFilename)
