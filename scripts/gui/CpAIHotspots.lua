--- Custom field hotspot that can be clicked for deleting of the field course.
CustomFieldHotspot = {}
CustomFieldHotspot.CATEGORY = 200
local CustomFieldHotspot_mt = Class(CustomFieldHotspot, FieldHotspot)

function CustomFieldHotspot.new(customMt)
	local self = FieldHotspot.new(customMt or CustomFieldHotspot_mt)
	
	return self
end

function CustomFieldHotspot:getCategory()
	return CustomFieldHotspot.CATEGORY 
end

function CustomFieldHotspot:setField(field)
	CustomFieldHotspot:superClass().setField(self,field)

	self.clickArea = MapHotspot.getClickArea(
		{
			0,
			0,
			1,
			1
		},
		{
			1,1,
		},
		0
	)	
end

function CustomFieldHotspot:onClick()
	CpUtil.debugFormat(CpDebug.DBG_HUD,"Custom field hotspot %s pressed.",self.name)	
	
end