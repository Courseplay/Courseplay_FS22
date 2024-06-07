--- This spec is only for overwriting giants function of the AIFieldWorker.
local modName = CpAIImplement and CpAIImplement.MOD_NAME -- for reload

---@class CpAIImplement
CpAIImplement = {}

CpAIImplement.MOD_NAME = g_currentModName or modName
CpAIImplement.NAME = ".cpAIImplement"
CpAIImplement.SPEC_NAME = CpAIImplement.MOD_NAME .. CpAIImplement.NAME
CpAIImplement.KEY = "."..CpAIImplement.MOD_NAME..CpAIImplement.NAME
CpAIImplement.AIIMPLEMENT_MT = {}

CpAIImplement.ADDITIONAL_SPECS = {
    "spec_baler",
    "spec_stonePicker",
    "spec_baleWrapper",
    "spec_baleLoader",
    "spec_forageWagon",
    "spec_cutter",
    "spec_vineCutter",
    "spec_vinePrepruner",
    "spec_plow",
    "spec_mower",
    "spec_pushHandTool",
    "spec_soilSampler",
    "spec_aPalletAutoLoader"
}


function CpAIImplement.initSpecialization()
    local schema = Vehicle.xmlSchemaSavegame
    local key = "vehicles.vehicle(?)" .. CpAIImplement.KEY
    CpJobParameters.registerXmlSchema(schema, key..".cpJob")
    CpJobParameters.registerXmlSchema(schema, key..".cpJobStartAtLastWp")
end

function CpAIImplement.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(AIImplement, specializations) 
end

function CpAIImplement.register(typeManager,typeName,specializations)
	if CpAIImplement.prerequisitesPresent(specializations) then
		typeManager:addSpecialization(typeName, CpAIImplement.SPEC_NAME)
	end
end

function CpAIImplement.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, 'onLoad', CpAIImplement)
    -- SpecializationUtil.registerEventListener(vehicleType, 'onLoadFinished', CpAIImplement)
    -- SpecializationUtil.registerEventListener(vehicleType, 'onReadStream', CpAIImplement)
    -- SpecializationUtil.registerEventListener(vehicleType, 'onWriteStream', CpAIImplement)
   
end

function CpAIImplement.registerFunctions(vehicleType)
    -- SpecializationUtil.registerFunction(vehicleType, "getCanStartCpBaleFinder", CpAIImplement.getCanStartCpBaleFinder)
   

end

function CpAIImplement.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, 'getCanImplementBeUsedForAI', CpAIImplement.getCanImplementBeUsedForAI)
    
end

function CpAIImplement.registerEvents(vehicleType)
    -- SpecializationUtil.registerEvent(vehicleType, "onCpWrapTypeSettingChanged")   
end
function CpAIImplement:onLoad(savegame)
	--- Register the spec: spec_cpAIImplement
    self.spec_cpAIImplement = self["spec_" .. CpAIImplement.SPEC_NAME]
    local spec = self.spec_cpAIImplement
end

function CpAIImplement:getCanImplementBeUsedForAI(superFunc, isCpJob)
    if isCpJob then 
        for _, value in ipairs(CpAIImplement.ADDITIONAL_SPECS) do
            if self[value] then 
                return true
            end
        end
        if AIUtil.hasValidUniversalTrailerAttached(self) then 
            return true
        end
        if AIUtil.hasCutterOnTrailerAttached(self) then 
            return true
        end
    end
    return superFunc(self)
end

function CpAIImplement:addVehicleToAIImplementList(superFunc, list)
    if self:getCanImplementBeUsedForAI(getmetatable(list) == CpAIImplement.AIIMPLEMENT_MT) then
        table.insert(list, {
            object = self
        })
    end
    superFunc(self, list)
end
AIImplement.addVehicleToAIImplementList = CpAIImplement.addVehicleToAIImplementList