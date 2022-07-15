--[[
	Basic brush, that manipulates waypoints.
]]
---@class CpBrush : ConstructionBrush
CpBrush = {
	TRANSLATION_PREFIX = "CP_editor_",
	radius = 0.5,
	primaryButtonText = "primary_text",
	primaryAxisText = "primary_axis_text",
	secondaryButtonText = "secondary_text",
	secondaryAxisText = "secondary_axis_text",
	tertiaryButtonText = "tertiary_text",
	inputTitle = "input_title",
	yesNoTitle = "yesNo_title"
}
local CpBrush_mt = Class(CpBrush, ConstructionBrush)
function CpBrush.new(customMt, cursor)
	local self =  ConstructionBrush.new(customMt or CpBrush_mt, cursor)
	self.cursor:setShapeSize(self.radius)
	self.cursor:setShape(GuiTopDownCursor.SHAPES.CIRCLE)
	self.lastHoveredIx = nil
	return self
end

function CpBrush:isAtPos(position, x, y, z)
	return MathUtil.getPointPointDistance(position.x, position.z, x, z) < self.radius 
end

--- Gets the hovered waypoint ix.
function CpBrush:getHoveredWaypointIx()
	local x, y, z = self.cursor:getPosition()
	if x == nil or z == nil then 
		return
	end
	-- try to get a waypoint in mouse range
	for ix, point in ipairs(self.courseWrapper:getWaypoints()) do
		if self:isAtPos(point, x, y, z) then
			return ix
		end
	end
end

function CpBrush:setParameters(editor, translation, courseWrapper)
	self.editor = editor
	self.translation = translation
	self.courseWrapper = courseWrapper
end

function CpBrush:update(dt)
	local ix = self:getHoveredWaypointIx()
	local lastIx = self.courseWrapper:setHovered(ix)
	if lastIx ~= nil then 
		self.editor:updateChangeSingle(lastIx)
	end
end

function CpBrush:openTextInput(callback, title, args)
	g_gui:showTextInputDialog({
			disableFilter = true,
			callback = callback,
			target = self,
			defaultText = "",
			dialogPrompt = title,
			imePrompt = title,
			maxCharacters = 50,
			confirmText = g_i18n:getText("button_ok"),
			args = args
		})
end

function CpBrush:showYesNoDialog(callback, title, args)
	g_gui:showYesNoDialog({
			text = title,
			callback = callback,
			target = self,
			args = args
		})
end

--- Gets the translation with the translation prefix.
function CpBrush:getTranslation(translation, ...)
	return string.format(g_i18n:getText(self.translation .. "_" .. translation), ...)
end
