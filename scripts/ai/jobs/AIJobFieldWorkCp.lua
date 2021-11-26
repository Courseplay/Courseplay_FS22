--- Example AI job derived of AIJobFieldWork.
---@class AIJobFieldWorkCp
AIJobFieldWorkCp = {}
local AIJobFieldWorkCp_mt = Class(AIJobFieldWorkCp, AIJobFieldWork)

function AIJobFieldWorkCp.new(isServer, customMt)
	local self = AIJobFieldWork.new(isServer, customMt or AIJobFieldWorkCp_mt)
	--- Creates a custom parameter.
	self.workWidthParameter = AIParameterWorkWidth.new()
	--- Creates a name link to get this parameter later with: "self:getNamedParameter("workWidth")"
	self:addNamedParameter("workWidth", self.workWidthParameter)
	--- Creates an Gui element in the helper menu.
	local workWidthGroup = AIParameterGroup.new(g_i18n:getText("work width"))
	workWidthGroup:addParameter(self.workWidthParameter)
	--- Adds this gui element to the gui table.
	table.insert(self.groupedParameters, workWidthGroup)
	return self
end

--- Registers additional jobs.
function AIJobFieldWorkCp.registerJob(self)
	self:registerJobType("FIELDWORK_CP", "FIELDWORK_CP", AIJobFieldWorkCp)
end

AIJobTypeManager.loadMapData = Utils.appendedFunction(AIJobTypeManager.loadMapData,AIJobFieldWorkCp.registerJob)
