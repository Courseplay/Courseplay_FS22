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

end

function CpAIFieldWorker.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getStartAIJobText", CpAIFieldWorker.getStartAIJobText)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, 'getStartableAIJob', CpAIFieldWorker.getStartableAIJob)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, 'updateAIFieldWorkerDriveStrategies', CpAIFieldWorker.updateAIFieldWorkerDriveStrategies)
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
    local lastJob = self:getLastJob()
    if lastJob and lastJob:isa(AIJobFieldWorkCp) then
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

-- We replace the Giants AIDriveStrategyStraight with our AIDriveStrategyFieldWorkCourse  to take care of
-- field work.
function CpAIFieldWorker:updateAIFieldWorkerDriveStrategies(superFunc, ...)
    local job = self:getJob()
    if not job:isa(AIJobFieldWorkCp) then
        CpUtil.debugVehicle(CpDebug.DBG_MODE_4, self, 'This is not a CP field work job, run the built-in helper...')
        return superFunc(self, ...)
    else
        CpUtil.debugVehicle(CpDebug.DBG_MODE_4, self, 'This is a CP field work job, setting up drive strategies...')
    end
    superFunc(self, ...)
    -- TODO: messing around with AIFieldWorker spec internals is not the best idea, should rather implement
    -- our own specialization
    local combineDriveStrategyIndex
    for i, strategy in ipairs(self.spec_aiFieldWorker.driveStrategies) do
        if strategy.getDriveStraightData then
            self.spec_aiFieldWorker.driveStrategies[i]:delete()
            local cpDriveStrategy
            if AIUtil.getImplementOrVehicleWithSpecialization(self, Combine) then
                cpDriveStrategy = AIDriveStrategyCombineCourse.new()
                CpUtil.debugVehicle(CpDebug.DBG_MODE_4, self, 'Replacing fieldwork helper drive strategy with AIDriveStrategyCombineCourse')
            elseif AIUtil.getImplementWithSpecialization(self, Plow) then
                cpDriveStrategy = AIDriveStrategyPlowCourse.new()
                CpUtil.debugVehicle(CpDebug.DBG_MODE_4, self, 'Replacing fieldwork helper drive strategy with AIDriveStrategyPlowCourse')
            else
                cpDriveStrategy = AIDriveStrategyFieldWorkCourse.new()
                CpUtil.debugVehicle(CpDebug.DBG_MODE_4, self, 'Replacing fieldwork helper drive strategy with AIDriveStrategyFieldWorkCourse')
            end
            cpDriveStrategy:setAIVehicle(self)
            self.spec_aiFieldWorker.driveStrategies[i] = cpDriveStrategy
            return
        end
        if strategy.combines then
            self.spec_aiFieldWorker.driveStrategies[i]:delete()
            CpUtil.debugVehicle(CpDebug.DBG_MODE_4, self, 'Removing fieldwork helper Giants combine drive strategy')
            combineDriveStrategyIndex = i
        end
    end
    if combineDriveStrategyIndex then
        table.remove(self.spec_cpAIFieldWorker.driveStrategies, combineDriveStrategyIndex)
    end
end