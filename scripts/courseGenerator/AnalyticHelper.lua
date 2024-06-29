--- Analytic path generator helpers
---
local AnalyticHelper = {}

---@return Vertex[] path as vertices
---@return number length of path
---@return string path type (see Dubins.lua)
function AnalyticHelper.getDubinsSolutionAsVertices(from, to, r, enabledPathTypes)
    local dubinsSolver = DubinsSolver(enabledPathTypes)
    local solution, type = dubinsSolver:solve(from, to, r, true)
    local path = {}
    for _, v in ipairs(solution:getWaypoints(from, r)) do
        table.insert(path, Vertex.fromVector(v))
    end
    return path, solution:getLength(r), type
end

---@class cg.AnalyticHelper
cg.AnalyticHelper = AnalyticHelper