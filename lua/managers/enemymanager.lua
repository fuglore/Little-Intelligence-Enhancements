local mvec3_set = mvector3.set
local mvec3_sub = mvector3.subtract
local mvec3_dir = mvector3.direction
local mvec3_dot = mvector3.dot
local mvec3_dis_sq = mvector3.distance_sq
local t_rem = table.remove
local t_ins = table.insert
local tmp_vec1 = Vector3()
local tmp_vec2 = Vector3()

function EnemyManager:set_corpse_disposal_enabled(state)
	local was_enabled = self:is_corpse_disposal_enabled()
	local state_modifier = state and 1 or -1
	self._corpse_disposal_enabled = self._corpse_disposal_enabled + state_modifier
	local is_now_enabled = self:is_corpse_disposal_enabled()

	if was_enabled and not is_now_enabled then
		local corpse_disposal_id = self._corpse_disposal_id

		if corpse_disposal_id then
			self._corpse_disposal_id = nil

			self:remove_delayed_clbk(corpse_disposal_id)
		end
	elseif not was_enabled and is_now_enabled then
		self:_chk_detach_stored_units()
		self:chk_queue_disposal(self._timer:time())
	end
end

function EnemyManager:chk_queue_disposal(t)
	local corpse_disposal_id = self._corpse_disposal_id

	if corpse_disposal_id then
		return
	end

	if self:corpse_limit() < self._enemy_data.nr_corpses then
		corpse_disposal_id = "EnemyManager._upd_corpse_disposal"
		self._corpse_disposal_id = corpse_disposal_id

		self:add_delayed_clbk(corpse_disposal_id, callback(self, self, "_upd_corpse_disposal"), t)
	end
end

function EnemyManager:corpse_limit_changed_clbk(setting_name, old_limit, new_limit)
	self._MAX_NR_CORPSES = new_limit

	if not self:is_corpse_disposal_enabled() then
		return
	end

	local corpse_disposal_id = self._corpse_disposal_id

	if corpse_disposal_id then
		if self._enemy_data.nr_corpses <= self:corpse_limit() then
			self._corpse_disposal_id = nil

			self:remove_delayed_clbk(corpse_disposal_id)
		end
	elseif self:corpse_limit() < self._enemy_data.nr_corpses then
		corpse_disposal_id = "EnemyManager._upd_corpse_disposal"
		self._corpse_disposal_id = corpse_disposal_id

		self:add_delayed_clbk(corpse_disposal_id, callback(self, self, "_upd_corpse_disposal"), self._timer:time())
	end
end

function EnemyManager:on_civilian_destroyed(civilian)
	local u_key = civilian:key()
	local civ_u_data = self._civilian_data.unit_data

	if civ_u_data[u_key] then
		managers.groupai:state():on_civilian_unregistered(civilian)

		civ_u_data[u_key] = nil

		self:_destroy_unit_gfx_lod_data(u_key)
	else
		local enemy_data = self._enemy_data
		local corpses = enemy_data.corpses
		local corpse_data = corpses[u_key]

		if corpse_data then
			corpses[u_key] = nil
			local corpses_to_detach = self._corpses_to_detach

			if corpses_to_detach[u_key] then
				corpses_to_detach[u_key] = nil
			end

			if not corpse_data.no_dispose then
				local nr_corpses = enemy_data.nr_corpses - 1
				enemy_data.nr_corpses = nr_corpses
				local corpse_disposal_id = self._corpse_disposal_id

				if corpse_disposal_id and nr_corpses <= self:corpse_limit() then
					self._corpse_disposal_id = nil

					self:remove_delayed_clbk(corpse_disposal_id)
				end
			end
		end
	end
end

