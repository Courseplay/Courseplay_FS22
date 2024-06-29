--- A container to hold waypoint and fieldwork related attributes
--- for a vertex.
--- These attributes contain information to help the vehicle navigate the course, while
--- the vertex is strictly a geometric concept.
local WaypointAttributes = CpObject()

function WaypointAttributes:clone()
    local a = cg.WaypointAttributes()
    for attribute, value in pairs(self) do
        a[attribute] = value
    end
    return a
end

--- Copy the attributes of v
---@param v Vertex the vertex to get the attributes from
function WaypointAttributes:copy(v)
    for attribute, value in pairs(v:getAttributes()) do
        self[attribute] = value
    end
end

---@return boolean true if the waypoint is part of a path bypassing a small island.
function WaypointAttributes:isIslandBypass()
    return self.islandBypass
end
---@return boolean true if this waypoint is on a section leading from one headland to the next
function WaypointAttributes:isHeadlandTransition()
    return self.headlandTransition
end

---@return number | nil number of the headland, starting at 1 on the outermost headland. The section leading
--- to the next headland (isHeadlandTransition() == true) has the same pass number as the headland where the
--- section starts (transition from 1 -> 2 has pass number 1)
function WaypointAttributes:getHeadlandPassNumber()
    return self.headlandPassNumber
end

---@return number the number of the row (within the block) this point is in, in the order of working,
function WaypointAttributes:getRowNumber()
    return self.rowNumber
end

---@return boolean true if this is the last waypoint of an up/down row. It is either time to switch to the next
--- row (by starting a turn) of the same block, the first row of the next block, or, to the headland if we
--- started working on the center of the field
function WaypointAttributes:isRowEnd()
    return self.rowEnd
end

---@return boolean true if this is the first waypoint of an up/down row.
function WaypointAttributes:isRowStart()
    return self.rowStart
end

---@return boolean true if this is a headland turn waypoint, like a corner where the vehicle must perform a turn
--- maneuver into the new direction (usually around 90º, but can be anything between 10 - 170),
--- making sure it covers the entire area.
function WaypointAttributes:isHeadlandTurn()
    return self.headlandTurn
end

---@return boolean true if this waypoint is part of a headland around a (big) island. Small islands are bypassed
--- and there isIslandBypass is set to true.
function WaypointAttributes:isIslandHeadland()
    return self.islandHeadland
end

--- if this is true, the driver should use the pathfinder to navigate to the next waypoint. One example of this is
--- switching from an end of the row to an island headland.
function WaypointAttributes:shouldUsePathfinderToNextWaypoint()
    return self.usePathfinderToNextWaypoint
end

--- if this is true, the driver should use the pathfinder to navigate to the this waypoint from the previous.
--- One example of this is when row starts at a small island so the 180º turn must use the pathfinder to avoid the island.
function WaypointAttributes:shouldUsePathfinderToThisWaypoint()
    return self.usePathfinderToThisWaypoint
end

--- Is this waypoint on a connecting path, that is, a section connecting the headlands to the
--- first waypoint of the up/down rows (or vica versa), or a section connecting two blocks.
--- In general, the driver should lift their implements and follow this path, maybe removing the
--- first and the last waypoint of it to make room to maneuver, and use the pathfinder when transitioning
--- to or from this section. For instance, if this path leads to the first up/down row, the generator
--- cannot guarantee that there are no obstacles (like a small island) between the last waypoint
--- of this path and the first up/down waypoint.
function WaypointAttributes:isOnConnectingPath()
    return self.onConnectingPath
end

--- Was the area on the left of this waypoint worked on already? Use this to determine:
---   * Is there fruit under the harvester's pipe?
---   * Which side to deploy the ridge markers?
---   * Which side to turn a rotatable plow?
--- NOTE: this only considers up/down rows in the same block. Headlands or rows in an adjacent block may have been
--- worked on or not, depending on whether the headland or the middle is worked first and on the block sequence.
--- NOTE: this is valid only if the vehicle worked on the course from the beginning as we rely on the planned
--- course here, not the actual course driven. If you start a course in the middle, you will get incorrect results.
--- NOTE: if this returns nil, we have no information if the left side was worked on or not. Use isLeftSideNotWorked() 
--- instead of not isLeftSideWorked() 
---@return boolean|nil returns true _only_ if we have valid information that the left side was worked.
function WaypointAttributes:isLeftSideWorked()
    return self.leftSideWorked
end

---@see isLeftSideWorked()
---@return boolean returns true _only_ if we have valid information that the left side is not worked
function WaypointAttributes:isLeftSideNotWorked()
    return self.leftSideWorked == false
end

--- Was the area on the right of this waypoint worked on already?
---   * Is there fruit under the harvester's pipe?
---   * Which side to deploy the ridge markers?
---   * Which side to turn a rotatable plow?
--- NOTE: this only considers up/down rows in the same block. Headlands or rows in an adjacent block may have been
--- worked on or not, depending on whether the headland or the middle is worked first and on the block sequence.
--- NOTE: this is valid only if the vehicle worked on the course from the beginning as we rely on the planned
--- course here, not the actual course driven. If you start a course in the middle, you will get incorrect results.
--- NOTE: if this returns nil, we have no information if the right side was worked on or not. Use isRightSideNotWorked() 
--- instead of not isRightSideWorked() 
---@return boolean|nil returns true _only_ if we have valid information that the right side was worked.
function WaypointAttributes:isRightSideWorked()
    return self.rightSideWorked
