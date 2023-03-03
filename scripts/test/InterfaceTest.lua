
InterfaceTests = {}

--- Simple interface test, 
--- that checks if all functions from an interface are implemented.
function InterfaceTests.compareToInterface(dynamicInterface, dynamicClass)
	local interface_metaTable = getmetatable(dynamicInterface)
	local class_metaTable = getmetatable(dynamicClass)
	for funcName, func in pairs(interface_metaTable) do 
		assert(class_metaTable[funcName] ~= nil)
	end
end