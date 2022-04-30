Hooks:PostHook(ElementSpawnEnemyGroup, "_finalize_values", "lies_finalize_values", function(self)
	if type(LIES.settings.fixed_spawngroups) ~= "number" then
		return
	end

	if LIES.settings.fixed_spawngroups == true or LIES.settings.fixed_spawngroups < 2 then
		return
	end

	if not tweak_data.group_ai.fixed then
		log("LIES: Attempting fixing spawngroups.")
		tweak_data.group_ai:_fix_enemy_spawn_groups()
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