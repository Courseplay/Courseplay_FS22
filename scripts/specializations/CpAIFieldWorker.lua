--- This spec is only for overwriting giants function of the AIFieldWorker.
---@class CpAIFieldWorker
CpAIFieldWorker = {}

CpAIFieldWorker.MOD_NAME = g_currentModName
CpAIFieldWorker.NAME = ".cpAIFieldWorker"
CpAIFieldWorker.SPEC_NAME = CpAIFieldWorker.MOD_NAME .. CpAIFieldWorker.NAME
CpAIFieldWorker.KEY = "."..CpAIFieldWorker.MOD_NAME..CpAIFieldWorker.NAME .. "."

function CpAIFieldWorker.initSpecialization()
    local schema = Vehicle.xmlSchemaSavegame
end

function CpAIFieldWorker.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(AIFieldWorker, specializations) 
end

function CpAIFieldWorker.register(typeManager,typeName,specializations)
	if CpAIFieldWorker.prerequisitesPresent(specializations) then
		typeManager:addSpecialization(typeName, CpAIFieldWorker.SPEC_NAME)
	end
end

function CpAIFieldWorker.registerEventListeners(vehicleType)
--	SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", CpAIFieldWorker)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", CpAIFieldWorker)
    SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", CpAIFieldWorker)
--    SpecializationUtil.registerEventListener(vehicleType, "getStartAIJobText", CpAIFieldWorker)
    SpecializationUtil.registerEventListener(vehicleType, "onEnterVehicle", CpAIFieldWorker)
    SpecializationUtil.registerEventListener(vehicleType, "onLeaveVehicle", CpAIFieldWorker)

end

function CpAIFieldWorker.registerFunctions(vehicleType)
  --  SpecializationUtil.registerFunction(vehicleType, 'getReverseDrivingDirectionNode', CpAIFieldWorker.getReverseDrivingDirectionNode)
end

function CpAIFieldWorker.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getStartAIJobText", CpAIFieldWorker.getStartAIJobText)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, 'getStartableAIJob', CpAIFieldWorker.getStartableAIJob)
end
------------------------------------------------------------------------------------------------------------------------
--- Event listeners
---------------------------------------------------------------------------------------------------------------------------
function CpAIFieldWorker:onLoad(savegame)
	--- Register the spec: spec_CpAIFieldWorker
    self.spec_cpAIFieldWorker = self["spec_" .. CpAIFieldWorker.SPEC_NAME]
    local spec = self.spec_cpAIFieldWorker
    spec.cpJob = g_currentMission.aiJobTypeManager:createJob(AIJobType.FIELDWORK_CP)
end

function CpAIFieldWorker:onPostLoad(savegame)

end

function CpAIFieldWorker:saveToXMLFile(xmlFile, baseKey, usedModNames)
   
end

function CpAIFieldWorker:onEnterVehicle(isControlling)
    
end

function CpAIFieldWorker:onLeaveVehicle(isControlling)
   
end

--- Makes sure the "H" key for helper starting, starts the cp job and not the giants default job.
function CpAIFieldWorker:getStartableAIJob(superFunc,...)
    if self:hasCpCourse() then
        self:updateAIFieldWorkerImplementData()
        if self:getCanStartFieldWork() then
            local spec = self.spec_cpAIFieldWorker
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

function CpAIFieldWorker:getStartAIJobText(superFunc,...)
    local text = superFunc(self,...)
	if self:getHasStartableAIJob() and self:hasCpCourse() then
        return text.."(CP)"
    end
    return text
end