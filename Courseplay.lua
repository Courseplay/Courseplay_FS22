
--- Global class
Courseplay = CpObject()
Courseplay.MOD_NAME = g_currentModName
Courseplay.BASE_DIRECTORY = g_currentModDirectory
Courseplay.BASE_KEY = "Courseplay."

function Courseplay:init()
	self:registerConsoleCommands()
end

------------------------------------------------------------------------------------------------------------------------
-- Global Giants functions listener 
------------------------------------------------------------------------------------------------------------------------

--- This function is called on loading a savegame.
---@param filename string
function Courseplay:loadMap(filename)
	self.globalSettings = CpGlobalSettings()
	self:registerSchema()
	self:load()
	self:setupGui()
	if g_currentMission.missionInfo.savegameDirectory ~= nil then
		local filePath = g_currentMission.missionInfo.savegameDirectory .. "/Courseplay.xml"
		self.xmlFile = XMLFile.load("cpXml", filePath , self.schema)
		if self.xmlFile == nil then return end
		self.globalSettings:loadFromXMLFile(self.xmlFile,g_Courseplay.BASE_KEY)
		self.xmlFile:delete()
	end
end

function Courseplay:registerSchema()
	self.schema = XMLSchema.new("Courseplay")
	self.globalSettings:registerSchema(self.schema,self.BASE_KEY)
end


function Courseplay:setupGui()
	CpVehicleSettingsFrame.init()
	CpGlobalSettingsFrame.init()
end

function Courseplay.saveToXMLFile(missionInfo)
	if missionInfo.isValid then 
		local xmlFile = XMLFile.create("cpXml",missionInfo.savegameDirectory.. "/Courseplay.xml", "Courseplay", g_Courseplay.schema)
		g_Courseplay.globalSettings:saveToXMLFile(xmlFile,g_Courseplay.BASE_KEY)
		xmlFile:save()
		xmlFile:delete()
	end
end
FSCareerMissionInfo.saveToXMLFile = Utils.appendedFunction(FSCareerMissionInfo.saveToXMLFile,Courseplay.saveToXMLFile)

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
	
end

---@param unicode number
---@param sym number
---@param modifier number
---@param isDown boolean
function Courseplay:keyEvent(unicode, sym, modifier, isDown)
	g_devHelper:keyEvent(unicode, sym, modifier, isDown)
end

function Courseplay:load()
	--self.savegameFolderPath = ('%ssavegame%d'):format(getUserProfileAppPath(), g_careerScreen.selectedIndex); -- This should work for both SP, MP and Dedicated Servers
	self.cpFolderPath = string.format("%s%s",getUserProfileAppPath(),"courseplay")
	createFolder(self.cpFolderPath)
	self.cpDebugPrintXmlFolderPath = string.format("%s/%s",self.cpFolderPath,"courseplayDebugPrint")
	createFolder(self.cpDebugPrintXmlFolderPath)
	self.cpDebugPrintXmlFilePathDefault = string.format("%s/%s",self.cpDebugPrintXmlFolderPath,"courseplayDebugPrint.xml")		

	self.cpXmlFile = string.format("%s/%s",self.cpFolderPath,"courseplay.xml")		

	g_courseManager = CourseManager()
end

function Courseplay:registerConsoleCommands()
	addConsoleCommand( 'cpAddMoney', 'adds money', 'addMoney',self)
	addConsoleCommand( 'cpRestartSaveGame', 'Load and start a savegame', 'restartSaveGame',self)
	addConsoleCommand( 'print', 'Print a variable', 'printVariable', self )
	addConsoleCommand( 'printGlobalCpVariable', 'Print a global cp variable', 'printGlobalCpVariable', self )
	addConsoleCommand( 'printVehicleVariable', 'Print g_currentMission.controlledVehicle.variable', 'printVehicleVariable', self )
	addConsoleCommand( 'printStrategyVariable', 'Print g_currentMission.controlledVehicle.spec_aiFieldWorker.driveStrategies[2].variable', 'printStrategyVariable', self )
	addConsoleCommand( 'cpLoadFile', 'Load a lua file', 'loadFile', self )
	addConsoleCommand( 'cpToggleDevHelper', 'Toggle development helper visual debug info', 'toggleDevHelper', self )
	addConsoleCommand( 'cpSaveAllFields', 'Save all fields of the map to an XML file for offline debugging', 'saveAllFields', self )
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
function Courseplay:printVariable(variableName, maxDepth,printToXML, printToSeparateXmlFiles)
	if printToXML and tonumber(printToXML) and tonumber(printToXML)>0 then
		CpUtil.printVariableToXML(variableName, maxDepth,printToSeparateXmlFiles)
		return
	end
	CpUtil.printVariable(variableName, maxDepth)
end

function Courseplay:printVariableInternal(prefix, variableName, maxDepth,printToXML,printToSeparateXmlFiles)
	if not string.startsWith(variableName, ':') and not string.startsWith(variableName, '.') then
		-- allow to omit the . at the beginning of the variable name.
		prefix = prefix .. '.'
	end
	self:printVariable(prefix .. variableName, maxDepth,printToXML,printToSeparateXmlFiles)
end


--- Print the variable in the selected vehicle's namespace
-- You can omit the dot for data members but if you want to call a function, you must start the variable name with a colon
function Courseplay:printVehicleVariable(variableName, maxDepth, printToXML,printToSeparateXmlFiles)
	local prefix = variableName and 'g_currentMission.controlledVehicle' or 'g_currentMission'
	variableName = variableName or 'controlledVehicle'
	self:printVariableInternal( prefix, variableName, maxDepth, printToXML,printToSeparateXmlFiles)
end

function Courseplay:printStrategyVariable(variableName, maxDepth, printToXML,printToSeparateXmlFiles)
	local prefix = 'g_currentMission.controlledVehicle.spec_aiFieldWorker.driveStrategies[2]'
	self:printVariableInternal( prefix, variableName, maxDepth, printToXML,printToSeparateXmlFiles)
end

function Courseplay:printGlobalCpVariable(variableName, maxDepth, printToXML,printToSeparateXmlFiles)
	if variableName then 
		self:printVariableInternal( 'g_Courseplay', variableName, maxDepth, printToXML,printToSeparateXmlFiles)
	else 
		self:printVariable('g_Courseplay', maxDepth, printToXML,printToSeparateXmlFiles)
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
	FieldUtil.saveAllFields()
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
    end
end
TypeManager.finalizeTypes = Utils.prependedFunction(TypeManager.finalizeTypes, Courseplay.register)

g_Courseplay = Courseplay()
addModEventListener(g_Courseplay)