end

---@see isRightSideWorked()
---@return boolean returns true _only_ if we have valid information that the right side is not worked
function WaypointAttributes:isRightSideNotWorked()
    return self.rightSideWorked == false
end

--- Set for each headland waypoint, this string uniquely identifies the boundary the headland was based on.
---@return string | nil F for the headlands around the field boundary, I<island ID> for headlands around an island,
--- but do not try to interpret as these can be arbitrary strings, use only for comparison with getAtBoundaryId()
function WaypointAttributes:getBoundaryId()
    return self.boundaryId
end

--- Row start/end waypoints ending at a headland will have to set this to the boundary ID of the headland.
--- This can be used to check if the next row can be reached using the same headland where the previous row ends.
---@return string | nil
function WaypointAttributes:getAtBoundaryId()
    return self.atBoundaryId
end

--- For the first and last waypoints of a row, the angle between the row and the headland
---@return number | nil
function WaypointAttributes:getHeadlandAngle()
    return self.headlandAngle
end

------------------------------------------------------------------------------------------------------------------------
--- Setters
---------------------------------------------------------------------------------------------------------------------------
function WaypointAttributes:setIslandBypass()
    self.islandBypass = true
end

function WaypointAttributes:setHeadlandTransition()
    self.headlandTransition = true
end

function WaypointAttributes:setHeadlandPassNumber(n)
    self.headlandPassNumber = n
end

function WaypointAttributes:setBlockNumber(n)
    self.blockNumber = n
end

function WaypointAttributes:setRowNumber(n)
    self.rowNumber = n
end

function WaypointAttributes:setRowEnd()
    self.rowEnd = true
end

function WaypointAttributes:setRowStart()
    self.rowStart = true
end

function WaypointAttributes:setHeadlandTurn(isHeadlandTurn)
    self.headlandTurn = isHeadlandTurn
end

function WaypointAttributes:setIslandHeadland()
    self.islandHeadland = true
end

function WaypointAttributes:setUsePathfinderToNextWaypoint()
    self.usePathfinderToNextWaypoint = true
end

function WaypointAttributes:setUsePathfinderToThisWaypoint()
    self.usePathfinderToThisWaypoint = true
end

function WaypointAttributes:setOnConnectingPath()
    self.onConnectingPath = true
end

---@see isLeftSideWorked()
function WaypointAttributes:setLeftSideWorked(worked)
    self.leftSideWorked = worked
end

---@see isRightSideWorked()
function WaypointAttributes:setRightSideWorked(worked)
    self.rightSideWorked = worked
end

function WaypointAttributes:setLeftSideBlockBoundary(blockBoundary)
    self.leftSideBlockBoundary = blockBoundary
end

function WaypointAttributes:setRightSideBlockBoundary(blockBoundary)
    self.rightSideBlockBoundary = blockBoundary
end

---@param boundaryId string
function WaypointAttributes:setBoundaryId(boundaryId)
    self.boundaryId = boundaryId
end

---@param boundaryId string
function WaypointAttributes:setAtBoundaryId(boundaryId)
    self.atBoundaryId = boundaryId
end

---@param a number radians
function WaypointAttributes:setHeadlandAngle(a)
    self.headlandAngle = a
end

---@return number number of the block this waypoint is in
function WaypointAttributes:_getBlockNumber()
    return self.blockNumber
end

---@param headland cg.Headland
function WaypointAttributes:_setAtHeadland(headland)
    self.atHeadland = headland
end

--- For generator internal use only, this is set for row end and start waypoints, storing the Headland object
--- terminating the row
---@return cg.Headland
function WaypointAttributes:_getAtHeadland()
    return self.atHeadland
end

--- For generator internal use only, this is set for row end and start waypoints, storing the Island object
--- terminating the row
---@return cg.Island|nil
function WaypointAttributes:_getAtIsland()
    return self.atHeadland and self.atHeadland:isIslandHeadland() and self.atHeadland:getIsland()
end

--- For generator internal use only: when reversing a complete course, make sure the attributes
--- are also reversed
function WaypointAttributes:_reverse()
    self.rowStart, self.rowEnd = self.rowEnd, self.rowStart
    self.usePathfinderToThisWaypoint, self.usePathfinderToNextWaypoint = self.usePathfinderToNextWaypoint, self.usePathfinderToThisWaypoint
    -- TODO: is there a use case where these are needed for a reversed course? It isn't trivial to find these out after the block is finalized
    self.leftSideWorked, self.rightSideWorked = nil, nil
end

function WaypointAttributes:__tostring()
    local str = '[ '
    for attribute, value in pairs(self) do
        str = str .. string.format('%s: %s ', attribute, value)
    end
    str = str .. ']'
    return str
end

---@class cg.WaypointAttributes
cg.WaypointAttributes = WaypointAttributes