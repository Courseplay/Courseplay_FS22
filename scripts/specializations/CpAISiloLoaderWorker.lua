
local modName = CpAISiloLoaderWorker and CpAISiloLoaderWorker.MOD_NAME -- for reload

---@class CpAISiloLoaderWorker
CpAISiloLoaderWorker = {}

CpAISiloLoaderWorker.startText = g_i18n:getText("CP_jobParameters_startAt_siloLoader")

CpAISiloLoaderWorker.MOD_NAME = g_currentModName or modName
CpAISiloLoaderWorker.NAME = ".cpAISiloLoaderWorker"
CpAISiloLoaderWorker.SPEC_NAME = CpAISiloLoaderWorker.MOD_NAME .. CpAISiloLoaderWorker.NAME
CpAISiloLoaderWorker.KEY = "." .. CpAISiloLoaderWorker.MOD_NAME .. CpAISiloLoaderWorker.NAME

function CpAISiloLoaderWorker.initSpecialization()
    local schema = Vehicle.xmlSchemaSavegame
    local key = "vehicles.vehicle(?)" .. CpAISiloLoaderWorker.KEY
    CpJobParameters.registerXmlSchema(schema, key..".cpJob")
end

function CpAISiloLoaderWorker.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(CpAIWorker, specializations) 
end

function CpAISiloLoaderWorker.register(typeManager,typeName,specializations)
	if CpAISiloLoaderWorker.prerequisitesPresent(specializations) then
		typeManager:addSpecialization(typeName, CpAISiloLoaderWorker.SPEC_NAME)
	end
end

function CpAISiloLoaderWorker.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, 'onLoad', CpAISiloLoaderWorker)
    SpecializationUtil.registerEventListener(vehicleType, 'onUpdate', CpAISiloLoaderWorker)
    SpecializationUtil.registerEventListener(vehicleType, 'onLoadFinished', CpAISiloLoaderWorker)
end

function CpAISiloLoaderWorker.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "startCpSiloLoaderWorker", CpAISiloLoaderWorker.startCpSiloLoaderWorker)
    SpecializationUtil.registerFunction(vehicleType, "stopCpSiloLoaderWorker", CpAISiloLoaderWorker.stopCpSiloLoaderWorker)

    SpecializationUtil.registerFunction(vehicleType, "getCanStartCpSiloLoaderWorker", CpAISiloLoaderWorker.getCanStartCpSiloLoaderWorker)
    SpecializationUtil.registerFunction(vehicleType, "getCpSiloLoaderWorkerJobParameters", CpAISiloLoaderWorker.getCpSiloLoaderWorkerJobParameters)
    
    SpecializationUtil.registerFunction(vehicleType, "applyCpSiloLoaderWorkerJobParameters", CpAISiloLoaderWorker.applyCpSiloLoaderWorkerJobParameters)
    SpecializationUtil.registerFunction(vehicleType, "getCpSiloLoaderWorkerJob", CpAISiloLoaderWorker.getCpSiloLoaderWorkerJob)
end

function CpAISiloLoaderWorker.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, 'getCanStartCp', CpAISiloLoaderWorker.getCanStartCp)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, 'getCpStartableJob', CpAISiloLoaderWorker.getCpStartableJob)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, 'getCpStartText', CpAISiloLoaderWorker.getCpStartText)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getCpDriveStrategy", CpAISiloLoaderWorker.getCpDriveStrategy)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, 'startCpAtFirstWp', CpAISiloLoaderWorker.startCpAtFirstWp)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, 'startCpAtLastWp', CpAISiloLoaderWorker.startCpAtLastWp)
end
------------------------------------------------------------------------------------------------------------------------
--- Event listeners
---------------------------------------------------------------------------------------------------------------------------
function CpAISiloLoaderWorker:onLoad(savegame)
	--- Register the spec: spec_CpAIBunkerSiloWorker
    self.spec_cpAISiloLoaderWorker = self["spec_" .. CpAISiloLoaderWorker.SPEC_NAME]
    local spec = self.spec_cpAISiloLoaderWorker
    --- This job is for starting the driving with a key bind or the mini gui.
    spec.cpJob = g_currentMission.aiJobTypeManager:createJob(AIJobType.SILO_LOADER_CP)
    spec.cpJob:setVehicle(self, true)
end


function CpAISiloLoaderWorker:onLoadFinished(savegame)
    local spec = self.spec_cpAISiloLoaderWorker
    if savegame ~= nil then 
        spec.cpJob:loadFromXMLFile(savegame.xmlFile, savegame.key.. CpAISiloLoaderWorker.KEY..".cpJob")
    end
end

