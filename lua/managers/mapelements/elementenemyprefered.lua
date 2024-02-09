local prevent_removal = {
	flat = {
		[102097] = true,
		[102092] = true,
		[102091] = true
	}
}

function ElementEnemyPreferedRemove:on_executed(instigator)
	if not self._values.enabled then
		return
	end
	
	if LIES.settings.hhtacs then
		if prevent_removal[Global.level_data.level_id] then
			local elementids = prevent_removal[Global.level_data.level_id]
			
			if elementids[self._id] then
				return
			end
		end
	end

	for _, id in ipairs(self._values.elements) do
		local element = self:get_mission_element(id)

		if element then
			element:remove()
		end
	end

	ElementEnemyPreferedRemove.super.on_executed(self, instigator)
end