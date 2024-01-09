Hooks:PostHook(ElementSpawnCivilian, "_finalize_values", "lies_finalize_values", function(self)
	if self._values.team == "default" then
		self._values.team = nil
	elseif self._values.team ~= nil then
		local teams = tweak_data.levels:get_team_setup()
		
		if not teams[self._values.team] then
			self._values.team = tweak_data.levels:get_default_team_ID("non_combatant")
		end
	end
end)