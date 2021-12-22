--- Can be used to display additional data for the current driver 
--- under the steering wheel map hotspot on the map.

---@class CpAIHotspotExtended
CpAIHotspotExtended = {}

function CpAIHotspotExtended:render(x, y, rotation, small)
--[[
	if self.vehicle and self.vehicle.getCpAdditionalHotspotDetails then 
		local timeRemaining = self.vehicle:getCpAdditionalHotspotDetails()
		if timeRemaining ~=nil then
			local text = CpGuiUtil.getFormatTimeText(timeRemaining)

			local alpha = 1

			if self.isBlinking then
				alpha = IngameMap.alpha
			end

			setTextColor(1, 1, 1, alpha)
			setTextAlignment(RenderText.ALIGN_CENTER)
			setTextWrapWidth(0)
			setTextBold(false) -- + self.textOffsetY * self.scale
			renderText(x + self.textOffsetX * self.scale, y , self.textSize * self.scale, text)
			setTextColor(1, 1, 1, 1)
			setTextAlignment(RenderText.ALIGN_LEFT)
		end
	end
	]]--
end
AIHotspot.render = Utils.appendedFunction(AIHotspot.render,CpAIHotspotExtended.render)