local common_harasser_string = "ai_spawn_enemy_harasser"
local instance_strings = {
	harasser_norm = true,
	harasser_hards = true,
	harasser_over = true
}
local valid_levels = {
	man = true,
	rvd1 = true
}

Hooks:PostHook(ElementSpawnEnemyDummy, "_finalize_values", "lies_hhtacs_elementcheck", function(self)
	if LIES.settings.hhtacs and valid_levels[Global.level_data.level_id] then
		local editor_name = self._editor_name
		
		if instance_strings[editor_name] then
			self._LIES_harasser_spawn = true

			return
		end
		
		local base_string = common_harasser_string
		
		for i = 1, 40 do
			local s_to_test = common_harasser_string
			
			if i < 10 then
				s_to_test = s_to_test .. "00"
			elseif i < 100 then
				s_to_test = s_to_test .. "0"
			end
			
			s_to_test = s_to_test .. tostring(i)
		
			if editor_name == s_to_test then
				self._LIES_harasser_spawn = true
				
				break
			end
		end
	end
end)

function ElementSpawnEnemyDummy:check_overwrite_spawn_value()
	if self._LIES_harasser_spawn then
		if tweak_data:difficulty_to_index(Global.game_settings.difficulty) < 4 then
			return
		end
		
		if math.random() < 0.6 then
			return
		end

		local groupaistate = managers.groupai:state()
		
		if groupaistate and groupaistate._timed_groups and groupaistate._timed_groups["marshal_squad"] and groupaistate._timed_groups["marshal_squad"].has_spawned then
			local current_unit_type = tweak_data.levels:get_ai_group_type()
			local units = tweak_data.group_ai.unit_categories.marshal_marksman.unit_types[current_unit_type]
			local value = units[math.random(#units)]
			
			return value
		end
	end
end

function ElementSpawnEnemyDummy:value(name)
	if LIES.settings.hhtacs and name == "enemy" then
		local value = self:check_overwrite_spawn_value()
		
		if value then
			return value
		end
	end

	if self._values.instance_name and self._values.instance_var_names and self._values.instance_var_names[name] then
		local value = managers.world_instance:get_instance_param(self._values.instance_name, self._values.instance_var_names[name])

		if value then
			return value
		end
	end
	
	return self._values[name]
end