--- This spec is only for overwriting giants function of the AIFieldWorker.
local modName = CpAIBunkerSiloWorker and CpAIBunkerSiloWorker.MOD_NAME -- for reload

---@class CpAIBunkerSiloWorker
CpAIBunkerSiloWorker = {}

CpAIBunkerSiloWorker.startText = g_i18n:getText("CP_jobParameters_startAt_bunkerSilo")

CpAIBunkerSiloWorker.MOD_NAME = g_currentModName or modName
CpAIBunkerSiloWorker.NAME = ".cpAIBunkerSiloWorker"
CpAIBunkerSiloWorker.SPEC_NAME = CpAIBunkerSiloWorker.MOD_NAME .. CpAIBunkerSiloWorker.NAME
CpAIBunkerSiloWorker.KEY = "."..CpAIBunkerSiloWorker.MOD_NAME..CpAIBunkerSiloWorker.NAME .. "."

function CpAIBunkerSiloWorker.initSpecialization()
    local schema = Vehicle.xmlSchemaSavegame
end

function CpAIBunkerSiloWorker.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(CpAIFieldWorker, specializations) 
end

function CpAIBunkerSiloWorker.register(typeManager,typeName,specializations)
	if CpAIBunkerSiloWorker.prerequisitesPresent(specializations) then
		typeManager:addSpecialization(typeName, CpAIBunkerSiloWorker.SPEC_NAME)
	end
end

function CpAIBunkerSiloWorker.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, 'onLoad', CpAIBunkerSiloWorker)
    SpecializationUtil.registerEventListener(vehicleType, 'onUpdate', CpAIBunkerSiloWorker)
    SpecializationUtil.registerEventListener(vehicleType, 'onLoadFinished', CpAIBunkerSiloWorker)
end

function CpAIBunkerSiloWorker.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "startCpBunkerSiloWorker", CpAIBunkerSiloWorker.startCpBunkerSiloWorker)
    SpecializationUtil.registerFunction(vehicleType, "stopCpBunkerSiloWorker", CpAIBunkerSiloWorker.stopCpBunkerSiloWorker)

    SpecializationUtil.registerFunction(vehicleType, "getCanStartCpBunkerSiloWorker", CpAIBunkerSiloWorker.getCanStartCpBunkerSiloWorker)
    SpecializationUtil.registerFunction(vehicleType, "getCpBunkerSiloWorkerJobParameters", CpAIBunkerSiloWorker.getCpBunkerSiloWorkerJobParameters)
    
    SpecializationUtil.registerFunction(vehicleType, "applyCpBunkerSiloWorkerJobParameters", CpAIBunkerSiloWorker.applyCpBunkerSiloWorkerJobParameters)
    SpecializationUtil.registerFunction(vehicleType, "getCpBunkerSiloWorkerJob", CpAIBunkerSiloWorker.getCpBunkerSiloWorkerJob)
end

function CpAIBunkerSiloWorker.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, 'getCanStartCp', CpAIBunkerSiloWorker.getCanStartCp)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, 'getCpStartableJob', CpAIBunkerSiloWorker.getCpStartableJob)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, 'getCpStartText', CpAIBunkerSiloWorker.getCpStartText)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getCpDriveStrategy", CpAIBunkerSiloWorker.getCpDriveStrategy)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, 'startCpAtFirstWp', CpAIBunkerSiloWorker.startCpAtFirstWp)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, 'startCpAtLastWp', CpAIBunkerSiloWorker.startCpAtLastWp)
end
------------------------------------------------------------------------------------------------------------------------
--- Event listeners
---------------------------------------------------------------------------------------------------------------------------
function CpAIBunkerSiloWorker:onLoad(savegame)
	--- Register the spec: spec_CpAIBunkerSiloWorker
    self.spec_cpAIBunkerSiloWorker = self["spec_" .. CpAIBunkerSiloWorker.SPEC_NAME]
    local spec = self.spec_cpAIBunkerSiloWorker
    --- This job is for starting the driving with a key bind or the mini gui.
    spec.cpJob = g_currentMission.aiJobTypeManager:createJob(AIJobType.BUNKER_SILO_CP)
    spec.cpJob:setVehicle(self, true)
end


function CpAIBunkerSiloWorker:onLoadFinished(savegame)
    local spec = self.spec_cpAIBunkerSiloWorker
    if savegame ~= nil then 
        spec.cpJob:loadFromXMLFile(savegame.xmlFile, savegame.key.. CpAIBunkerSiloWorker.KEY..".cpJob")
    end
end

function CpAIBunkerSiloWorker:saveToXMLFile(xmlFile, baseKey, usedModNames)
    local spec = self.spec_cpAIBunkerSiloWorker
    spec.cpJob:saveToXMLFile(xmlFile, baseKey.. ".cpJob")
end

