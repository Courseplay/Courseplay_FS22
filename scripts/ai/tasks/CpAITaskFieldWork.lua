
---@class CpAITaskFieldWork : CpAITask
CpAITaskFieldWork = CpObject(CpAITask)

function CpAITaskFieldWork:reset()
	self.startPosition = nil
	self.fieldPolygon = nil
	CpAITask.reset(self)
end

function CpAITaskFieldWork:setFieldPolygon(polygon)
	self.fieldPolygon = polygon	
end

function CpAITaskFieldWork:setStartPosition(startPosition)
	self.startPosition = startPosition
end

--- Makes sure the cp fieldworker gets started.
function CpAITaskFieldWork:start()
	if self.isServer then
		self:debug("Field work task started.")
		self.vehicle:startFieldWorker()
		local spec = self.vehicle.spec_aiFieldWorker
		local cpSpec = self.vehicle.spec_cpAIFieldWorker
		--- Remembers the last lane offset setting value that was used.
        cpSpec.cpJobStartAtLastWp:getCpJobParameters().laneOffset:setValue(self.job:getCpJobParameters().laneOffset:getValue())
		if spec.driveStrategies ~= nil then
			for i = #spec.driveStrategies, 1, -1 do
				spec.driveStrategies[i]:delete()
				table.remove(spec.driveStrategies, i)
			end
			spec.driveStrategies = {}
		end
		local cpDriveStrategy
		if self.startPosition and g_vineScanner:hasVineNodesCloseBy(self.startPosition.x, self.startPosition.z) then 
			--- Checks if there are any vine nodes close to the starting point.
			self:debug('Found a vine course, install CP vine fieldwork drive strategy for it')
			cpDriveStrategy = AIDriveStrategyVineFieldWorkCourse(self, self.job)
		elseif AIUtil.hasChildVehicleWithSpecialization(self.vehicle, Plow) then
			self:debug('Found a plow, install CP plow drive strategy for it')
			cpDriveStrategy = AIDriveStrategyPlowCourse(self, self.job)
		else
			local combine = AIUtil.getImplementOrVehicleWithSpecialization(self.vehicle, Combine) 
			local pipe = combine and SpecializationUtil.hasSpecialization(Pipe, combine.specializations)
			if combine and pipe then 
				-- Default harvesters with a pipe.
				self:debug('Found a combine with pipe, install CP combine drive strategy for it')
				cpDriveStrategy = AIDriveStrategyCombineCourse(self, self.job)
				cpSpec.combineDriveStrategy = cpDriveStrategy
			end
			if not cpDriveStrategy then 
				self:debug('Installing default CP fieldwork drive strategy')
				cpDriveStrategy = AIDriveStrategyFieldWorkCourse(self, self.job)
			end
		end
		cpDriveStrategy:setFieldPolygon(self.fieldPolygon)
		cpDriveStrategy:setAIVehicle(self.vehicle, self.job:getCpJobParameters())
		cpSpec.driveStrategy = cpDriveStrategy
		--- Only the last driving strategy can stop the helper, while it is running.
		table.insert(spec.driveStrategies, cpDriveStrategy)
	end
	CpAITask.start(self)
end

function CpAITaskFieldWork:stop(wasJobStopped)
	if self.isServer then 
		self:debug("Field work task stopped.")
		self.vehicle:stopFieldWorker()
		self.vehicle:cpBrakeToStop()
	end
	CpAITask.stop(self, wasJobStopped)
end