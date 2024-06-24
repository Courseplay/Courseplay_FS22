
---@class Field
local Field = CpObject()

---@param id string unique ID for this field for logging
---@param num number field number as shown in game
function Field:init(id, num)
	self.id = id
	self.num = num
	self.logger = Logger('Field ' .. id)
	---@type cg.Polygon
	self.boundary = cg.Polygon()
	---@type cg.Polygon
	self.islandPoints = cg.Polygon()
	---@type cg.Island[]
	self.islands = {}
end

function Field:getId()
	return self.id
end

function Field:getNum()
	return self.num
end

--- Read all fields saved in an XML file from the game console with the cpSaveAllFields command
---@return Field[] list of Fields in the file
function Field.loadSavedFields(fileName)
	local fields = {}
	local ix = 0
	for line in io.lines(fileName) do
		local fieldNum = string.match( line, '<field fieldNum="([%d%.-]+)"' )
		if fieldNum then
			-- a new field started
			ix = tonumber( fieldNum )
			fields[ix] = Field(string.gsub(fileName, 'fields/', ''):gsub('fields\\', ''):gsub('.xml', '') .. '-' .. ix, ix)
			Logger(''):debug('Loading field %s', ix)
		end
		local num, x, z = string.match( line, '<point(%d+).+pos="([%d%.-]+) [%d%.-]+ ([%d%.-]+)"' )
		if num then
			fields[ix].boundary:append(cg.Vertex(tonumber(x), -tonumber(z)))
		end
		num, x, z = string.match( line, '<islandNode(%d+).+pos="([%d%.-]+) +([%d%.-]+)"' )
		if num then
			fields[ix].islandPoints:append(cg.Vertex(tonumber(x ), -tonumber(z)))
		end
	end
	-- initialize all loaded fields
	for _, f in pairs(fields) do
		f:getBoundary():calculateProperties()
		f:setupIslands()
	end
	return fields
end

--- Center of the field (centroid)
---@return cg.Vector
function Field:getCenter()
	if not self.center then
		self.center = self.boundary:getCenter()
	end
	return self.center
end

--- Bounding box
function Field:getBoundingBox()
	return self.boundary:getBoundingBox()
end

---@return cg.Polygon
function Field:getBoundary()
	return self.boundary
end

---@return cg.Island[]
function Field:getIslands()
	return self.islands
end

--- Vertices with coordinates unpacked, to draw with love.graphics.polygon
function Field:getUnpackedVertices()
	if not self.unpackedVertices then
		self.unpackedVertices = self.boundary:getUnpackedVertices()
	end
	return self.unpackedVertices
end

-- set up all island related data for the field
function Field:setupIslands()
	local islandPerimeterPoints = cg.Island.getIslandPerimeterPoints(self.islandPoints)
	-- remember them for debug
	self.islandPerimeterPoints = {}
	if (#islandPerimeterPoints) > 0 then
		self.logger:debug('setting up islands from %d points', #islandPerimeterPoints)
	end
	for _, p in ipairs(islandPerimeterPoints) do table.insert(self.islandPerimeterPoints, p:clone()) end
	local islandId = 1
	while #islandPerimeterPoints > 0 do
		local island = cg.Island(islandId, islandPerimeterPoints)
		-- ignore too really small islands (under 5 sqm), there are too many issues with the
		-- headland generation for them
		if island:getBoundary():getArea() > 5 then
			table.insert(self.islands, island)
			islandId = islandId + 1
		end
	end
end


---@class cg.Field
cg.Field = Field