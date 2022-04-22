--- Enables soil sampling for the precision farming dlc.
---@class SoilSamplerController : ImplementController
SoilSamplerController = CpObject(ImplementController)

function SoilSamplerController:init(vehicle, implement)
    ImplementController.init(self, vehicle, implement)
    self.soilSamplerSpec = implement.spec_soilSampler
	self.lastSampleTaken = nil
	-- The sampling radius is a hexagon, so we shrink this to roughly math a square.
	self.distBetweenProbes = self.soilSamplerSpec.samplingRadius
	self.isRaised = false
end

function SoilSamplerController:onLowering()
	self:startSampling()

	self.isRaised = false
end

function SoilSamplerController:onRaising()
	self:startSampling()

	self.isRaised = true
end

function SoilSamplerController:onStart()
	self.implement:setFoldDirection(1)
end

function SoilSamplerController:onFinished()
	self.implement:sendTakenSoilSamples()
end

function SoilSamplerController:getDriveData()

	local maxSpeed = nil
	if not self.lastSampleTaken then 
		maxSpeed = 0
		if not self.soilSamplerSpec.isSampling then
			local vx, _, vz = getWorldTranslation(self.soilSamplerSpec.samplingNode)
			self.lastSampleTaken = {vx, vz, self.vehicle.lastMovedDistance}
			self.implement:aiImplementEndLine()
		end
	elseif not self.isRaised then
		local x, z, lastDistMoved = unpack(self.lastSampleTaken)
		local vx, _, vz = getWorldTranslation(self.soilSamplerSpec.samplingNode)
		if MathUtil.vector2Length(x-vx, z-vz) > self.distBetweenProbes or (self.vehicle.lastMovedDistance - lastDistMoved) > self.distBetweenProbes then 
			self:startSampling()
		end
	end

	return nil, nil, nil, maxSpeed
end

function SoilSamplerController:startSampling()
	if not self.soilSamplerSpec.isSampling then 
		self.implement:startSoilSampling()
		self.lastSampleTaken = nil
	end
end