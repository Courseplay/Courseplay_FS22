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
	CustomFieldHotspot:superClass().setField(self, field)

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

function CustomFieldHotspot:onClickDelete()
	CpUtil.debugFormat(CpDebug.DBG_HUD,"Delete custom field %s.", self.name)
	g_customFieldManager:deleteField(self.field)
end

function CustomFieldHotspot:onClickRename()
	CpUtil.debugFormat(CpDebug.DBG_HUD,"Rename custom field %s.", self.name)
	g_customFieldManager:renameField(self.field, self)
end

function CustomFieldHotspot:onClickEdit()
	CpUtil.debugFormat(CpDebug.DBG_HUD,"Edit custom field %s.", self.name)
	g_customFieldManager:editField(self.field, self)
end

function CustomFieldHotspot:getAreaText()
    --- Needs to be converted to ha.
    return g_i18n:formatArea(self.field:getAreaInSqMeters()/10000 , 2)
end

--- Enables field hotspot area content box.
FieldHotspot.clickArea = MapHotspot.getClickArea(
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

FieldHotspot.getAreaText = function (self)
	--- Is already in ha.
	return g_i18n:formatArea(self.field.fieldArea , 2)
end