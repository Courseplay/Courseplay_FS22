---@class AITaskShovelLoadingBunkerSilo
AITaskShovelLoadingBunkerSilo = {
	STATE_SET_LOADING_SHOVEL_POSITION = 0,
	STATE_DRIVING_INTO_SILO = 1,
	STATE_SET_TRANSPORT_SHOVEL_POSITION = 2,
	STATE_DRIVING_OUT_OF_SILO = 3,
}
local AITaskShovelLoadingBunkerSilo_mt = Class(AITaskShovelLoadingBunkerSilo,AITask)

function AITaskShovelLoadingBunkerSilo.new(isServer, job, customMt)
	local self = AITask.new(isServer,job,customMt or AITaskShovelLoadingBunkerSilo_mt)
	self.vehicle = nil
	self.shovel = nil
	self.maxSpeed = 10
	self.siloEndOffset = 5
	self.offset = 0
	self.startPos = {}
	self.startDir = {}
	self.endPos = {}
	self.silo = nil
	self.state = AITaskShovelLoadingBunkerSilo.STATE_SET_LOADING_SHOVEL_POSITION

	return self
end

function AITaskShovelLoadingBunkerSilo:reset()
	self.vehicle = nil
	self.shovel = nil
	self.offset = 0
	self.startPos = {}
	self.startDir = {}
	self.endPos = {}
	self.silo = nil
	self.state = AITaskShovelLoadingBunkerSilo.STATE_SET_LOADING_SHOVEL_POSITION
	AITaskShovelLoadingBunkerSilo:superClass.reset(self)
end

function AITaskShovelLoadingBunkerSilo:start()
	local x,z,dirX,dirZ = self:getStartPositionAndDirection()
	local dx,dz = self:getEndPosition(x,z,dirX,dirZ)
	self.startPos = {x,z}
	self.startDir = {dirX,dirZ}
	self.endPos = {dx,dz}

	AITaskShovelLoadingBunkerSilo:superClass().start(self)

end


function AITaskShovelLoadingBunkerSilo:getWorkWidth()
	return CpUtil.getShovelWidth(self.shovel)
end


function AITaskShovelLoadingBunkerSilo:setupSilo(x,z,xDir,zDir)
	if x~=nil and xDir~=nil then 
		self.silo = BunkerSiloUtil.findBunkerSiloAtPosition(x,z,xDir,zDir)
	end
end

function AITaskShovelLoadingBunkerSilo:getStartPositionAndDirection(x,z)
	if x==nil or z==nil then 
		local cx,_,cz = getWorldTranslation(self.vehicle.rootNode)
		x,z = cx,cz
	end

	return BunkerSiloUtil.getStartPointFromVehiclePos(self.silo,x,z,self:getWorkWidth())
end

function AITaskShovelLoadingBunkerSilo:getEndPosition(x,z,xDir,zDir)
	return BunkerSiloUtil.getEndPositionFromStartPositionAndDirection(self.silo,x,z,xDir,zDir,self.siloEndOffset)
end

function AITaskShovelLoadingBunkerSilo:delete()
end

function AITaskShovelLoadingBunkerSilo:update(dt)
end

function AITaskShovelLoadingBunkerSilo:validate(ignoreUnsetParameters)
	return true, nil
end


function AITaskShovelLoadingBunkerSilo:setVehicle(vehicle)
	self.vehicle = vehicle
end

function AITaskShovelLoadingBunkerSilo:setShovel(shovel)
	self.shovel = shovel
end

function AITaskShovelLoadingBunkerSilo:setOffset(offset)
	self.offset = offset
end



