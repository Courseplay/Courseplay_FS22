--- Interface for analytic solutions of pathfinding problems
---@class AnalyticSolution
AnalyticSolution = CpObject()

---@param turnRadius number needed as the solution is usually normalized for the unit circle
---@return number length of the analytic solution in meters
function AnalyticSolution:getLength(turnRadius)
	return 0
end

---@param start State3D
---@param turnRadius number
---@return State3D[] array of path points of the solution
function AnalyticSolution:getWaypoints(start, turnRadius)
end

--- Interface for all analytic path problem solvers (Dubins and Reeds-Shepp)
---@class AnalyticSolver
AnalyticSolver = CpObject()

--- Solve a pathfinding problem (find drivable path between start and goal
--- for a vehicle with the given turn radius
---@param start State3D
---@param goal State3D
---@param turnRadius number
---@return AnalyticSolution a path descriptor
function AnalyticSolver:solve(start, goal, turnRadius)
	return AnalyticSolution()
end

Gear =
{
	Forward = {},
	Backward = {}
}

Steer =
{
	Left = {},
	Straight = {},
	Right = {}
}
