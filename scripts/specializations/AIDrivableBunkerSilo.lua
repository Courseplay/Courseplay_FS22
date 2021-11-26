
---@class AIDrivableBunkerSilo
AIDrivableBunkerSilo = {
	DEACTIVATED = 0,
	LOADING = 1,
	TRANSPORT = 2,
	PRE_UNLOAD = 3,
	UNLOADING = 4,
	LOADING_SHOVEL_ANGLE = 90,
	TRANSPORT_SHOVEL_ANGLE = 80
}
AIDrivableBunkerSilo.MOD_NAME = g_currentModName

function AIDrivableBunkerSilo.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(AIDrivable, specializations) 
end

function AIDrivableBunkerSilo.registerEventListeners(vehicleType)	
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", AIDrivableBunkerSilo)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdate", AIDrivableBunkerSilo)
end

function AIDrivableBunkerSilo.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "setShovelState", AIDrivableBunkerSilo.setShovelState)
    SpecializationUtil.registerFunction(vehicleType, "resetShovelState", AIDrivableBunkerSilo.resetShovelState)
	SpecializationUtil.registerFunction(vehicleType, "setupAIDrivableBunkerSilo", AIDrivableBunkerSilo.setupAIDrivableBunkerSilo)
	SpecializationUtil.registerFunction(vehicleType, "isAIDrivableBunkerSiloDirty", AIDrivableBunkerSilo.isAIDrivableBunkerSiloDirty)
end

function AIDrivableBunkerSilo.registerOverwrittenFunctions(vehicleType)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "aiBlock", AIDrivableBunkerSilo.aiBlock)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "aiContinue", AIDrivableBunkerSilo.aiContinue)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getStartableAIJob", AIDrivableBunkerSilo.getStartableAIJob)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getHasStartableAIJob", AIDrivableBunkerSilo.getHasStartableAIJob)
end

function AIDrivableBunkerSilo:onLoad(savegame)
	--- Register the spec: spec_AIDrivableBunkerSilo
    local specName = AIDrivableBunkerSilo.MOD_NAME .. ".aiDrivableBunkerSilo"
    self.spec_aiDrivableBunkerSilo = self["spec_" .. specName]
    local spec = self.spec_aiDrivableBunkerSilo
	spec.state = AIDrivableBunkerSilo.DEACTIVATED
	
end

function AIDrivableBunkerSilo:aiBlock(superFunc)
	superFunc(self)
end

function AIDrivableBunkerSilo:aiContinue(superFunc)
	superFunc(self)
end

function AIDrivableBunkerSilo:getStartableAIJob(superFunc)
	return superFunc(self)
end

function AIDrivableBunkerSilo:getHasStartableAIJob(superFunc)
	return superFunc(self)
end