function EnemyManager:on_enemy_destroyed(enemy)
	local u_key = enemy:key()
	local enemy_data = self._enemy_data
	local enemy_u_data = enemy_data.unit_data

	if enemy_u_data[u_key] then
		self:on_enemy_unregistered(enemy)

		enemy_u_data[u_key] = nil

		self:_destroy_unit_gfx_lod_data(u_key)
	else
		local corpses = enemy_data.corpses
		local corpse_data = corpses[u_key]

		if corpse_data then
			corpses[u_key] = nil
			local corpses_to_detach = self._corpses_to_detach

			if corpses_to_detach[u_key] then
				corpses_to_detach[u_key] = nil
			end

			if not corpse_data.no_dispose then
				local nr_corpses = enemy_data.nr_corpses - 1
				enemy_data.nr_corpses = nr_corpses
				local corpse_disposal_id = self._corpse_disposal_id

				if corpse_disposal_id and nr_corpses <= self:corpse_limit() then
					self._corpse_disposal_id = nil

					self:remove_delayed_clbk(corpse_disposal_id)
				end
			end
		end
	end
end

function EnemyManager:register_shield(shield_unit)
	local unit_data_ext = shield_unit:unit_data()

	if unit_data_ext then
		unit_data_ext:add_destroy_listener(self._unit_clbk_key, callback(self, self, "unregister_shield"))
	else
		print("[EnemyManager:register_shield] ERROR - unit_data extension not found on shield unit ", shield_unit)
	end

	local t = self._timer:time()
	local enemy_data = self._enemy_data
	enemy_data.shields[shield_unit:key()] = {
		unit = shield_unit,
		death_t = t
	}
	local nr_shields = enemy_data.nr_shields + 1
	enemy_data.nr_shields = nr_shields
	local shield_disposal_id = self._shield_disposal_id

	if not shield_disposal_id then
		shield_disposal_id = "EnemyManager._upd_shield_disposal"
		self._shield_disposal_id = shield_disposal_id

		if self:shield_limit() < nr_shields then
			self._fast_shield_disposal = true

			self:add_delayed_clbk(shield_disposal_id, callback(self, self, "_upd_shield_disposal_fast"), t)
		else
			self:add_delayed_clbk(shield_disposal_id, callback(self, self, "_upd_shield_disposal"), t + self._shield_disposal_lifetime)
		end
	elseif not self._fast_shield_disposal and self:shield_limit() < nr_shields then
		self._fast_shield_disposal = false

		self:reschedule_delayed_clbk(shield_disposal_id, t)
	end
end

function EnemyManager:unregister_shield(shield_unit)
	local u_key = shield_unit:key()
	local enemy_data = self._enemy_data
	local shields = enemy_data.shields

	if not shields[u_key] then
		return
	end

	shields[u_key] = nil
	local nr_shields = enemy_data.nr_shields - 1
	enemy_data.nr_shields = nr_shields
	local shield_disposal_id = self._shield_disposal_id

	if not shield_disposal_id then
		return
	end

	if nr_shields == 0 then
		self._shield_disposal_id = nil
		self._fast_shield_disposal = false

		self:remove_delayed_clbk(shield_disposal_id)
	elseif self._fast_shield_disposal and nr_shields <= self:shield_limit() then
		self._fast_shield_disposal = false
		local delay = nil

		for u_key, u_data in pairs(shields) do
			local death_t = u_data.death_t

			if not delay or death_t < delay then
				delay = death_t
			end
		end

		delay = delay + self._shield_disposal_lifetime

		self:reschedule_delayed_clbk(shield_disposal_id, delay)
	end
end

