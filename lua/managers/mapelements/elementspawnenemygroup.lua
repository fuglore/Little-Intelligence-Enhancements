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
	
	if not self._values.preferred_spawn_groups then
		self._values.preferred_spawn_groups = {}
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

function ElementSpawnEnemyGroup:on_executed(instigator)
	if not self._values.enabled then
		return
	end

	self:_check_spawn_points()

	if #self._spawn_points > 0 then
		if self._group_data.spawn_type == "group" then
			local spawn_group_data = managers.groupai:state():create_spawn_group(self._id, self, self._spawn_points)

			local has_spawned_group = managers.groupai:state():force_spawn_group(spawn_group_data, self._values.preferred_spawn_groups)
			
			if has_spawned_group then
				local spawn_task = managers.groupai:state()._spawning_groups[1]

				if spawn_task then
					managers.groupai:state():_perform_group_spawning(spawn_task, true)
				end
			end
		elseif self._group_data.spawn_type == "group_guaranteed" then
			local spawn_group_data = managers.groupai:state():create_spawn_group(self._id, self, self._spawn_points)

			managers.groupai:state():force_spawn_group(spawn_group_data, self._values.preferred_spawn_groups, true)

			local spawn_task = managers.groupai:state()._spawning_groups[1]

			if spawn_task then
				managers.groupai:state():_perform_group_spawning(spawn_task, true)
			end
		else
			for i = 1, self:get_random_table_value(self._group_data.amount) do
				local element = self._spawn_points[self:_get_spawn_point(i)]

				element:produce({
					team = self._values.team
				})
			end
		end
	end

	ElementSpawnEnemyGroup.super.on_executed(self, instigator)
end