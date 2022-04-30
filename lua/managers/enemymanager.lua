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