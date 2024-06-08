--- This spec is only for overwriting giants function of the AIFieldWorker.
local modName = CpAIImplement and CpAIImplement.MOD_NAME -- for reload

---@class CpAIImplement
CpAIImplement = {}

CpAIImplement.MOD_NAME = g_currentModName or modName
CpAIImplement.NAME = ".cpAIImplement"
CpAIImplement.SPEC_NAME = CpAIImplement.MOD_NAME .. CpAIImplement.NAME
CpAIImplement.KEY = "."..CpAIImplement.MOD_NAME..CpAIImplement.NAME
CpAIImplement.AIIMPLEMENT_MT = {}
CpAIImplement.JOB_TABLES_MT = {
    FIELDWORK = {},
    BALE_LOADER = {},
    SILO_LOADER = {},
    COMBINE_UNLOADER = {},
    BUNKER_SILO = {}
}

CpAIImplement.SPECS = {
    FIELDWORK = {
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
    },
    BALE_LOADER = {
        "spec_baleWrapper",
        "spec_baleLoader",
        "spec_aPalletAutoLoader",
    }
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
    SpecializationUtil.registerOverwrittenFunction(vehicleType, 'addVehicleToAIImplementList', CpAIImplement.addVehicleToAIImplementList)
    
end

function CpAIImplement.registerEvents(vehicleType)
    -- SpecializationUtil.registerEvent(vehicleType, "onCpWrapTypeSettingChanged")   
end
function CpAIImplement:onLoad(savegame)
	--- Register the spec: spec_cpAIImplement
    self.spec_cpAIImplement = self["spec_" .. CpAIImplement.SPEC_NAME]
    local spec = self.spec_cpAIImplement
end

function CpAIImplement:getCanImplementBeUsedForAI(superFunc, list)
    if not list then 
        return superFunc(self)
    end
    if self["spec_attachable"] then 
        if self["spec_attachable"].detachingInProgress then
            return false
        end
    end

    if getmetatable(list) == CpAIImplement.JOB_TABLES_MT.FIELDWORK then 
        CpUtil.debugImplement(CpDebug.DBG_IMPLEMENTS, self, "Check if the implement can be used for fieldwork ...")
        local found, foundSpec = false, "---"
        for _, value in ipairs(CpAIImplement.SPECS.FIELDWORK) do
            if self[value] then 
                foundSpec = value
                found = true
            end
        end
        if self["spec_universalAutoload"] and self["spec_universalAutoload"].isAutoloadEnabled then 
            foundSpec = "spec_universalAutoload"
            found = true
        end

        --- Checks if cutter on an trailer is attached.
        if self["spec_dynamicMountAttacher"] and 
            next(self["spec_dynamicMountAttacher"].dynamicMountedObjects) ~= nil and 
            next(self["spec_dynamicMountAttacher"].dynamicMountedObjects)["spec_cutter"] ~= nil then 

            foundSpec = "spec_dynamicMountAttacher"
            found = true
        end
        if found then 
            return true
        end
    elseif getmetatable(list) == CpAIImplement.JOB_TABLES_MT.BALE_LOADER then
        CpUtil.debugImplement(CpDebug.DBG_IMPLEMENTS, self, "Check if the implement can be used for the baleloader ...")
        local found, foundSpec = false, "---"
        for _, value in ipairs(CpAIImplement.SPECS.BALE_LOADER) do
            if self[value] then 
                found = true
                foundSpec = value
            end
        end
        if self["spec_baleWrapper"] and self["spec_baler"] then 
            --- Disabled!
            return false
        end
        if self["spec_universalAutoload"] and self["spec_universalAutoload"].isAutoloadEnabled then 
            foundSpec = "spec_universalAutoload"
            found = true
        end
        if found then 
            CpUtil.debugImplement(CpDebug.DBG_IMPLEMENTS, self, "Found valid spec: %s", foundSpec)
            return true
        end

    elseif getmetatable(list) == CpAIImplement.JOB_TABLES_MT.BUNKER_SILO then
        CpUtil.debugImplement(CpDebug.DBG_IMPLEMENTS, self, "Check if the implement can be used for the bunker silo mode ...")
        return true
    elseif getmetatable(list) == CpAIImplement.JOB_TABLES_MT.SILO_LOADER then
        CpUtil.debugImplement(CpDebug.DBG_IMPLEMENTS, self, "Check if the implement can be used for the silo loader ...")
        local found, foundSpec = false, "---"
        if self["spec_shovel"] then
            foundSpec = "spec_shovel"
            found = true   
        end
        if found then 
            return true
        end
    elseif getmetatable(list) == CpAIImplement.JOB_TABLES_MT.COMBINE_UNLOADER then
        CpUtil.debugImplement(CpDebug.DBG_IMPLEMENTS, self, "Check if the implement can be used for the combine unloader ...")
        local found, foundSpec = false, "---"
        if self["spec_trailer"] and 
            self["spec_dischargeable"] and
            #self["spec_dischargeable"].dischargeNodes > 0 then 
            foundSpec = "spec_shovel"
            found = true   
        end
        if found then 
            return true
        end
    end
    return false
end

function CpAIImplement:addVehicleToAIImplementList(superFunc, list)
    if self:getCanImplementBeUsedForAI(list) then
        table.insert(list, {
            object = self
        })
    end
    if self["spec_attacherJoints"] then 
        --AttacherJoints.addVehicleToAIImplementList(self, function () end, list)
        for _, implement in pairs(self:getAttachedImplements()) do
            local object = implement.object

            if object ~= nil and object.addVehicleToAIImplementList ~= nil then
                object:addVehicleToAIImplementList(list)
            end
        end
    end
end
