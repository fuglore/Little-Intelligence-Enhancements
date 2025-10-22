function CopLogicIntimidated.enter(data, new_logic_name, enter_params)
	CopLogicBase.enter(data, new_logic_name, enter_params)
	data.unit:brain():cancel_all_pathing_searches()

	local old_internal_data = data.internal_data
	local my_data = {
		unit = data.unit
	}
	data.internal_data = my_data
	my_data.detection = data.char_tweak.detection.combat
	my_data.aggressor_unit = enter_params and enter_params.aggressor_unit

	if data.attention_obj then
		CopLogicBase._set_attention_obj(data, nil, nil)
	end

	if old_internal_data and old_internal_data.nearest_cover then
		my_data.nearest_cover = old_internal_data.nearest_cover

		managers.navigation:reserve_cover(my_data.nearest_cover[1], data.pos_rsrv_id)
	end

	data.unit:movement():set_allow_fire(false)

	if data.objective then
		data.objective_failed_clbk(data.unit, data.objective)
	end

	if data.unit:anim_data().hands_tied then
		CopLogicIntimidated._do_tied(data, nil)
	else
		my_data.surrender_break_t = data.char_tweak.surrender_break_time and data.t + math.random(data.char_tweak.surrender_break_time[1], data.char_tweak.surrender_break_time[2], math.random())
		
		local key_str = tostring(data.key)
		my_data.update_task_key = "CopLogicIntimidated.queued_update" .. key_str

		CopLogicBase.queue_task(my_data, my_data.update_task_key, CopLogicIntimidated.queued_update, data, data.t + 0.2)
		
		data.unit:brain():set_update_enabled_state(true)
	end

	data.unit:sound():say("s01x", true)
	data.unit:movement():set_cool(false)

	if my_data ~= data.internal_data then
		return
	end

	data.unit:brain():set_attention_settings({
		corpse_sneak = true
	})

	my_data.is_hostage = true

	managers.groupai:state():on_hostage_state(true, data.key, true)
	managers.network:session():send_to_peers_synched("sync_unit_surrendered", data.unit, true)
end

function CopLogicIntimidated.register_rescue_SO(ignore_this, data)
	local my_data = data.internal_data

	CopLogicBase.on_delayed_clbk(my_data, my_data.delayed_rescue_SO_id)

	my_data.delayed_rescue_SO_id = nil
	local my_tracker = data.unit:movement():nav_tracker()
	local objective_pos = my_tracker:field_position()
	local followup_objective = {
		type = "act",
		action = {
			variant = "idle",
			body_part = 1,
			type = "act",
			blocks = {
				action = -1,
				walk = -1
			}
		}
	}
	local objective = {
		interrupt_health = 0.75,
		stance = "hos",
		type = "act",
		scan = true,
		destroy_clbk_key = false,
		interrupt_dis = 700,
		sabo_voiceline = "none",
		follow_unit = data.unit,
		pos = mvector3.copy(objective_pos),
		nav_seg = data.unit:movement():nav_tracker():nav_segment(),
		fail_clbk = callback(CopLogicIntimidated, CopLogicIntimidated, "on_rescue_SO_failed", data),
		complete_clbk = callback(CopLogicIntimidated, CopLogicIntimidated, "on_rescue_SO_completed", data),
		action = {
			variant = "untie",
			body_part = 1,
			type = "act",
			blocks = {
				action = -1,
				walk = -1
			}
		},
		action_duration = tweak_data.interaction.free.timer,
		followup_objective = followup_objective
	}
	local so_descriptor = {
		interval = 10,
		search_dis_sq = 1000000,
		AI_group = "enemies",
		base_chance = 1,
		chance_inc = 0,
		usage_amount = 1,
		objective = objective,
		search_pos = mvector3.copy(data.m_pos),
		admin_clbk = callback(CopLogicIntimidated, CopLogicIntimidated, "on_rescue_SO_administered", data),
		verification_clbk = callback(CopLogicIntimidated, CopLogicIntimidated, "rescue_SO_verification", data)
	}
	local so_id = "rescue" .. tostring(data.unit:key())
	my_data.rescue_SO_id = so_id

	managers.groupai:state():add_special_objective(so_id, so_descriptor)
	managers.groupai:state():register_rescueable_hostage(data.unit, nil)
