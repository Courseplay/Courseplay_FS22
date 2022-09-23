--- This spec is only for overwriting giants function of the AIFieldWorker.
local modName = CpAIBaleFinder and CpAIBaleFinder.MOD_NAME -- for reload

---@class CpAIBaleFinder
CpAIBaleFinder = {}

CpAIBaleFinder.startText = g_i18n:getText("CP_jobParameters_startAt_bales")

CpAIBaleFinder.MOD_NAME = g_currentModName or modName
CpAIBaleFinder.NAME = ".cpAIBaleFinder"
CpAIBaleFinder.SPEC_NAME = CpAIBaleFinder.MOD_NAME .. CpAIBaleFinder.NAME
CpAIBaleFinder.KEY = "."..CpAIBaleFinder.MOD_NAME..CpAIBaleFinder.NAME

function CpAIBaleFinder.initSpecialization()
    local schema = Vehicle.xmlSchemaSavegame
    local key = "vehicles.vehicle(?)" .. CpAIBaleFinder.KEY
    CpJobParameters.registerXmlSchema(schema, key..".cpJob")
    CpJobParameters.registerXmlSchema(schema, key..".cpJobStartAtLastWp")
end

function CpAIBaleFinder.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(CpAIFieldWorker, specializations) 
end

function CpAIBaleFinder.register(typeManager,typeName,specializations)
	if CpAIBaleFinder.prerequisitesPresent(specializations) then
		typeManager:addSpecialization(typeName, CpAIBaleFinder.SPEC_NAME)
	end
end

function CpAIBaleFinder.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, 'onLoad', CpAIBaleFinder)
    SpecializationUtil.registerEventListener(vehicleType, 'onLoadFinished', CpAIBaleFinder)
end

function CpAIBaleFinder.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "startCpBaleFinder", CpAIBaleFinder.startCpBaleFinder)

    SpecializationUtil.registerFunction(vehicleType, "getCanStartCpBaleFinder", CpAIBaleFinder.getCanStartCpBaleFinder)
    SpecializationUtil.registerFunction(vehicleType, "getCpBaleFinderJobParameters", CpAIBaleFinder.getCpBaleFinderJobParameters)
end

function CpAIBaleFinder.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, 'getCanStartCp', CpAIBaleFinder.getCanStartCp)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, 'getCpStartableJob', CpAIBaleFinder.getCpStartableJob)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, 'getCpStartText', CpAIBaleFinder.getCpStartText)

    SpecializationUtil.registerOverwrittenFunction(vehicleType, 'startCpAtFirstWp', CpAIBaleFinder.startCpAtFirstWp)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, 'startCpAtLastWp', CpAIBaleFinder.startCpAtLastWp)
end
------------------------------------------------------------------------------------------------------------------------
--- Event listeners
---------------------------------------------------------------------------------------------------------------------------
function CpAIBaleFinder:onLoad(savegame)
	--- Register the spec: spec_CpAIBaleFinder
    self.spec_cpAIBaleFinder = self["spec_" .. CpAIBaleFinder.SPEC_NAME]
    local spec = self.spec_cpAIBaleFinder
    --- This job is for starting the driving with a key bind or the mini gui.
    spec.cpJob = g_currentMission.aiJobTypeManager:createJob(AIJobType.BALE_FINDER_CP)
    spec.cpJob:setVehicle(self)
    spec.cpJobStartAtLastWp = g_currentMission.aiJobTypeManager:createJob(AIJobType.BALE_FINDER_CP)
end

function CpAIBaleFinder:onLoadFinished(savegame)
    local spec = self.spec_cpAIBaleFinder
    if savegame ~= nil then 
        spec.cpJob:getCpJobParameters():loadFromXMLFile(savegame.xmlFile, savegame.key.. CpAIBaleFinder.KEY..".cpJob")
        spec.cpJobStartAtLastWp:getCpJobParameters():loadFromXMLFile(savegame.xmlFile, savegame.key.. CpAIFieldWorker.KEY..".cpJobStartAtLastWp")
    end
end

function CpAIBaleFinder:saveToXMLFile(xmlFile, baseKey, usedModNames)
    local spec = self.spec_cpAIBaleFinder
    spec.cpJob:getCpJobParameters():saveToXMLFile(xmlFile, baseKey.. ".cpJob")
    spec.cpJobStartAtLastWp:getCpJobParameters():saveToXMLFile(xmlFile, baseKey.. ".cpJobStartAtLastWp")
end

function CpAIBaleFinder:getCpBaleFinderJobParameters()
    local spec = self.spec_cpAIBaleFinder
    return spec.cpJob:getCpJobParameters() 
end

function CpAIBaleFinder:getCpDriveStrategy(superFunc)
    return superFunc(self) or self.spec_cpAIBaleFinder.driveStrategy
end

