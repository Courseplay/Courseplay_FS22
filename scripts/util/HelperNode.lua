--[[
This file is part of Courseplay (https://github.com/Courseplay/FS22_Courseplay)
Copyright (C) 2024 Courseplay Dev Team

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

]]--

-- A helper node is a temporary node to help with relative vehicle position calculations.
-- It wraps the creation of the Giant's engine node.
-- NOTE: it must be destroyed explicitly to avoid node leak.

---@class HelperNode
HelperNode = CpObject()

--- Create a new helper node, linking it to the given rootNode.
---@param name string
---@param rootNode number|nil
function HelperNode:init(name, rootNode)
    self.node = createTransformGroup(name)
    self.rootNode = rootNode
    if self.rootNode then
        link(self.rootNode, self.node)
    end
end

--- Safely destroy a node
function HelperNode:destroy()
    if self.node and entityExists(self.node) then
        if self.rootNode then
            unlink(self.node)
        end
        delete(self.node)
    end
end

--- Place the node at the given position and rotation.
---@param x number
---@param y number if the node is linked to the terrain, this is relative to the terrain height at x, z
---@param z number
---@param yRotation number|nil Rotation set only if not nil
function HelperNode:place(x, y, z, yRotation)
    setTranslation(self.node, x, y, z)
    if yRotation then
        setRotation(self.node, 0, yRotation, 0)
    end
end

--- Get the position of a point relative to node, in the helper node's coordinate system.
---@param node number
---@param lx number x coordinate of the point relative to the node
---@param ly number y coordinate of the point relative to the node
---@param lz number z coordinate of the point relative to the node
---@return number, number, number
function HelperNode:localToLocal(node, lx, ly, lz)
    return localToLocal(node, self.node, lx, ly, lz)
end

---@param text string|nil
function HelperNode:draw(text)
    if entityExists(self.node) then
        DebugUtil.drawDebugNode(self.node, text or getName(self.node), false, 0)
    end
end

-- A helper node that is linked to the terrain root node, and the y coordinate is always
-- the terrain height at the x, z position.
---@class HelperTerrainNode : HelperNode
HelperTerrainNode = CpObject(HelperNode)

--- Create a new terrain helper node, linking it to the terrain root node.
---@param name string
function HelperTerrainNode:init(name)
    HelperNode.init(self, name, g_currentMission.terrainRootNode)
end

--- Place the node at the given position and rotation.
---@param x number
---@param y number if the node is linked to the terrain, this is relative to the terrain height at x, z
---@param z number
---@param yRotation number|nil Rotation set only if not nil
function HelperTerrainNode:place(x, y, z, yRotation)
    setTranslation(self.node, x, getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z) + y, z)
    if yRotation then
        -- leave z/x rotation as is
        local xRotation, _, zRotation = getWorldRotation(node)
        setRotation(self.node, xRotation, yRotation, zRotation)
    end
end

--- Place the node at the same world position and rotation as the given node.
--- An optional local position can be given to offset the helper node from the given node.
---@param node number
---@param y number|nil relative height to terrain
---@param lx number|nil x coordinate of the point relative to node
---@param ly number|nil y coordinate of the point relative to node
---@param lz number|nil z coordinate of the point relative to node
function HelperTerrainNode:placeAtNode(node, y, lx, ly, lz)
    local x, _, z = localToWorld(node, lx or 0, ly or 0, lz or 0)
    local xRotation, yRotation, zRotation = getWorldRotation(node)
    setRotation(self.node, xRotation, yRotation, zRotation)
    self:place(x, y or 0, z)
end
