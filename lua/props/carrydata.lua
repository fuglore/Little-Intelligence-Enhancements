function CarryData:_chk_register_steal_SO()
	if not self._link_body then
		return
	end

	if not self._has_body_activation_clbk then
		local clbk = callback(self, self, "clbk_body_active_state")
		self._has_body_activation_clbk = {
			[self._link_body:key()] = clbk
		}

		self._unit:add_body_activation_callback(clbk)
		self._link_body:set_activate_tag(Idstring("bag_moving"))
		self._link_body:set_deactivate_tag(Idstring("bag_still"))
	end

	if not Network:is_server() or self._steal_SO_data or self._linked_to or self._zipline_unit or self._link_body:active() or not managers.navigation:is_data_ready() then
		return
	end

	if not self._AI_carry then
		return
	end

	local tracker_pickup = managers.navigation:create_nav_tracker(self._unit:position(), false)
	local pickup_nav_seg = tracker_pickup:nav_segment()
	local pickup_pos = tracker_pickup:field_position()
	local pickup_area = managers.groupai:state():get_area_from_nav_seg_id(pickup_nav_seg)

	managers.navigation:destroy_nav_tracker(tracker_pickup)

	if pickup_area.enemy_loot_drop_points then
		return
	end

	local drop_pos, drop_nav_seg, drop_area = nil
	local drop_point = managers.groupai:state():get_safe_enemy_loot_drop_point(pickup_nav_seg)

	if drop_point then
		drop_pos = mvector3.copy(drop_point.pos)
		drop_nav_seg = drop_point.nav_seg
		drop_area = drop_point.area
	elseif not self._register_steal_SO_clbk_id then
		self._register_steal_SO_clbk_id = "carrydata_registerSO" .. tostring(self._unit:key())

		managers.enemy:add_delayed_clbk(self._register_steal_SO_clbk_id, callback(self, self, "clbk_register_steal_SO"), TimerManager:game():time() + 10)

		return
	end

	local drop_objective = {
		type = "act",
		sabo_voiceline = "gatherloot",
		sabotage = true,
		interrupt_health = 0.5,
		path_ahead = true,
		action_duration = 1,
		haste = "run",
		pose = "crouch",
		interrupt_dis = 200,
		nav_seg = drop_nav_seg,
		pos = drop_pos,
		area = drop_area,
		fail_clbk = callback(self, self, "on_secure_SO_failed"),
		complete_clbk = callback(self, self, "on_secure_SO_completed"),
		action = {
			align_sync = true,
			type = "act",
			body_part = 1,
			variant = "untie",
			blocks = {
				action = -1,
				walk = -1
			}
		}
	}
	local pickup_objective = {
		destroy_clbk_key = false,
		sabotage = true,
		sabo_voiceline = "none",
		type = "act",
		action_duration = 1,
		haste = "run",
		interrupt_health = 0.5,
		pose = "crouch",
		interrupt_dis = 200,
		nav_seg = pickup_nav_seg,
		area = pickup_area,
		pos = pickup_pos,
		fail_clbk = callback(self, self, "on_pickup_SO_failed"),
		complete_clbk = callback(self, self, "on_pickup_SO_completed"),
		action = {
			align_sync = true,
			type = "act",
			body_part = 1,
			variant = "untie",
			blocks = {
				action = -1,
				walk = -1
			}
		},
		followup_objective = drop_objective
	}
	local so_descriptor = {
		interval = 0,
		base_chance = 1,
		chance_inc = 0,
		usage_amount = 1,
		objective = pickup_objective,
		search_pos = pickup_objective.pos,
		verification_clbk = callback(self, self, "clbk_pickup_SO_verification"),
		AI_group = self._AI_carry.SO_category,
		admin_clbk = callback(self, self, "on_pickup_SO_administered")
	}
	local so_id = "carrysteal" .. tostring(self._unit:key())
	self._steal_SO_data = {
		SO_registered = true,
		picked_up = false,
		SO_id = so_id,
		pickup_area = pickup_area,
		pickup_objective = pickup_objective,
		secure_pos = drop_pos,
		pickup_pos = pickup_pos
	}

	managers.groupai:state():add_special_objective(so_id, so_descriptor)
	managers.groupai:state():register_loot(self._unit, pickup_area)
end
