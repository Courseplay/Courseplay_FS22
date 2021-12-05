--- AI job derived of AIJobFieldWork.
---@class AIJobFieldWorkCp : AIJobFieldWork
AIJobFieldWorkCp = {}
local AIJobFieldWorkCp_mt = Class(AIJobFieldWorkCp, AIJobFieldWork)

---Localization text symbols.
AIJobFieldWorkCp.translations = {
    JobName = "FIELDWORK_CP",
    GenerateButton = "FIELDWORK_BUTTON",
	workWidth = "workWidth",
	centerMode = "centerMode",
	headlandCornerType = "headlandCornerType",
	numberOfHeadlands = "numberOfHeadlands",
	rowDirection = "rowDirection",
	startOnHeadland = "startOnHeadland",

}

--- Creates a xml schema to load the ai parameters from the config file.
function AIJobFieldWorkCp:initXmlSchema()
	AIJobFieldWorkCp.xmlSchema = XMLSchema.new("AIParameters")
	local schema = AIJobFieldWorkCp.xmlSchema	
	--- 			valueTypeId, 			path, 				description, defaultValue, isRequired
	schema:register(XMLValueType.STRING, "AIParameters.AIParameter(?)#name", "AI parameter name",nil,true)
	schema:register(XMLValueType.STRING, "AIParameters.AIParameter(?)#title", "AI parameter tile",nil,true)
	schema:register(XMLValueType.INT, "AIParameters.AIParameter(?)#min", "AI parameter min")
	schema:register(XMLValueType.INT, "AIParameters.AIParameter(?)#max", "AI parameter max")
	schema:register(XMLValueType.FLOAT, "AIParameters.AIParameter(?)#incremental", "AI parameter incremental",1)

	schema:register(XMLValueType.STRING, "AIParameters.AIParameter(?).Values.Value(?)#name", "AI parameter value name", nil)
	schema:register(XMLValueType.INT, "AIParameters.AIParameter(?).Values.Value(?)", "AI parameter value", nil)

	schema:register(XMLValueType.STRING, "AIParameters.AIParameter(?).Texts.Text(?)#name", "AI parameter value name", nil)
	schema:register(XMLValueType.STRING, "AIParameters.AIParameter(?).Texts.Text(?)", "AI parameter value", nil)
end

function AIJobFieldWorkCp.new(isServer, customMt)
	local self = AIJobFieldWork.new(isServer, customMt or AIJobFieldWorkCp_mt)
	self.aiParametersFilePath = Utils.getFilename("config/FieldWorkAIParameters.xml", g_Courseplay.BASE_DIRECTORY)
	self:initXmlSchema()
	self:enrichAIParameters(self.aiParametersFilePath)
	CoursePlot.getInstance():setVisible(false)
	self.lastPositionX, self.lastPositionZ = math.huge, math.huge
	self.hasValidPosition = false

	--- Small translation fix, needs to be removed once giants fixes it.
	local ai = 	g_currentMission.aiJobTypeManager
	ai:getJobTypeByIndex(ai:getJobTypeIndexByName("FIELDWORK_CP")).title = g_i18n:getText(AIJobFieldWorkCp.translations.JobName)
	return self
end

--- Loads all AI parameters form an xmlFile.
function AIJobFieldWorkCp:loadAIParametersData(filePath)
	local aiParameters = {}
	local xmlFile = XMLFile.load("aiParametersXml", filePath, AIJobFieldWorkCp.xmlSchema)
	xmlFile:iterate("AIParameters.AIParameter", function (i, baseKey)
		local aiParameter = {}
		aiParameter.name = xmlFile:getValue(baseKey.."#name")
		aiParameter.title = g_i18n:getText(xmlFile:getValue(baseKey.."#title"))
		aiParameter.min = xmlFile:getValue(baseKey.."#min")
		aiParameter.max = xmlFile:getValue(baseKey.."#max")
		aiParameter.incremental = MathUtil.round(xmlFile:getValue(baseKey.."#incremental"),3)
	--	CpUtil.info("AIParameter(%d) name: %s, title: %s, min: %s, max: %s, inc: %s",
	--				i,tostring(aiParameter.name),tostring(aiParameter.title),tostring(aiParameter.min),
	--				tostring(aiParameter.max),tostring(aiParameter.incremental))
		aiParameter.values = {}
		xmlFile:iterate(baseKey..".Values.Value", function (i, key)
			local name = xmlFile:getValue(key.."#name")
			local value = xmlFile:getValue(key)
			table.insert(aiParameter.values,value)
		end)
		aiParameter.texts = {}
		xmlFile:iterate(baseKey..".Texts.Text", function (i, key)
			local name = xmlFile:getValue(key.."#name")
			local text = g_i18n:getText(xmlFile:getValue(key))
			table.insert(aiParameter.texts,text)
		end)
		table.insert(aiParameters,aiParameter)
	end)
	xmlFile:delete()
	return aiParameters
end


--- Creates the necessary AI parameters and binds them to the gui.
function AIJobFieldWorkCp:enrichAIParameters(filePath)
	self.aiParameters = self:loadAIParametersData(filePath)
	for _,data in ipairs(self.aiParameters) do
		local key = data.name.."Parameter"
		--- Creates the parameter
		self[key] = AIParameterSettingList.new(data)
		--- Creates a name link to get this parameter later with: "self:getNamedParameter("data.name")"
		self:addNamedParameter(data.name, self[key])
		--- Creates an Gui title element in the helper menu.
		local group = AIParameterGroup.new(data.title)
		group:addParameter(self[key])
		--- Adds this gui element to the gui table.
		table.insert(self.groupedParameters, group)
	end
