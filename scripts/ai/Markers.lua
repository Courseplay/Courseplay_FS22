
Markers = {}

-- a global table with the vehicle as the key to persist the marker nodes we don't want to leak through jobs
-- and also don't want to deal with keeping track when to delete them
g_vehicleMarkers = {}

local function createMarkerIfDoesNotExist(vehicle, name, referenceNode)
    if not g_vehicleMarkers[vehicle] then
        g_vehicleMarkers[vehicle] = {}
    end
    if not g_vehicleMarkers[vehicle][name] then
        g_vehicleMarkers[vehicle][name] = CpUtil.createNode(name, 0, 0, 0, referenceNode)
    end
end

-- Put a node on the back of the vehicle for easy distance checks use this instead of the root/direction node
local function setBackMarkerNode(vehicle, measuredBackDistance)
    local backMarkerOffset = 0
    local referenceNode
    local reverserNode, debugText = AIUtil.getReverserNode(vehicle)
    if AIUtil.hasImplementsOnTheBack(vehicle) then
        local lastImplement
        lastImplement, backMarkerOffset = AIUtil.getLastAttachedImplement(vehicle)
        referenceNode = vehicle.rootNode
        CpUtil.debugVehicle(CpDebug.DBG_IMPLEMENTS, 'Using the last implement\'s rear distance for the rear proximity sensor, %d m from root node', backMarkerOffset)
    elseif measuredBackDistance then
        referenceNode = vehicle.rootNode
        backMarkerOffset = -measuredBackDistance
        CpUtil.debugVehicle(CpDebug.DBG_IMPLEMENTS,'back marker node on measured back distance %.1f', measuredBackDistance)
    elseif reverserNode then
        -- if there is a reverser node, use that, mainly because that most likely will turn with an implement
        -- or with the back component of an articulated vehicle. Just need to find out the distance correctly
        local dx, _, dz = localToLocal(reverserNode, vehicle.rootNode, 0, 0, 0)
        local dBetweenRootAndReverserNode = MathUtil.vector2Length(dx, dz)
        backMarkerOffset = dBetweenRootAndReverserNode - vehicle.size.length / 2 - vehicle.size.lengthOffset
        referenceNode = reverserNode
        CpUtil.debugVehicle(CpDebug.DBG_IMPLEMENTS,'Using the %s node for the rear proximity sensor %d m from root node (%d m between root and reverser)',
                debugText, backMarkerOffset, dBetweenRootAndReverserNode)
    else
        referenceNode = vehicle.rootNode
        backMarkerOffset = - vehicle.size.length / 2 + vehicle.size.lengthOffset
        CpUtil.debugVehicle(CpDebug.DBG_IMPLEMENTS,'Using the vehicle\'s root node for the rear proximity sensor, %d m from root node', backMarkerOffset)
    end

    createMarkerIfDoesNotExist(vehicle, 'backMarkerNode', referenceNode)
    -- relink to current reference node (in case of implement change for example
    unlink(g_vehicleMarkers[vehicle].backMarkerNode)
    link(referenceNode, g_vehicleMarkers[vehicle].backMarkerNode)
    setTranslation(g_vehicleMarkers[vehicle].backMarkerNode, 0, 0, backMarkerOffset)
end

-- Put a node on the front of the vehicle for easy distance checks use this instead of the root/direction node
local function setFrontMarkerNode(vehicle)
    local firstImplement, frontMarkerOffset = AIUtil.getFirstAttachedImplement(vehicle)
    CpUtil.debugVehicle(CpDebug.DBG_IMPLEMENTS,'Using the %s\'s root node for the front proximity sensor, %d m from root node',
            firstImplement.getName and firstImplement:getName() or 'N/A', frontMarkerOffset)

    createMarkerIfDoesNotExist(vehicle, 'frontMarkerNode', vehicle.rootNode)
    -- relink to current reference node (in case of implement change for example
    unlink(g_vehicleMarkers[vehicle].frontMarkerNode)
    link(vehicle.rootNode, g_vehicleMarkers[vehicle].frontMarkerNode)
    setTranslation(g_vehicleMarkers[vehicle].frontMarkerNode, 0, 0, frontMarkerOffset)
end

--- Create two nodes, one on the front and one on the back of the vehicle (including implements). The front node
--- is just in front of any attached implements, the back node is just behind all attached implements.
--- These nodes can be used for distance measurements or to link proximity sensors to them
---@param vehicle table
---@param measuredBackDistance number optional distance between the root node of the vehicle and the back of the vehicle if known
function Markers.setMarkerNodes(vehicle, measuredBackDistance)
    setBackMarkerNode(vehicle, measuredBackDistance)
    setFrontMarkerNode(vehicle)
end

function Markers.getFrontMarkerNode(vehicle)
    if not g_vehicleMarkers[vehicle] or not g_vehicleMarkers[vehicle].frontMarkerNode then
        setFrontMarkerNode(vehicle)
    end
    return g_vehicleMarkers[vehicle].frontMarkerNode
end

function Markers.getBackMarkerNode(vehicle)
    if not g_vehicleMarkers[vehicle] or not g_vehicleMarkers[vehicle].backMarkerNode then
        setBackMarkerNode(vehicle)
    end
    return g_vehicleMarkers[vehicle].backMarkerNode
end

