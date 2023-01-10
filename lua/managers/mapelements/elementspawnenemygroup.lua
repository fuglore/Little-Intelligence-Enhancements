Hooks:PostHook(ElementSpawnEnemyGroup, "_finalize_values", "lies_finalize_values", function(self)
	if self._values.team == "default" then
		self._values.team = nil
	elseif self._values.team ~= nil then
		local teams = tweak_data.levels:get_team_setup()
		
		if not teams[self._values.team] then
			self._values.team = tweak_data.levels:get_default_team_ID("combatant")
		end
	end

	if type(LIES.settings.fixed_spawngroups) ~= "number" then
		return
	end

	if LIES.settings.fixed_spawngroups == true or LIES.settings.fixed_spawngroups < 3 then
		return
	end

	if self._values.preferred_spawn_groups then
		local has_regular_enemies = true
	
		for name, name2 in pairs(self._values.preferred_spawn_groups) do
			if name2 == "single_spooc" or name2 == "Phalanx" then
				
				has_regular_enemies = nil
				break
			end
		end
		
		if not has_regular_enemies then

		else
			local preferreds = {}
			
			for cat_name, team in pairs(tweak_data.group_ai.enemy_spawn_groups) do
				if cat_name ~= "Phalanx" and cat_name ~= "single_spooc" then
					table.insert(preferreds, cat_name)
				end
			end
			
			self._values.preferred_spawn_groups = preferreds
		end
	end
end)