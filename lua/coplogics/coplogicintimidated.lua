local tmp_vec1 = Vector3()
local tmp_vec2 = Vector3()

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
	
	if my_data.aggressor_unit then
		my_data.intimidator_units = {}
		my_data.intimidator_units[my_data.aggressor_unit:key()] = data.t + 2
	end

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
	data.t = TimerManager:game():time()

	CopLogicIntimidated._update_enemy_detection(data, my_data)

	if my_data ~= data.internal_data or not alive(data.unit) or data.unit:character_damage():dead() or not data.unit:movement() then
		return
	end
	
	if not my_data.tied then
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
		
		local anim_data = data.unit:anim_data()
	
		if anim_data.hands_up or anim_data.hands_back or anim_data.hands_tied then
			local new_action = {
				variant = "stand",
				body_part = 1,
				type = "act"
			}

			data.unit:brain():action_request(new_action)
		end
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

function CopLogicIntimidated._update_enemy_detection(data, my_data)
	if not alive(data.unit) or data.unit:character_damage():dead() or not data.unit:movement() then
		return
	end

	local fight = not my_data.tied
	
	if fight then
		if not my_data.surrender_break_t or data.t < my_data.surrender_break_t then
			local crim_fwd = tmp_vec2
			local max_intimidation_range = tweak_data.player.long_dis_interaction.intimidate_range_enemies * tweak_data.upgrades.values.player.intimidate_range_mul[1] * tweak_data.upgrades.values.player.passive_intimidate_range_mul[1] * 1.05

			for u_key, u_data in pairs(managers.groupai:state():all_criminals()) do
				if not u_data.is_deployable then
					if my_data.intimidator_units[u_key] and data.t < my_data.intimidator_units[u_key] then
						fight = nil
						
						break
					end
				
					local crim_unit = u_data.unit
					local crim_pos = u_data.m_pos
					local dis = mvector3.direction(tmp_vec1, data.m_pos, crim_pos)

					if dis < max_intimidation_range then
						mvector3.set(crim_fwd, crim_unit:movement():detect_look_dir())
						mvector3.set_z(crim_fwd, 0)
						mvector3.normalize(crim_fwd)

						if mvector3.dot(crim_fwd, tmp_vec1) < -0.2 then
							local vis_ray = data.unit:raycast("ray", data.unit:movement():m_head_pos(), u_data.m_det_pos, "slot_mask", data.visibility_slotmask, "ray_type", "ai_vision", "report")

							if not vis_ray then
								fight = nil

								break
							end
						end
					end
				end
			end
		end
	end

	if fight then
		if not my_data.fight_t then
			my_data.fight_t = data.t + 2
		end
		
		if my_data.fight_t < data.t then
			my_data.surrender_clbk_registered = nil

			data.brain:set_objective(nil)
			CopLogicBase._exit(data.unit, "idle")
		end
	else
		my_data.fight_t = nil
	end
end

function CopLogicIntimidated.on_intimidated(data, amount, aggressor_unit)
	local my_data = data.internal_data

	if not my_data.tied then
		data.t = TimerManager:game():time()
		
		if aggressor_unit then
			my_data.intimidator_units = my_data.intimidator_units or {}
			my_data.intimidator_units[aggressor_unit:key()] = data.t + 2
		end
		
		my_data.surrender_break_t = data.char_tweak.surrender_break_time and data.t + math.random(data.char_tweak.surrender_break_time[1], data.char_tweak.surrender_break_time[2], math.random())
		local anim_data = data.unit:anim_data()
		local anim, blocks = nil

		if anim_data.hands_up then
			anim = "hands_back"
			blocks = {
				heavy_hurt = -1,
				hurt = -1,
				action = -1,
				light_hurt = -1,
				walk = -1
			}
		elseif anim_data.hands_back then
			anim = "tied"
			blocks = {
				heavy_hurt = -1,
				hurt_sick = -1,
				action = -1,
				light_hurt = -1,
				hurt = -1,
				walk = -1
			}
		else
			if managers.groupai:state():whisper_mode() then
				anim = "tied_all_in_one"
			else
				anim = "hands_up"
			end

			blocks = {
				heavy_hurt = -1,
				hurt = -1,
				action = -1,
				light_hurt = -1,
				walk = -1
			}
		end

		local action_data = {
			clamp_to_graph = true,
			type = "act",
			body_part = 1,
			variant = anim,
			blocks = blocks
		}
		local act_action = data.unit:brain():action_request(action_data)

		if data.unit:anim_data().hands_tied then
			CopLogicIntimidated._do_tied(data, aggressor_unit)
		end
	end
end