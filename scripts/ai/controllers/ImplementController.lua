---@class ImplementController
ImplementController = CpObject()

function ImplementController:init(vehicle, implement)
    self.vehicle = vehicle
    self.implement = implement
    self.overwrittenFunctions = {}
    self.additionalAIEvents = {}
end

function ImplementController:delete()
    self:unregisterOverwrittenFunctions()
    self:unregisterAIEvents()
end

function ImplementController:setAllStaticParameters(settings,fillLevelManager)
    self.settings = settings
    self.fillLevelManager = fillLevelManager
end

--- Get the controlled implement
function ImplementController:getImplement()
    return self.implement
end

---@param disabledStates table list of drive strategy states where the controlling of this implement is disabled
function ImplementController:setDisabledStates(disabledStates)
    self.disabledStates = disabledStates
end

---@param currentState table current state of the drive strategy
---@return boolean true if currentState is not one of the disabled states
function ImplementController:isEnabled(currentState)
    for _, state in pairs(self.disabledStates) do
        if currentState == state then
            return false
        end
    end
    return true
end

function ImplementController:debug(...)
    CpUtil.debugVehicle(CpDebug.DBG_IMPLEMENTS, self.vehicle,
            CpUtil.getName(self.implement) .. ': ' .. string.format(...))
end

function ImplementController:debugSparse(...)
    if g_updateLoopIndex % 100 == 0 then
        self:debug(...)
    end
end

--- Drive strategies can instantiate controllers for implements and call getDriveData for each
--- implement. If the implement wants to change any of the driving parameter, it'll return
--- a non nil value for that parameter, most often a speed value to slow down or stop.

---@return number gx world x coordinate to drive to or nil
---@return number gz world z coordinate to drive to or nil
---@return boolean direction is forwards if true or nil
---@return number maximum speed or nil
function ImplementController:update()
    return nil, nil, nil, nil
end

--- Overwrites a function and stores it, so the basic functionality gets restored after cp is finished.
---@param class table
---@param funcName string 
---@param newFunc function
function ImplementController:registerOverwrittenFunction(class,funcName,newFunc)    
    local oldFunc = class[funcName]
    class[funcName] = Utils.overwrittenFunction(oldFunc, newFunc)
    local reference = {}
    reference.class = class
    reference.funcName = funcName
    reference.oldFunc = oldFunc

    table.insert(self.overwrittenFunctions, reference)
end

--- Restores basic functionality as cp is finished.
function ImplementController:unregisterOverwrittenFunctions()
    for i=#self.overwrittenFunctions, 1, -1 do
        local reference = self.overwrittenFunctions[i]
        reference.class[reference.funcName] = reference.oldFunc
        self.overwrittenFunctions[i] = nil
    end
end

--- Register additional AI events, like onAIImplementStartLine and so on, that were not already initialized.
function ImplementController:registerAIEvents(class,eventName,...)
    SpecializationUtil.registerEventListener(self.implement, eventName, class)
    
    local data = {
        eventName = eventName,
        class = class
    }
    table.insert(self.additionalAIEvents,data)
end

--- Removes the cp additional AI events, like onAIImplementStartLine and so on.
function ImplementController:unregisterAIEvents()    
    for i=#self.additionalAIEvents,1,-1 do 
        local data = self.additionalAIEvents[i]
        SpecializationUtil.removeEventListener(self.implement, data.eventName, data.class)
        self.additionalAIEvents[i] = nil
    end
end


------------------------------------------------------------
--- Overwritten functions
------------------------------------------------------------

--- Disabled resetting the auto work width.
local function emptyFunction(implement,superFunc,...)
	if implement.rootVehicle and implement.rootVehicle:getIsCpActive() then 
		return
	end
	return superFunc(implement,...)
end
VariableWorkWidth.onAIFieldWorkerStart = Utils.overwrittenFunction(VariableWorkWidth.onAIFieldWorkerStart,emptyFunction)
VariableWorkWidth.onAIImplementStart = Utils.overwrittenFunction(VariableWorkWidth.onAIImplementStart,emptyFunction)

--- Registers event listeners for lowering/raising of the pickup.
local function lowerPickup(pickup,superFunc,...)
    if superFunc ~= nil then superFunc(pickup,...) end
    if pickup.rootVehicle and pickup.rootVehicle:getIsCpActive() then
        pickup:setPickupState(true)
    end
end
local function raisePickup(pickup,superFunc,...)
    if superFunc ~= nil then superFunc(pickup,...) end
    if pickup.rootVehicle and pickup.rootVehicle:getIsCpActive() then
        pickup:setPickupState(false)
    end
end
Pickup.onAIImplementStartLine = Utils.overwrittenFunction(Pickup.onAIImplementStartLine,lowerPickup)
Pickup.onAIImplementEndLine = Utils.overwrittenFunction(Pickup.onAIImplementEndLine,raisePickup)
Pickup.onAIImplementEnd = Utils.overwrittenFunction(Pickup.onAIImplementEnd,raisePickup)

local registerPickupListeners = function(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onAIImplementStartLine", Pickup)
    SpecializationUtil.registerEventListener(vehicleType, "onAIImplementEndLine", Pickup)
    SpecializationUtil.registerEventListener(vehicleType, "onAIImplementEnd", Pickup)
end
Pickup.registerEventListeners = Utils.appendedFunction(Pickup.registerEventListeners, registerPickupListeners)


--- Folds the implement at the end.
local function fold(implement,superFunc,...)
    if superFunc ~= nil then superFunc(implement,...) end
    if implement.rootVehicle and implement.rootVehicle:getIsCpActive() then
        implement:setFoldState(-1, false)
    end
end
Foldable.onAIFieldWorkerEnd = Utils.overwrittenFunction(Foldable.onAIFieldWorkerEnd,fold)
Foldable.onAIImplementEnd = Utils.overwrittenFunction(Foldable.onAIImplementEnd,fold)

local registerFoldableListeners = function(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onAIFieldWorkerEnd", Foldable)
    SpecializationUtil.registerEventListener(vehicleType, "onAIImplementEnd", Foldable)
end
Foldable.registerEventListeners = Utils.appendedFunction(Foldable.registerEventListeners, registerFoldableListeners)
