--- This spec is only for overwriting giants function of the AIFieldWorker.
---@class CpAIFieldWorkerExtended
CpAIFieldWorkerExtended = {}

CpAIFieldWorkerExtended.MOD_NAME = g_currentModName
CpAIFieldWorkerExtended.NAME = ".cpAIFieldWorkerExtended"
CpAIFieldWorkerExtended.SPEC_NAME = CpAIFieldWorkerExtended.MOD_NAME .. CpAIFieldWorkerExtended.NAME
CpAIFieldWorkerExtended.KEY = "."..CpAIFieldWorkerExtended.MOD_NAME..CpAIFieldWorkerExtended.NAME .. "."

function CpAIFieldWorkerExtended.initSpecialization()
    local schema = Vehicle.xmlSchemaSavegame
end

function CpAIFieldWorkerExtended.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(AIFieldWorker, specializations) 
end

function CpAIFieldWorkerExtended.register(typeManager,typeName,specializations)
	if CpAIFieldWorkerExtended.prerequisitesPresent(specializations) then
		typeManager:addSpecialization(typeName, CpAIFieldWorkerExtended.SPEC_NAME)	
	end
end

function CpAIFieldWorkerExtended.registerEventListeners(vehicleType)	
--	SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", CpAIFieldWorkerExtended)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", CpAIFieldWorkerExtended)
    SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", CpAIFieldWorkerExtended)
--    SpecializationUtil.registerEventListener(vehicleType, "getStartAIJobText", CpAIFieldWorkerExtended)
    SpecializationUtil.registerEventListener(vehicleType, "onEnterVehicle", CpAIFieldWorkerExtended)
    SpecializationUtil.registerEventListener(vehicleType, "onLeaveVehicle", CpAIFieldWorkerExtended)

end

function CpAIFieldWorkerExtended.registerFunctions(vehicleType)
  --  SpecializationUtil.registerFunction(vehicleType, 'getReverseDrivingDirectionNode', CpAIFieldWorkerExtended.getReverseDrivingDirectionNode)
end

function CpAIFieldWorkerExtended.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getStartAIJobText", CpAIFieldWorkerExtended.getStartAIJobText)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, 'getStartableAIJob', CpAIFieldWorkerExtended.getStartableAIJob)
end
------------------------------------------------------------------------------------------------------------------------
--- Event listeners
---------------------------------------------------------------------------------------------------------------------------
function CpAIFieldWorkerExtended:onLoad(savegame)
	--- Register the spec: spec_CpAIFieldWorkerExtended
    self.spec_cpAIFieldWorkerExtended = self["spec_" .. CpAIFieldWorkerExtended.SPEC_NAME]
    local spec = self.spec_cpAIFieldWorkerExtended
    spec.cpJob = g_currentMission.aiJobTypeManager:createJob(AIJobType.FIELDWORK_CP)
end

function CpAIFieldWorkerExtended:onPostLoad(savegame)

end

function CpAIFieldWorkerExtended:saveToXMLFile(xmlFile, baseKey, usedModNames)
   
end

function CpAIFieldWorkerExtended:onEnterVehicle(isControlling)
    
end

function CpAIFieldWorkerExtended:onLeaveVehicle(isControlling)
   
end

--- Makes sure the "H" key for helper starting, starts the cp job and not the giants default job.
function CpAIFieldWorkerExtended:getStartableAIJob(superFunc,...)
    if self:hasCpCourse() then 
        self:updateAIFieldWorkerImplementData()
        if self:getCanStartFieldWork() then
            local spec = self.spec_cpAIFieldWorkerExtended
            local fieldJob = spec.cpJob
            fieldJob:applyCurrentState(self, g_currentMission, g_currentMission.player.farmId, true)
            fieldJob:setValues()
            local success = fieldJob:validate(false)
            if success then
                return fieldJob
            end
        end
    end
    return superFunc(self,...)
end

function CpAIFieldWorkerExtended:getStartAIJobText(superFunc,...)
    local text = superFunc(self,...)
    local job = self:getStartableAIJob()
	if job and job:isa(AIJobFieldWorkCp) and self:getHasStartableAIJob() then
        return text.."(CP)"
    end
    return text
end