function CpAIBunkerSiloWorker:onUpdate(dt)
    local spec = self.spec_cpAIBunkerSiloWorker
    if spec.bunkerSiloStrategy and self.isServer then
        spec.bunkerSiloStrategy:update(dt)
        if g_updateLoopIndex % 4 == 0 then
            local tX, tZ, moveForwards, maxSpeed =  spec.bunkerSiloStrategy:getDriveData(dt)

            -- same as AIFieldWorker:updateAIFieldWorker(), do the actual driving
            local tY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, tX, 0, tZ)
            local pX, _, pZ = worldToLocal(self:getAISteeringNode(), tX, tY, tZ)

            if not moveForwards and self.spec_articulatedAxis ~= nil and
                    self.spec_articulatedAxis.aiRevereserNode ~= nil then
                pX, _, pZ = worldToLocal(self.spec_articulatedAxis.aiRevereserNode, tX, tY, tZ)
            end

            if not moveForwards and self:getAIReverserNode() ~= nil then
                pX, _, pZ = worldToLocal(self:getAIReverserNode(), tX, tY, tZ)
            end

            local acceleration = 1
            local isAllowedToDrive = maxSpeed ~= 0

            AIVehicleUtil.driveToPoint(self, dt, acceleration, isAllowedToDrive, moveForwards, pX, pZ, maxSpeed)
        end
    end
end

function CpAIBunkerSiloWorker:getCpDriveStrategy(superFunc)
    return superFunc(self) or self.spec_cpAIBunkerSiloWorker.bunkerSiloStrategy
end

--- Is the bunker silo allowed?
function CpAIBunkerSiloWorker:getCanStartCpBunkerSiloWorker()
	return not self:getCanStartCpFieldWork() and not self:getCanStartCpBaleFinder() and not self:hasCpCourse() and not self:getCanStartCpCombineUnloader()
end

function CpAIBunkerSiloWorker:getCanStartCp(superFunc)
    return superFunc(self) or self:getCanStartCpBunkerSiloWorker()
end

function CpAIBunkerSiloWorker:getCpStartableJob(superFunc)
    local spec = self.spec_cpAIBunkerSiloWorker
	return superFunc(self) or self:getCanStartCpBunkerSiloWorker() and spec.cpJob
end

function CpAIBunkerSiloWorker:getCpStartText(superFunc)
	local text = superFunc and superFunc(self)
	return text~="" and text or self:getCanStartCpBunkerSiloWorker() and CpAIBunkerSiloWorker.startText
end

function CpAIBunkerSiloWorker:getCpBunkerSiloWorkerJobParameters()
    local spec = self.spec_cpAIBunkerSiloWorker
    return spec.cpJob:getCpJobParameters()
end

function CpAIBunkerSiloWorker:applyCpBunkerSiloWorkerJobParameters(job)
    local spec = self.spec_cpAIBunkerSiloWorker
    spec.cpJob:getCpJobParameters():validateSettings()
    spec.cpJob:copyFrom(job)
end

function CpAIBunkerSiloWorker:getCpBunkerSiloWorkerJob()
    local spec = self.spec_cpAIBunkerSiloWorker
    return spec.cpJob
end


--- Starts the cp driver at the first waypoint.
function CpAIBunkerSiloWorker:startCpAtFirstWp(superFunc, ...)
    if not superFunc(self, ...) then 
        if self:getCanStartCpBunkerSiloWorker() then 
            local spec = self.spec_cpAIBunkerSiloWorker
            spec.cpJob:applyCurrentState(self, g_currentMission, g_currentMission.player.farmId, true)
            spec.cpJob:setValues()
            g_client:getServerConnection():sendEvent(AIJobStartRequestEvent.new(spec.cpJob, self:getOwnerFarmId()))
            return true
        end
    else 
        return true
    end
end

--- Starts the cp driver at the last driven waypoint.
function CpAIBunkerSiloWorker:startCpAtLastWp(superFunc, ...)
    if not superFunc(self, ...) and self:getCanStartCpBunkerSiloWorker() then 
        return self:startCpAtFirstWp()
    end
    return false
end

--- Custom version of AIFieldWorker:startFieldWorker()
function CpAIBunkerSiloWorker:startCpBunkerSiloWorker(silo, jobParameters)
    local spec = self.spec_cpAIBunkerSiloWorker
    if self.isServer then 
        spec.bunkerSiloStrategy = AIDriveStrategyBunkerSilo.new()
        spec.bunkerSiloStrategy:setSilo(silo)
        -- this also starts the strategy
        spec.bunkerSiloStrategy:setAIVehicle(self, jobParameters)
    end
end

function CpAIBunkerSiloWorker:stopCpBunkerSiloWorker()
    local spec = self.spec_cpAIBunkerSiloWorker
    if spec.bunkerSiloStrategy then 
        spec.bunkerSiloStrategy:delete()
        spec.bunkerSiloStrategy = nil
    end
end