--- Is the bale finder allowed?
function CpAIBaleFinder:getCanStartCpBaleFinder()
	return (AIUtil.hasImplementWithSpecialization(self, BaleWrapper) and not AIUtil.hasImplementWithSpecialization(self, Baler)) or
			AIUtil.hasImplementWithSpecialization(self, BaleLoader) or 
            --- FS22_aPalletAutoLoader from Achimobil: https://bitbucket.org/Achimobil79/ls22_palletautoloader/src/master/
            AIUtil.hasChildVehicleWithSpecialization(self, nil, "spec_aPalletAutoLoader") or 
            --- FS22_UniversalAutoload form loki79uk: https://github.com/loki79uk/FS22_UniversalAutoload
            AIUtil.hasValidUniversalTrailerAttached(self)
end

function CpAIBaleFinder:getCanStartCp(superFunc)
    return superFunc(self) or self:getCanStartCpBaleFinder() and not self:getIsCpCourseRecorderActive()
end

--- Only use the bale finder, if the cp field work job is not possible.
function CpAIBaleFinder:getCpStartableJob(superFunc)
    local spec = self.spec_cpAIBaleFinder
	return superFunc(self) or self:getCanStartCpBaleFinder() and spec.cpJob
end

function CpAIBaleFinder:getCpStartText(superFunc)
	local text = superFunc and superFunc(self)
	return text~="" and text or self:getCanStartCpBaleFinder() and CpAIBaleFinder.startText
end


--- Starts the cp driver at the first waypoint.
function CpAIBaleFinder:startCpAtFirstWp(superFunc)
    if not superFunc(self) then 
        if self:getCanStartCpBaleFinder() then 
            local spec = self.spec_cpAIBaleFinder
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
function CpAIBaleFinder:startCpAtLastWp(superFunc)
    if not superFunc(self) then 
        if self:getCanStartCpBaleFinder() then 
            local spec = self.spec_cpAIBaleFinder
            --- Applies the bale wrap type set in the hud, so ad can start with the correct type.
            --- TODO: This should only be applied, if the driver was started for the first time by ad and not every time.
            spec.cpJobStartAtLastWp:getCpJobParameters().baleWrapType:setValue(spec.cpJob:getCpJobParameters().baleWrapType:getValue())
            spec.cpJobStartAtLastWp:applyCurrentState(self, g_currentMission, g_currentMission.player.farmId, true)
            spec.cpJobStartAtLastWp:setValues()
            local success = spec.cpJobStartAtLastWp:validate(false)
            if success then
                g_client:getServerConnection():sendEvent(AIJobStartRequestEvent.new(spec.cpJobStartAtLastWp, self:getOwnerFarmId()))
                return true
            end
        end
    else 
        return true
    end
end

--- Custom version of AIFieldWorker:startFieldWorker()
function CpAIBaleFinder:startCpBaleFinder(fieldPolygon, jobParameters)
    --- Calls the giants startFieldWorker function.
    self:startFieldWorker()
    if self.isServer then 
        --- Replaces drive strategies.
        CpAIBaleFinder.replaceDriveStrategies(self, fieldPolygon, jobParameters)

        --- Remembers the last bale warp type setting value that was used.
        local spec = self.spec_cpAIBaleFinder
        spec.cpJobStartAtLastWp:getCpJobParameters().baleWrapType:setValue(jobParameters.baleWrapType:getValue())
    end
end

-- We replace the Giants AIDriveStrategyStraight with our AIDriveStrategyFieldWorkCourse  to take care of
-- field work.
function CpAIBaleFinder:replaceDriveStrategies(fieldPolygon, jobParameters)
    CpUtil.debugVehicle(CpDebug.DBG_FIELDWORK, self, 'This is a CP field work job, start the CP AI driver, setting up drive strategies...')
    local spec = self.spec_aiFieldWorker
    if spec.driveStrategies ~= nil then
        for i = #spec.driveStrategies, 1, -1 do
            spec.driveStrategies[i]:delete()
            table.remove(spec.driveStrategies, i)
        end

        spec.driveStrategies = {}
    end
	CpUtil.debugVehicle(CpDebug.DBG_FIELDWORK, self, 'Bale collect/wrap job, install CP drive strategy for it')
    local cpDriveStrategy = AIDriveStrategyFindBales.new()
    cpDriveStrategy:setFieldPolygon(fieldPolygon)
    cpDriveStrategy:setJobParameterValues(jobParameters)
    cpDriveStrategy:setAIVehicle(self)
    self.spec_cpAIFieldWorker.driveStrategy = cpDriveStrategy
    --- TODO: Correctly implement this strategy.
	local driveStrategyCollision = AIDriveStrategyCollision.new(cpDriveStrategy)
    driveStrategyCollision:setAIVehicle(self)
    table.insert(spec.driveStrategies, driveStrategyCollision)
    --- Only the last driving strategy can stop the helper, while it is running.
    table.insert(spec.driveStrategies, cpDriveStrategy)
end