function CpAISiloLoaderWorker:saveToXMLFile(xmlFile, baseKey, usedModNames)
    local spec = self.spec_cpAISiloLoaderWorker
    spec.cpJob:saveToXMLFile(xmlFile, baseKey.. ".cpJob")
end

function CpAISiloLoaderWorker:onUpdate(dt)
    local spec = self.spec_cpAISiloLoaderWorker
    if spec.siloLoaderStrategy and self.isServer then
        spec.siloLoaderStrategy:update(dt)
        if g_updateLoopIndex % 4 == 0 then
            local tX, tZ, moveForwards, maxSpeed =  spec.siloLoaderStrategy:getDriveData(dt)

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

function CpAISiloLoaderWorker:getCpDriveStrategy(superFunc)
    return superFunc(self) or self.spec_cpAISiloLoaderWorker.siloLoaderStrategy
end

--- Is the bunker silo allowed?
function CpAISiloLoaderWorker:getCanStartCpSiloLoaderWorker()
	return not self:getCanStartCpFieldWork() and not self:getCanStartCpBaleFinder() and not self:hasCpCourse() 
        and not self:getCanStartCpCombineUnloader() and AIUtil.hasChildVehicleWithSpecialization(self, Shovel) 
        and AIUtil.hasChildVehicleWithSpecialization(self, ConveyorBelt)
end

function CpAISiloLoaderWorker:getCanStartCp(superFunc)
    return superFunc(self) or self:getCanStartCpSiloLoaderWorker()
end

function CpAISiloLoaderWorker:getCpStartableJob(superFunc, isStartedByHud)
    local spec = self.spec_cpAISiloLoaderWorker
	return superFunc(self) or self:getCanStartCpSiloLoaderWorker() and spec.cpJob
end

function CpAISiloLoaderWorker:getCpStartText(superFunc)
	local text = superFunc and superFunc(self)
	return text~="" and text or self:getCanStartCpSiloLoaderWorker() and CpAISiloLoaderWorker.startText
end

function CpAISiloLoaderWorker:getCpSiloLoaderWorkerJobParameters()
    local spec = self.spec_cpAISiloLoaderWorker
    return spec.cpJob:getCpJobParameters()
end

function CpAISiloLoaderWorker:applyCpSiloLoaderWorkerJobParameters(job)
    local spec = self.spec_cpAISiloLoaderWorker
    spec.cpJob:getCpJobParameters():validateSettings()
    spec.cpJob:copyFrom(job)
end

function CpAISiloLoaderWorker:getCpSiloLoaderWorkerJob()
    local spec = self.spec_cpAISiloLoaderWorker
    return spec.cpJob
end


--- Starts the cp driver at the first waypoint.
function CpAISiloLoaderWorker:startCpAtFirstWp(superFunc, ...)
    if not superFunc(self, ...) then 
        if self:getCanStartCpSiloLoaderWorker() then 
            local spec = self.spec_cpAISiloLoaderWorker
            spec.cpJob:applyCurrentState(self, g_currentMission, g_currentMission.player.farmId, true)
            spec.cpJob:setValues()
            local success = spec.cpJob:validate(false)
            if success then
                g_client:getServerConnection():sendEvent(AIJobStartRequestEvent.new(spec.cpJob, self:getOwnerFarmId()))
                return true
            end
        end
    else 
        return true
    end
end

--- Starts the cp driver at the last driven waypoint.
function CpAISiloLoaderWorker:startCpAtLastWp(superFunc, ...)
    if not superFunc(self, ...) then 
        if self:getCanStartCpSiloLoaderWorker() then 
            local spec = self.spec_cpAISiloLoaderWorker
            spec.cpJob:applyCurrentState(self, g_currentMission, g_currentMission.player.farmId, true)
            spec.cpJob:setValues()
            local success = spec.cpJob:validate(false)
            if success then
                g_client:getServerConnection():sendEvent(AIJobStartRequestEvent.new(spec.cpJob, self:getOwnerFarmId()))
                return true
            end
        end
    else 
        return true
    end
end

--- Custom version of AIFieldWorker:startFieldWorker()
function CpAISiloLoaderWorker:startCpSiloLoaderWorker(silo, jobParameters)
    local spec = self.spec_cpAISiloLoaderWorker
    if self.isServer then 
        spec.siloLoaderStrategy = AIDriveStrategySiloLoader.new()
        spec.siloLoaderStrategy:setSilo(silo)
        -- this also starts the strategy
        spec.siloLoaderStrategy:setAIVehicle(self, jobParameters)
    end
end

function CpAISiloLoaderWorker:stopCpSiloLoaderWorker()
    local spec = self.spec_cpAISiloLoaderWorker
    if spec.siloLoaderStrategy then 
        spec.siloLoaderStrategy:delete()
        spec.siloLoaderStrategy = nil
    end
end