--- This is to encapsulate the specifics of a field center up/down rows generated
--- for the two-side headland pattern.
--- With that pattern, we always use baseline edges, that is, the rows following the
--- field edge (instead of always being straight) and do not allow multiple blocks.

---@class CenterTwoSided : cg.Center
local CenterTwoSided = CpObject(cg.Center)

---@param context cg.FieldworkContext
---@param boundary cg.Polygon the field boundary
---@param headland cg.Headland|nil the innermost headland if exists
---@param startLocation cg.Vector location of the vehicle before it starts working on the center.
---@param bigIslands cg.Island[] islands too big to circle
---@param lastRow cg.Row the last row of the center (before cut), this will be added to the ones generated
function CenterTwoSided:init(context, boundary, headland, startLocation, bigIslands, lastRow)
    cg.Center.init(self, context, boundary, headland, startLocation, bigIslands, lastRow)
    -- force using the baseline edge, no matter what the context is
    self.useBaselineEdge = true
end

function CenterTwoSided:_splitIntoBlocks(rows)
    local block = cg.Block(self.context.rowPattern)
    for _, row in ipairs(rows) do
        local sections = row:split(self.headland, {}, true)
        if #sections == 1 then
            block:addRow(sections[1])
        elseif #sections > 1 then
            self.context:addError(self.logger, 'Two side headlands: center would need multiple blocks')
        end
    end
    return block:getNumberOfRows() > 0 and { block } or {}
end

function CenterTwoSided:_wrapUpConnectingPaths()
    -- instead of the connecting track use pathfinder to the entry of the next block
    self.connectingPaths[1] = {}
    self.blocks[1]:getEntryVertex():getAttributes():setUsePathfinderToThisWaypoint()
end

---@class cg.CenterTwoSided : cg.Center
cg.CenterTwoSided = CenterTwoSided