end

function AIJobFieldWorkCp:applyCurrentState(vehicle, mission, farmId, isDirectStart)
	AIJobFieldWorkCp:superClass().applyCurrentState(self, vehicle, mission, farmId, isDirectStart)

	if vehicle.getLastJob ~= nil then
		local lastJob = vehicle:getLastJob()
		-- if there's a last job, reuse its parameters
		if not isDirectStart and lastJob ~= nil and lastJob:isa(AIJobFieldWorkCp) then
			for _, data in ipairs(self.aiParameters) do
				local key = data.name .. "Parameter"
				self[key]:setValue(lastJob[key]:getValue())
			end
		end
	end
	-- for now, always take the auto work width
	self.workWidthParameter:setFloatValue(WorkWidthUtil.getAutomaticWorkWidth(vehicle))
end

--- Called when parameters change, scan field
function AIJobFieldWorkCp:validate(farmId)
	local isValid, errorMessage = AIJobFieldWork:superClass().validate(self, farmId)
	if not isValid then
		return isValid, errorMessage
	end

	-- everything else is valid, now find the field
	local tx, tz = self.positionAngleParameter:getPosition()
	if tx == self.lastPositionX and tz == self.lastPositionZ then
		CpUtil.debugFormat(CpDebug.DBG_HUD, 'Position did not change, do not generate course again')
		return isValid, errorMessage
	else
		self.lastPositionX, self.lastPositionZ = tx, tz
		self.hasValidPosition = true
	end

	self.fieldPolygon = g_fieldScanner:findContour(tx, tz)
	if not self.fieldPolygon then
		self.hasValidPosition = false
		return false, 'target not on field'
	end

	if self.course == nil then
		return false, 'Generate a course before starting the job!'
	end
	return true, ''
end

--- Registers additional jobs.
function AIJobFieldWorkCp.registerJob(self)
	self:registerJobType("FIELDWORK_CP", AIJobFieldWorkCp.translations.JobName, AIJobFieldWorkCp)
end

--- Is course generation allowed ?
function AIJobFieldWorkCp:getCanGenerateFieldWorkCourse()
	return self.hasValidPosition
end

--- Button callback to generate a field work course.
function AIJobFieldWorkCp:onClickGenerateFieldWorkCourse()
	print("onClickGenerateFieldWorkCourse")

	local vehicle = self.vehicleParameter:getVehicle()
	local status, ok
	status, ok, self.course = CourseGeneratorInterface.generate(self.fieldPolygon,
			{x = self.lastPositionX, z = self.lastPositionZ},
			0,
			AIUtil.getTurningRadius(vehicle),
			self.workWidthParameter:getValue(),
			self.numberOfHeadlandsParameter:getValue(),
			self.startOnHeadlandParameter:getValue(),
			self.headlandCornerTypeParameter:getValue(),
			self.centerModeParameter:getValue(),
			self.rowDirectionParameter:getValue()
	)
	if not ok then
		return false, 'could not generate course'
	end
	-- we have course, show the course plot on the AI helper screen
	CoursePlot.getInstance():setWaypoints(self.course.waypoints)
	CoursePlot.getInstance():setVisible(true)
	-- save the course on the vehicle for the strategy to use later
	self.course:setVehicle(vehicle)
	vehicle:setFieldWorkCourse(self.course)
end

--- for reload, messing with the internals of the job type manager so it uses the reloaded job
if g_currentMission then
	local myJobTypeIndex = g_currentMission.aiJobTypeManager:getJobTypeIndexByName('FIELDWORK_CP')
	if myJobTypeIndex then
		local myJobType = g_currentMission.aiJobTypeManager:getJobTypeByIndex(myJobTypeIndex)
		myJobType.classObject = AIJobFieldWorkCp
	end
end

AIJobTypeManager.loadMapData = Utils.appendedFunction(AIJobTypeManager.loadMapData,AIJobFieldWorkCp.registerJob)

--- Adds the course generate button.
function AIJobFieldWorkCp.loadFromXmlInGameMenu(self, xmlFile, key)
	self.buttonGenerateCourse = self.buttonGotoJob:clone(self.buttonGotoJob.parent)
	self.buttonGenerateCourse:setText(g_i18n:getText(AIJobFieldWorkCp.translations.GenerateButton))
	--self.buttonGenerateCourse:setText("generator")
	self.buttonGenerateCourse:setVisible(false)
	self.buttonGenerateCourse.onClickCallback = self.onClickGenerateFieldWorkCourse
	self.buttonGotoJob.parent:invalidateLayout()
end
InGameMenuAIFrame.onLoadMapFinished = Utils.appendedFunction(InGameMenuAIFrame.onLoadMapFinished,AIJobFieldWorkCp.loadFromXmlInGameMenu)


--- Updates generate button visibility.
function AIJobFieldWorkCp.updateContextInputBarVisibilityIngameMenu(self)
	local visible = self.currentJob and self.currentJob.getCanGenerateFieldWorkCourse and self.currentJob:getCanGenerateFieldWorkCourse()
	self.buttonGenerateCourse:setVisible(visible)
end

InGameMenuAIFrame.updateContextInputBarVisibility = Utils.appendedFunction(InGameMenuAIFrame.updateContextInputBarVisibility,AIJobFieldWorkCp.updateContextInputBarVisibilityIngameMenu)

--- Button Callback.
function InGameMenuAIFrame:onClickGenerateFieldWorkCourse()
	if self.currentJob and self.currentJob.getCanGenerateFieldWorkCourse and self.currentJob:getCanGenerateFieldWorkCourse() then 
		self.currentJob:onClickGenerateFieldWorkCourse()
	end
end