function EnemyManager:_upd_shield_disposal()
	local t = self._timer:time()
	local enemy_data = self._enemy_data
	local nr_shields = enemy_data.nr_shields
	local disposals_needed = nr_shields - self:shield_limit()
	local shields = enemy_data.shields
	local player = managers.player:player_unit()
	local cam_pos, cam_fwd = nil

	if player then
		cam_pos = player:movement():m_head_pos()
		cam_fwd = player:camera():forward()
	elseif managers.viewport:get_current_camera() then
		cam_pos = managers.viewport:get_current_camera_position()
		cam_fwd = managers.viewport:get_current_camera_rotation():y()
	end

	local to_dispose = {}
	local nr_found = 0
	local disposal_life_t = self._shield_disposal_lifetime

	for u_key, u_data in pairs(shields) do
		if t > u_data.death_t + disposal_life_t then
			to_dispose[u_key] = true
			nr_found = nr_found + 1
		end
	end

	if nr_found < disposals_needed then
		if cam_pos then
			local min_dis = 90000
			local dot_chk = 0
			local dir_vec = tmp_vec1
			local u_pos = tmp_vec2

			for u_key, u_data in pairs(shields) do
				if not to_dispose[u_key] then
					local unit = u_data.unit

					unit:m_position(u_pos)

					if min_dis < mvec3_dis_sq(cam_pos, u_pos) then
						mvec3_dir(dir_vec, cam_pos, u_pos)

						if mvec3_dot(cam_fwd, dir_vec) < dot_chk then
							to_dispose[u_key] = true
							nr_found = nr_found + 1

							if nr_found == disposals_needed then
								break
							end
						end
					end
				end
			end
		end

		disposals_needed = disposals_needed - nr_found

		if disposals_needed > 0 then
			local oldest_shields = {}

			for u_key, u_data in pairs(shields) do
				if not to_dispose[u_key] then
					local death_t = u_data.death_t

					for i = disposals_needed, 1, -1 do
						local old_shield = oldest_shields[i]

						if not old_shield then
							old_shield = {
								t = death_t,
								key = u_key
							}
							oldest_shields[#oldest_shields + 1] = old_shield

							break
						elseif death_t < old_shield.t then
							old_shield.t = death_t
							old_shield.key = u_key

							break
						end
					end
				end
			end

			for i = 1, disposals_needed do
				to_dispose[oldest_shields[i].key] = true
			end

			nr_found = nr_found + disposals_needed
		end
	end

	for u_key, _ in pairs(to_dispose) do
		local unit = shields[u_key].unit
		shields[u_key] = nil

		unit:set_slot(0)
	end

	nr_shields = nr_shields - nr_found
	enemy_data.nr_shields = nr_shields

	if nr_shields > 0 then
		local delay = nil

		for u_key, u_data in pairs(shields) do
			local death_t = u_data.death_t

			if not delay or death_t < delay then
				delay = death_t
			end
		end

		delay = delay + disposal_life_t
		
		self:add_delayed_clbk(self._shield_disposal_id, callback(self, self, "_upd_shield_disposal"), delay)
	else
		self._shield_disposal_id = nil
	end
end

function EnemyManager:_update_queued_tasks(t, dt)
	local n_tasks = #self._queued_tasks
	
	if n_tasks > 0 then
		local tick_rate = tweak_data.group_ai.ai_tick_rate
		local max_buffer = tick_rate * n_tasks
		self._queue_buffer = math.min(self._queue_buffer + dt, tick_rate * n_tasks)

		while tick_rate <= self._queue_buffer do
			if #self._queued_tasks > 0 then
				local best_i_task, best_task_t 
				
				for i_task = 1, #self._queued_tasks do
					local task_data = self._queued_tasks[i_task]

					if not task_data.t then
						self:_execute_queued_task(i_task)

						self._queue_buffer = self._queue_buffer - tick_rate
						
						break
					elseif task_data.asap and not self._queued_task_executed or task_data.t < t then
						if not best_task_t or task_data.t < best_task_t then
							best_task_t = task_data.t
							best_i_task = i_task
						end
					end
				end
					
				if best_i_task then
					self:_execute_queued_task(best_i_task)
					
					self._queue_buffer = self._queue_buffer - tick_rate
				else
					break
				end
			else
				break
			end
		end
	else
		self._queue_buffer = 0
	end

	local all_clbks = self._delayed_clbks

	if all_clbks[1] and all_clbks[1][2] < t then
		local clbk = table.remove(all_clbks, 1)[3]

		clbk()
	end
end