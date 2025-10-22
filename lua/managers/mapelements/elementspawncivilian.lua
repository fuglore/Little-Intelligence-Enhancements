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

function ElementSpawnCivilian:produce(params)
	if not managers.groupai:state():is_AI_enabled() then
		return
	end

	local default_team_id = params and params.team or self._values.team or tweak_data.levels:get_default_team_ID("non_combatant")
	local unit = safe_spawn_unit(self._enemy_name, self:get_orientation())
	unit:unit_data().mission_element = self

	table.insert(self._units, unit)

	if self._values.state then
		local state = CopActionAct._act_redirects.civilian_spawn[self._values.state]
		
		if unit:brain() then
			local action_data = {
				align_sync = true,
				body_part = 1,
				type = "act",
				variant = state
			}
			local spawn_ai = {
				init_state = "idle",
				objective = {
					interrupt_health = 1,
					interrupt_dis = -1,
					type = "act",
					action = action_data
				}
			}

			unit:brain():set_spawn_ai(spawn_ai)
		else
			unit:base():play_state(state)
		end
	end

	if self._values.force_pickup then
		unit:character_damage():set_pickup(self._values.force_pickup)
	end

	unit:movement():set_team(managers.groupai:state():team_data(default_team_id))
	self:event("spawn", unit)

	return unit
end