end

function CopLogicIntimidated.queued_update(data)
	local my_data = data.internal_data

	CopLogicIntimidated._update_enemy_detection(data, my_data)

	if my_data ~= data.internal_data then
		return
	end
	
	if not data.unit:anim_data().hands_tied then
		if not my_data.update_task_key then
			log("logic: " .. data.name)
			
			return
		end
	
		CopLogicBase.queue_task(my_data, my_data.update_task_key, CopLogicIntimidated.queued_update, data, data.t + 0.2)
	end
end

function CopLogicIntimidated.exit(data, new_logic_name, enter_params)
	CopLogicBase.exit(data, new_logic_name, enter_params)

	local my_data = data.internal_data
	
	data.unit:brain():cancel_all_pathing_searches()
	CopLogicBase.cancel_queued_tasks(my_data)
	CopLogicBase.cancel_delayed_clbks(my_data)

	CopLogicIntimidated._unregister_rescue_SO(data, my_data)

	if new_logic_name ~= "inactive" then
		data.unit:base():set_slot(data.unit, 12)

		if my_data.tied then
			managers.network:session():send_to_peers_synched("sync_unit_event_id_16", data.unit, "brain", HuskCopBrain._NET_EVENTS.surrender_cop_untied)
		end
	end

	if my_data.nearest_cover then
		managers.navigation:release_cover(my_data.nearest_cover[1])
	end

	if new_logic_name ~= "inactive" then
		data.unit:brain():set_update_enabled_state(true)
		data.unit:interaction():set_active(false, true, false)
	end

	if my_data.tied then
		managers.groupai:state():on_enemy_untied(data.unit:key())
	end

	CopLogicIntimidated._unregister_harassment_SO(data, my_data)

	if my_data.surrender_clbk_registered then
		managers.groupai:state():remove_from_surrendered(data.unit)
	end

	if my_data.is_hostage then
		managers.groupai:state():on_hostage_state(false, data.key, true)
	end

	managers.network:session():send_to_peers_synched("sync_unit_surrendered", data.unit, false)
end

function CopLogicIntimidated._do_tied(data, aggressor_unit)
	local my_data = data.internal_data
	aggressor_unit = alive(aggressor_unit) and aggressor_unit

	if managers.groupai:state():rescue_state() then
		CopLogicIntimidated._add_delayed_rescue_SO(data, my_data)
	end

	if my_data.surrender_clbk_registered then
		managers.groupai:state():remove_from_surrendered(data.unit)

		my_data.surrender_clbk_registered = nil
	end

	my_data.tied = true

	data.unit:inventory():destroy_all_items()
	data.unit:brain():set_update_enabled_state(false)

	if my_data.update_task_key then
		managers.enemy:unqueue_task(my_data.update_task_key)

		my_data.update_task_key = nil
	end

	data.brain:rem_pos_rsrv("stand")
	managers.groupai:state():on_enemy_tied(data.unit:key())
	data.unit:base():set_slot(data.unit, 22)
	managers.network:session():send_to_peers_synched("sync_unit_event_id_16", data.unit, "brain", HuskCopBrain._NET_EVENTS.surrender_cop_tied)
	data.unit:movement():remove_giveaway()
	CopLogicIntimidated._chk_begin_alarm_pager(data)

	if not data.brain:is_pager_started() then
		data.unit:interaction():set_tweak_data("hostage_convert")
		data.unit:interaction():set_active(true, true, false)
	end

	if data.unit:unit_data().mission_element then
		data.unit:unit_data().mission_element:event("tied", data.unit)
	end

	if aggressor_unit then
		data.unit:character_damage():drop_pickup()
		data.unit:character_damage():set_pickup(nil)

		if aggressor_unit == managers.player:player_unit() then
			managers.statistics:tied({
				name = data.unit:base()._tweak_table
			})
		elseif aggressor_unit:base() and aggressor_unit:base().is_husk_player then
			aggressor_unit:network():send_to_unit({
				"statistics_tied",
				data.unit:base()._tweak_table
			})
		end
	end

	managers.groupai:state():on_criminal_suspicion_progress(nil, data.unit, nil)
end