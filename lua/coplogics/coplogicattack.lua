local mvec3_set = mvector3.set
local mvec3_add = mvector3.add
local mvec3_mul = mvector3.multiply
local mvec3_set_z = mvector3.set_z
local mvec3_sub = mvector3.subtract
local mvec3_dir = mvector3.direction
local mvec3_dot = mvector3.dot
local mvec3_dis = mvector3.distance
local mvec3_dis_sq = mvector3.distance_sq
local mvec3_lerp = mvector3.lerp
local mvec3_norm = mvector3.normalize
local temp_vec1 = Vector3()
local temp_vec2 = Vector3()
local temp_vec3 = Vector3()

function CopLogicAttack.enter(data, new_logic_name, enter_params)
	CopLogicBase.enter(data, new_logic_name, enter_params)
	data.unit:brain():cancel_all_pathing_searches()

	local old_internal_data = data.internal_data
	local my_data = {
		unit = data.unit
	}
	data.internal_data = my_data
	my_data.detection = data.char_tweak.detection.combat

	if old_internal_data then
		my_data.turning = old_internal_data.turning
		my_data.firing = old_internal_data.firing
		my_data.shooting = old_internal_data.shooting
		my_data.attention_unit = old_internal_data.attention_unit

		CopLogicAttack._set_best_cover(data, my_data, old_internal_data.best_cover)
	end

	my_data.cover_test_step = 0
	local key_str = tostring(data.key)

	CopLogicIdle._chk_has_old_action(data, my_data)

	if data.unit:base():has_tag("medic") then
		my_data.attitude = "avoid"
	else
		my_data.attitude = data.objective and data.objective.attitude or "avoid"
	end
	
	if data.char_tweak.weapon and data.char_tweak.weapon[data.unit:inventory():equipped_unit():base():weapon_tweak_data().usage] then
		my_data.weapon_range = data.char_tweak.weapon[data.unit:inventory():equipped_unit():base():weapon_tweak_data().usage].range
	end
	
	if not my_data.weapon_range then
		my_data.weapon_range = {
			optimal = 2000,
			far = 5000,
			close = 1000
		}
	end

	data.unit:brain():set_update_enabled_state(true)

	if data.cool then
		data.unit:movement():set_cool(false)
	end

	if (not data.objective or not data.objective.stance) and data.unit:movement():stance_code() == 1 then
		data.unit:movement():set_stance("hos")
	end

	if my_data ~= data.internal_data then
		return
	end
	
	CopLogicAttack._upd_enemy_detection(data, true)
	
	if my_data ~= data.internal_data then
		return
	end
	
	if data.objective and (data.objective.action_duration or data.objective.action_timeout_t and data.t < data.objective.action_timeout_t) then
		my_data.action_timeout_clbk_id = "CopLogicIdle_action_timeout" .. tostring(data.key)
		local action_timeout_t = data.objective.action_timeout_t or data.t + data.objective.action_duration
		data.objective.action_timeout_t = action_timeout_t

		CopLogicBase.add_delayed_clbk(my_data, my_data.action_timeout_clbk_id, callback(CopLogicIdle, CopLogicIdle, "clbk_action_timeout", data), action_timeout_t)
	end

	data.unit:brain():set_attention_settings({
		cbt = true
	})
end

function CopLogicAttack.queued_update(data)
	local my_data = data.internal_data
	data.t = TimerManager:game():time()
	
	CopLogicAttack._upd_enemy_detection(data, true)
	
	if data.internal_data == my_data then
		if data.attention_obj and AIAttentionObject.REACT_AIM <= data.attention_obj.reaction then
			CopLogicAttack.update(data)
		end
	end

	if data.internal_data == my_data then
		CopLogicAttack.queue_update(data, data.internal_data)
	end
end

function CopLogicAttack.queue_update(data, my_data)
	CopLogicBase.queue_task(my_data, my_data.update_queue_id, data.logic.queued_update, data, data.t + (data.important and 0 or 0.2), true)
end

local safe_dmg_types = {
	bullet = true,
	explosion = true,
	fire = true,
	melee = true
}

function CopLogicAttack.damage_clbk(data, damage_info)
	CopLogicIdle.damage_clbk(data, damage_info)
	
	if not safe_dmg_types[damage_info.variant] then
		return
	end

	if data.important and not data.is_converted then
		if not data.unit:movement():chk_action_forbidden("walk") then
			local my_data = data.internal_data

			if not my_data.tasing and not my_data.spooc_attack then
				CopLogicBase.chk_start_action_dodge(data, "hit")
			end
		end
	end
end

function CopLogicAttack._upd_enemy_detection(data, is_synchronous)
	managers.groupai:state():on_unit_detection_updated(data.unit)

	data.t = TimerManager:game():time()
	local my_data = data.internal_data
	local min_reaction = AIAttentionObject.REACT_AIM	
	local delay = CopLogicBase._upd_attention_obj_detection(data, min_reaction, nil)
	local new_attention, new_prio_slot, new_reaction = CopLogicIdle._get_priority_attention(data, data.detected_attention_objects, nil)
	local old_att_obj = data.attention_obj

	CopLogicBase._set_attention_obj(data, new_attention, new_reaction)
	data.logic._chk_exit_attack_logic(data, new_reaction)

	if my_data ~= data.internal_data then
		return
	end

	if new_attention then
		if old_att_obj and old_att_obj.u_key ~= new_attention.u_key then
			CopLogicAttack._cancel_charge(data, my_data)
			
			my_data.cover_test_step = 0
			my_data.flank_cover = nil
			my_data.charging = nil
		end
	elseif old_att_obj then
		CopLogicAttack._cancel_charge(data, my_data)
		
		my_data.cover_test_step = 0
		my_data.flank_cover = nil
		my_data.charging = nil
	end

	CopLogicBase._chk_call_the_police(data)

	if my_data ~= data.internal_data then
		return
	end
	
	if data.attention_obj and data.attention_obj.verified then
		my_data.charging = my_data.charging or my_data.flank_cover
		
		--stop the charge, we are not chargers we do not push unless nescessary
		if my_data.charging and not data.unit:movement():chk_action_forbidden("walk") then 
			if data.attention_obj.dis < 400 or LIES.settings.enemy_aggro_level < 4 and (not data.tactics or not data.tactics.charge) then
				local new_action = {
					body_part = 2,
					type = "idle"
				}

				data.unit:brain():action_request(new_action)
			
				CopLogicAttack._cancel_charge(data, my_data)
				my_data.at_cover_shoot_pos = true
			end
		end
		
		my_data.cover_test_step = 0
		my_data.flank_cover = nil
	end
	
	data.logic._upd_aim(data, my_data)

	if not is_synchronous then
		CopLogicBase.queue_task(my_data, my_data.detection_task_key, CopLogicAttack._upd_enemy_detection, data, delay and data.t + delay, data.important and true)
	end

	CopLogicBase._report_detections(data.detected_attention_objects)
end

function CopLogicAttack.update(data)
	local my_data = data.internal_data

	if my_data.has_old_action or my_data.old_action_advancing then
		CopLogicAttack._upd_stop_old_action(data, my_data)
		
		if my_data.has_old_action or my_data.old_action_advancing then
			if not my_data.update_queue_id then
				data.unit:brain():set_update_enabled_state(false)

				my_data.update_queue_id = "CopLogicAttack.queued_update" .. tostring(data.key)

				CopLogicAttack.queue_update(data, my_data)
			end
	
			return
		end
	end

	if CopLogicIdle._chk_relocate(data) then
		return
	end

	if CopLogicAttack._chk_exit_non_walkable_area(data) then
		return
	end

	CopLogicAttack._process_pathing_results(data, my_data)

	if not data.attention_obj or data.attention_obj.reaction < AIAttentionObject.REACT_AIM then
		CopLogicAttack._upd_enemy_detection(data, true)

		if my_data ~= data.internal_data or not data.attention_obj then
			return
		end
	end
	
	if AIAttentionObject.REACT_COMBAT <= data.attention_obj.reaction and not data.unit:movement():chk_action_forbidden("walk") then
		local want_to_take_cover = CopLogicAttack._chk_wants_to_take_cover(data, my_data)
			
		if data.char_tweak.chatter and data.char_tweak.chatter.suppress and my_data.attitude == "engage" and want_to_take_cover then
			if (data.important or data.unit:base():has_tag("special")) and want_to_take_cover ~= my_data.want_to_take_cover and not my_data.want_to_take_cover then
				local said = managers.groupai:state():chk_say_enemy_chatter(data.unit, data.m_pos, "wantcover")
				
				if not said and data.unit:base():has_tag("special") then
					if not data.next_priority_speak_t or data.next_priority_speak_t < data.t then
						if data.unit:sound():say("hlp", true) then
							data.next_priority_speak_t = data.t + 4
						end
					end
				end
			end
		end
		
		if data.attention_obj.hostage_blocked and not (data.tactics and data.tactics.hrt) then
			want_to_take_cover = true
		end
		
		my_data.want_to_take_cover = want_to_take_cover
		
		--log(tostring(my_data.attitude))

		CopLogicAttack._update_cover(data)
		
		if not data.next_mov_time or data.next_mov_time < data.t then
			CopLogicAttack._upd_combat_movement(data)
		end
	end
	
	if data.is_converted or data.check_crim_jobless or data.team.id == "criminal1" then
		if not data.objective or data.objective.type == "free" then
			if not data.path_fail_t or data.t - data.path_fail_t > 1 then
				managers.groupai:state():on_criminal_jobless(data.unit)

				if my_data ~= data.internal_data then
					return
				end
			end
		end
	end

	if not my_data.update_queue_id then
		data.unit:brain():set_update_enabled_state(false)

		my_data.update_queue_id = "CopLogicAttack.queued_update" .. tostring(data.key)

		CopLogicAttack.queue_update(data, my_data)
	end
end

function CopLogicAttack._chk_request_action_walk_to_cover_shoot_pos(data, my_data, path, speed)
	CopLogicAttack._cancel_cover_pathing(data, my_data)
	CopLogicAttack._cancel_charge(data, my_data)
	CopLogicAttack._correct_path_start_pos(data, path)

	local new_action_data = {
		body_part = 2,
		type = "walk",
		nav_path = path,
		variant = speed or "walk"
	}
	my_data.cover_path = nil
	my_data.advancing = data.unit:brain():action_request(new_action_data)

	if my_data.advancing then
		my_data.walking_to_cover_shoot_pos = my_data.advancing
		my_data.at_cover_shoot_pos = nil
		my_data.in_cover = nil

		data.brain:rem_pos_rsrv("path")
		
		CopLogicAttack._upd_aim(data, my_data)
		
		return true
	end
end

function CopLogicAttack._upd_combat_movement(data)
	local my_data = data.internal_data
	local t = data.t
	local unit = data.unit
	local focus_enemy = data.attention_obj
	local in_cover = my_data.in_cover
	local best_cover = my_data.best_cover
	local enemy_visible = focus_enemy.verified
	local enemy_visible_soft = focus_enemy.verified_t and t - focus_enemy.verified_t < 7
	local enemy_visible_softer = focus_enemy.verified_t and t - focus_enemy.verified_t < 15
	local alert_soft = data.is_suppressed
	local action_taken = data.logic.action_taken(data, my_data)
	local want_to_take_cover = my_data.want_to_take_cover
	action_taken = action_taken or CopLogicAttack._upd_pose(data, my_data)
	local move_to_cover, want_flank_cover = nil
	local aggro_level = LIES.settings.enemy_aggro_level
	local wanted_attack_range = my_data.wanted_attack_range

	--[[uncomment to draw cover stuff or whatever
		
	if my_data.moving_to_cover then
		local height = 41
		local line = Draw:brush(Color.blue:with_alpha(0.5), 0.2)
		line:cylinder(data.m_pos, my_data.moving_to_cover[1][1], 5)
		
		if my_data.moving_to_cover[5] then
			line:cylinder(my_data.moving_to_cover[5], my_data.moving_to_cover[1][1], 5)
			line:sphere(my_data.moving_to_cover[5], 8)
		end
		
		line:cylinder(my_data.moving_to_cover[1][1], my_data.moving_to_cover[1][1] + math.UP * height, 5)
	elseif my_data.in_cover then
		local height = my_data.in_cover[4] and 180 or 90
		local line = Draw:brush(Color.green:with_alpha(0.5), 0.2)
		if my_data.in_cover[5] then
			line:cylinder(my_data.in_cover[1][1], my_data.in_cover[5], 30)
			line:cylinder(my_data.in_cover[1][1], my_data.in_cover[1][1] + math.UP * height, 30)
		else
			line:cylinder(my_data.in_cover[1][1], my_data.in_cover[1][1] + math.UP * height, 30)
		end
	elseif my_data.best_cover then
		local height = 41
		local line = Draw:brush(Color.green:with_alpha(0.5), 0.2)
		line:cylinder(data.m_pos, my_data.best_cover[1][1], 5)
		
		if my_data.best_cover[5] then
			line:cylinder(my_data.best_cover[5], my_data.best_cover[1][1], 5)
			line:sphere(my_data.best_cover[5], 8)
		end
		
		line:cylinder(my_data.best_cover[1][1], my_data.best_cover[1][1] + math.UP * height, 5)
	end
	
	if data.attention_obj.verified then
		if my_data.surprised then
			local line = Draw:brush(Color.blue:with_alpha(0.25), 0.2)
			line:sphere(data.unit:movement():m_head_pos(), 30)
		elseif my_data.want_to_take_cover then
			local line = Draw:brush(Color.yellow:with_alpha(0.25), 0.2)
			line:sphere(data.unit:movement():m_head_pos(), 30)
		elseif my_data.walking_to_cover_shoot_pos or my_data.at_cover_shoot_pos then
			local line = Draw:brush(Color.red:with_alpha(0.25), 0.2)
			line:cylinder(data.m_pos, data.unit:movement():m_head_pos(), 60)
		end
	else
		if my_data.walking_to_cover_shoot_pos or my_data.at_cover_shoot_pos then
			local line = Draw:brush(Color.red:with_alpha(0.25), 0.2)
			line:cylinder(data.m_pos, data.unit:movement():m_head_pos(), 60)
		else
			local line = Draw:brush(Color.blue:with_alpha(0.25), 0.2)
			line:cylinder(data.m_pos, data.unit:movement():m_head_pos(), 60)
		end
	end]]

	if my_data.cover_test_step ~= 0 and not enemy_visible_softer and (action_taken or want_to_take_cover or not in_cover) then
		my_data.cover_test_step = 0
	end

	if my_data.stay_out_time and (enemy_visible and focus_enemy.aimed_at or not my_data.at_cover_shoot_pos or action_taken or want_to_take_cover) then
		my_data.stay_out_time = nil
	elseif my_data.attitude == "engage" and not my_data.stay_out_time and not enemy_visible and my_data.at_cover_shoot_pos and not action_taken and not want_to_take_cover then
		my_data.stay_out_time = t + 7
	end
	
	local can_charge
	
	if not data.tactics or not data.tactics.sniper then
		can_charge = aggro_level > 3 or my_data.flank_cover and my_data.flank_cover.failed or data.tactics and data.tactics.charge or wanted_attack_range and focus_enemy.dis > wanted_attack_range or wanted_attack_range and not enemy_visible
	end

	if action_taken then
		-- Nothing
	elseif want_to_take_cover or data.is_converted then
		move_to_cover = true
	elseif not enemy_visible then --no longer requires a group objective to work, takes into account flank cover and just generally not seeing enemies in a while
		if can_charge and (not my_data.charge_path_failed_t or data.t - my_data.charge_path_failed_t > 2) then
			if my_data.charge_path then
				local path = my_data.charge_path
				my_data.charge_path = nil
				local haste = "walk"
				
				if not data.char_tweak.walk_only then
					if data.tactics and data.tactics.charge or aggro_level > 2 then
						haste = "run"
					end
				end
				
				action_taken = CopLogicAttack._chk_request_action_walk_to_cover_shoot_pos(data, my_data, path, haste)
				
				if action_taken then
					my_data.charging = true
				end
			elseif not my_data.charge_path_search_id and data.attention_obj.nav_tracker then
				my_data.charge_pos = CopLogicAttack._find_charge_pos(data, my_data, data.attention_obj.nav_tracker, wanted_attack_range and wanted_attack_range * 0.9 or my_data.weapon_range.close)

				if my_data.charge_pos then
					my_data.charge_path_search_id = "charge" .. tostring(data.key)

					unit:brain():search_for_path(my_data.charge_path_search_id, my_data.charge_pos, nil, nil, nil)
				else
					debug_pause_unit(data.unit, "failed to find charge_pos", data.unit)

					my_data.charge_path_failed_t = TimerManager:game():time()
				end
			end
		elseif aggro_level < 4 and focus_enemy.verified_t and t - focus_enemy.verified_t < 2 and best_cover and (not in_cover or best_cover[1] ~= in_cover[1]) then
			move_to_cover = true
		elseif in_cover then
			local my_tracker = unit:movement():nav_tracker()
			local m_tracker_pos = my_tracker:position()
			
			if my_data.in_cover[7] then
				local path = {
					m_tracker_pos,
					mvector3.copy(my_data.in_cover[5])
				}
				
				action_taken = CopLogicAttack._chk_request_action_walk_to_cover_offset_pos(data, my_data, path)
			elseif my_data.cover_test_step <= 2 then
				local height = nil

				if in_cover[4] then
					height = 165
				else
					height = 82.5
				end
				
				local aim_pos = focus_enemy.verified_pos
				
				--make this into a loop to save updates
				local reservation = {
					radius = 30,
					filter = data.pos_rsrv_id
				}
				
				while my_data.cover_test_step < 3 do
					local shoot_from_pos = CopLogicAttack._peek_for_pos_sideways(data, my_data, my_tracker, aim_pos, height)

					if shoot_from_pos then
						reservation.position = shoot_from_pos
						if not managers.navigation:is_pos_free(reservation) then
							local path = {
								m_tracker_pos,
								shoot_from_pos
							}
							action_taken = CopLogicAttack._chk_request_action_walk_to_cover_shoot_pos(data, my_data, path, "walk")

							break
						end
					end
					
					my_data.cover_test_step = my_data.cover_test_step + 1
				end
			elseif not enemy_visible_soft then
				move_to_cover = true
				
				if not data.tactics or not data.tactics.sniper then
					want_flank_cover = true
				end
			end
		elseif my_data.walking_to_cover_shoot_pos then
			-- Nothing
		elseif my_data.at_cover_shoot_pos then
			if not my_data.stay_out_time or my_data.stay_out_time < t then
				move_to_cover = true
			end
		else
			move_to_cover = true
		end
	elseif my_data.at_cover_shoot_pos and aggro_level < 4 then
		if not my_data.stay_out_time or my_data.stay_out_time < t then
			move_to_cover = true
		end
	else
		if (not my_data.charge_path_failed_t or data.t - my_data.charge_path_failed_t > 2) then
			if can_charge then
				if my_data.charge_path then
					local path = my_data.charge_path
					my_data.charge_path = nil
					local haste = "walk"
				
					if not data.char_tweak.walk_only then
						if data.tactics and data.tactics.charge or aggro_level > 2 then
							haste = "run"
						end
					end
					
					action_taken = CopLogicAttack._chk_request_action_walk_to_cover_shoot_pos(data, my_data, path, haste)
					
					if action_taken then
						my_data.charging = true
					end
				elseif not my_data.charge_path_search_id and data.attention_obj.nav_tracker then
					my_data.charge_pos = CopLogicAttack._find_charge_pos(data, my_data, data.attention_obj.nav_tracker, wanted_attack_range and wanted_attack_range * 0.9 or my_data.weapon_range.close)

					if my_data.charge_pos then
						my_data.charge_path_search_id = "charge" .. tostring(data.key)

						unit:brain():search_for_path(my_data.charge_path_search_id, my_data.charge_pos, nil, nil, nil)
					else
						debug_pause_unit(data.unit, "failed to find charge_pos", data.unit)

						my_data.charge_path_failed_t = TimerManager:game():time()
					end
				end
			else
				move_to_cover = true
			end
		else
			move_to_cover = true
		end
	end
	
	local have_flank_cover = my_data.flank_cover and true
	
	if want_flank_cover then
		if not my_data.flank_cover then
			local sign = math.random() < 0.5 and -1 or 1
			local step = 30
			my_data.flank_cover = {
				step = step,
				angle = step * sign,
				sign = sign
			}
		end
	else
		my_data.flank_cover = nil
	end
	
	if not want_flank_cover or want_flank_cover and have_flank_cover then
		if not action_taken and move_to_cover and my_data.cover_path then
			if not best_cover then
				--log("path is outdated, something funky happened in taserlogicattack probably")
				my_data.cover_path = nil
			else
				action_taken = CopLogicAttack._chk_request_action_walk_to_cover(data, my_data)
			end
		elseif not my_data.cover_path and not my_data.cover_path_search_id and not action_taken and best_cover and (not in_cover or best_cover[1] ~= in_cover[1]) and (not my_data.cover_path_failed_t or data.t - my_data.cover_path_failed_t > 2) then
			my_data.cover_path_search_id = tostring(unit:key()) .. "cover"

			data.unit:brain():search_for_path_to_cover(my_data.cover_path_search_id, best_cover[1], best_cover[5])
		end
	end

	if not data.is_converted and not my_data.turning and not data.unit:movement():chk_action_forbidden("walk") and CopLogicAttack._can_move(data) and data.attention_obj.verified and (not in_cover or not in_cover[4]) then
		if data.is_suppressed and data.t - data.unit:character_damage():last_suppression_t() < 0.7 then
			action_taken = CopLogicBase.chk_start_action_dodge(data, "scared")
		end

		if not action_taken and focus_enemy.is_person and focus_enemy.dis < 2000 and (data.group and data.group.size > 1 or math.random() < 0.5) then
			local dodge = nil

			if focus_enemy.is_local_player then
				local e_movement_state = focus_enemy.unit:movement():current_state()

				if not e_movement_state:_is_reloading() and not e_movement_state:_interacting() and not e_movement_state:is_equipping() then
					dodge = true
				end
			else
				local e_anim_data = focus_enemy.unit:anim_data()

				if (e_anim_data.move or e_anim_data.idle) and not e_anim_data.reload then
					dodge = true
				end
			end

			if dodge and focus_enemy.aimed_at then
				action_taken = CopLogicBase.chk_start_action_dodge(data, "preemptive")
			end
		end
	end

	if not action_taken and (want_to_take_cover or move_to_cover) and not best_cover then
		action_taken = CopLogicAttack._chk_start_action_move_back(data, my_data, focus_enemy, false)
	end

	action_taken = action_taken or CopLogicAttack._chk_start_action_move_out_of_the_way(data, my_data)
end

function CopLogicAttack.action_taken(data, my_data)
	return my_data.advancing or my_data.turning or my_data.moving_to_cover or my_data.walking_to_cover_shoot_pos or my_data.surprised or my_data.has_old_action or data.unit:movement():chk_action_forbidden("walk")
end

function CopLogicAttack._pathing_complete_clbk(data)
	local my_data = data.internal_data
	
	if my_data.exiting or my_data.spooc_attack or my_data.tasing then
		return
	end
	
	local focus_enemy = data.attention_obj

	if not focus_enemy or focus_enemy.reaction < AIAttentionObject.REACT_COMBAT then
		return
	end
	
	CopLogicAttack._process_pathing_results(data, my_data)
	CopLogicAttack._upd_combat_movement(data)
	local action_taken = data.logic.action_taken(data, my_data)
	
	if not action_taken then
		data.logic._update_cover(data)
	end
end

function CopLogicAttack._chk_wants_to_take_cover(data, my_data)
	local ammo_max, ammo = data.unit:inventory():equipped_unit():base():ammo_info()

	if ammo <= 0 then
		return true
	end

	if not data.attention_obj or data.attention_obj.reaction < AIAttentionObject.REACT_COMBAT then
		return
	end
	
	if data.tactics and data.tactics.sniper then
		if data.attention_obj.verified_t and data.t - data.attention_obj.verified_t < 2 and data.attention_obj.aimed_at then
			return true
		end
	end
	
	local aggro_level = LIES.settings.enemy_aggro_level
	
	if my_data.attitude ~= "engage" then
		return true
	end
	
	if aggro_level > 3 then
		return
	end
	
	if data.unit:anim_data().reload then
		return true
	end
	
	if aggro_level < 3 then
		if data.is_suppressed then
			return true
		end
		
		if ammo / ammo_max < 0.2 then
			return true
		end
		
		if data.attention_obj.verified then
			if aggro_level < 2 and data.attention_obj.aimed_at or not data.tactics or (data.tactics.ranged_fire or data.tactics.sniper) and my_data.weapon_range.close < data.attention_obj.verified_dis then
				if my_data.firing then
					return true
				end
			end
		end
	end
end

function CopLogicAttack.chk_should_turn(data, my_data)
	return not my_data.optimal_path and not my_data.turning and not my_data.has_old_action and not data.unit:movement():chk_action_forbidden("walk") and not my_data.moving_to_cover and not my_data.walking_to_cover_shoot_pos and not my_data.surprised and not my_data.advancing
end

function CopLogicAttack._check_needs_reload(data, my_data)
	if data.unit:anim_data().reload then
		return true
	end
	
	local weapon, weapon_base, ammo_max, ammo

	if alive(data.unit) and data.unit:inventory() then
		weapon = data.unit:inventory():equipped_unit()
	
		if weapon and alive(weapon) then
			weapon_base = weapon and weapon:base()
			ammo_max, ammo = weapon_base:ammo_info()
			local state = data.name
			
			if ammo / ammo_max > 0.2 then
				return true
			end
		end
	end
	
	if not ammo then
		return true
	end
	
	local needs_reload = nil
	
	if ammo <= 1 or ammo / ammo_max <= 0.2 then
		needs_reload = true
	end
	
	if needs_reload then
		local ammo_base = weapon_base and weapon_base:ammo_base()
		
		if ammo_base then
			ammo_base:set_ammo_remaining_in_clip(0)
			
			if not my_data.shooting then
				local shoot_action = {
					body_part = 3,
					type = "shoot"
				}

				if data.unit:brain():action_request(shoot_action) then
					my_data.shooting = true
				end
			end
		end
	end
end

function CopLogicAttack._upd_aim(data, my_data)
	local shoot, aim, expected_pos = nil
	local focus_enemy = data.attention_obj
	local walk_action, walk_dir

	if focus_enemy and AIAttentionObject.REACT_AIM <= focus_enemy.reaction then
		local last_sup_t = data.unit:character_damage():last_suppression_t()

		if LIES.settings.hhtacs and (focus_enemy.verified_t and data.t - focus_enemy.verified_t < 2 or my_data.shooting) then
			if focus_enemy.hostage_blocked then
				if data.important then
					if data.char_tweak.chatter and data.char_tweak.chatter.ready then
						managers.groupai:state():chk_say_enemy_chatter(data.unit, data.m_pos, "hostageblock")
					end
				end
			
				if data.brain:request_switch_to_safe_weapon(3) then
					if my_data.shooting then
						local new_action = {
							body_part = 3,
							type = "idle"
						}

						data.unit:brain():action_request(new_action)
					end
					
					if my_data.firing then
						data.unit:movement():set_allow_fire(false)

						my_data.firing = nil
					end
				end
			elseif data.safe_equipped and data.brain:request_switch_to_normal_weapon(7) then
				if my_data.shooting then
					local new_action = {
						body_part = 3,
						type = "idle"
					}

					data.unit:brain():action_request(new_action)
				end
				
				if my_data.firing then
					data.unit:movement():set_allow_fire(false)

					my_data.firing = nil
				end
			end
		end
		
		if not data.char_tweak.always_face_enemy and not focus_enemy.dangerous_special then
			if my_data.low_value_att or data.unit:anim_data().run and my_data.weapon_range.close < focus_enemy.dis and not (data.tactics and data.tactics.sniper) then
				walk_action = my_data.advancing 
			
				if walk_action and walk_action._init_called and walk_action._footstep_pos  then --do this properly
					local pos_for_dir = walk_action._footstep_pos
					walk_dir = pos_for_dir - data.m_pos
					walk_dir = walk_dir:with_z(0):normalized()

					mvec3_dir(temp_vec2, data.m_pos, focus_enemy.m_pos)
					mvec3_set_z(temp_vec2, 0)

					local dot = mvec3_dot(walk_dir, temp_vec2)

					if dot < 0.7 then
						shoot = false
						aim = false
					end
				end
			end
		end
		
		local firing_range = running and my_data.weapon_range.close or my_data.weapon_range.far

		if focus_enemy.verified or focus_enemy.nearly_visible then
			if aim == nil and AIAttentionObject.REACT_AIM <= focus_enemy.reaction then
				if AIAttentionObject.REACT_SHOOT <= focus_enemy.reaction then

					if AIAttentionObject.REACT_SHOOT == focus_enemy.reaction then
						shoot = true
					end
					
					if not shoot and my_data.attitude == "engage" then
						shoot = true
					end

					if not shoot then
						if data.unit:base():has_tag("law") and not data.is_converted then
							if focus_enemy.criminal_record and focus_enemy.criminal_record.assault_t and data.t - focus_enemy.criminal_record.assault_t < 7 then
								shoot = true
							elseif focus_enemy.dis < firing_range then
								shoot = true
							else
								aim = true
							end
						else
							shoot = true
						end
					end

					aim = aim or shoot
				else
					aim = true
				end
			end
		elseif AIAttentionObject.REACT_AIM <= focus_enemy.reaction then
			local time_since_verification = focus_enemy.verified_t and data.t - focus_enemy.verified_t
				
			if time_since_verification and aim == nil then
				local running = data.unit:anim_data().run

				if running and not data.char_tweak.always_face_enemy then
					if time_since_verification < math.lerp(5, 1, math.max(0, focus_enemy.verified_dis - 500) / 600) then
						aim = true
					end
				elseif time_since_verification < 10 then
					aim = true
				end

				if aim and (data.char_tweak.always_face_enemy or time_since_verification < 3) and AIAttentionObject.REACT_SHOOT <= focus_enemy.reaction then
					if AIAttentionObject.REACT_SHOOT == focus_enemy.reaction then
						shoot = true
					end
					
					if not shoot and my_data.attitude == "engage" then
						shoot = true
					end
					
					if not shoot then
						if data.unit:base():has_tag("law") and not data.is_converted then
							if focus_enemy.criminal_record and focus_enemy.criminal_record.assault_t and data.t - focus_enemy.criminal_record.assault_t < 7 then
								shoot = true
							elseif focus_enemy.dis < firing_range then
								shoot = true
							else
								aim = true
							end
						else
							shoot = true
						end
					end
				end
			end
		end

		CopLogicAttack._chk_enrage(data, focus_enemy)
	end
	
	if shoot and focus_enemy and not data.safe_equipped and not focus_enemy.hostage_blocked then
		LIESBossLogicAttack._chk_use_throwable(data, my_data, focus_enemy)
	end

	if not aim then
		if data.char_tweak.always_face_enemy or my_data.walking_to_cover_shoot_pos then
			if focus_enemy and AIAttentionObject.REACT_COMBAT <= focus_enemy.reaction then
				aim = true
			end
		end
	end
	
	if shoot and data.tactics and data.tactics.harass and data.char_tweak.chatter and data.char_tweak.chatter.clear and focus_enemy.verified then
		if focus_enemy.is_local_player then
			local cur_state = focus_enemy.unit:movement():current_state()
			
			if cur_state:_is_reloading() then
				managers.groupai:state():chk_say_enemy_chatter(data.unit, data.m_pos, "calloutreload")
			end
		else
			local focus_anim_data = focus_enemy.unit:anim_data()

			if focus_anim_data and focus_anim_data.reload then
				managers.groupai:state():chk_say_enemy_chatter(data.unit, data.m_pos, "calloutreload")
			end
		end
	end
	
	aim = shoot or aim

	if aim or shoot then
		if focus_enemy.verified then		
			if my_data.attention_unit ~= focus_enemy.u_key then
				CopLogicBase._set_attention(data, focus_enemy)

				my_data.attention_unit = focus_enemy.u_key
			end
		elseif focus_enemy.nearly_visible then
			local look_pos = focus_enemy.verified_pos
			if my_data.attention_unit ~= look_pos then
				CopLogicBase._set_attention_on_pos(data, mvector3.copy(look_pos))

				my_data.attention_unit = mvector3.copy(look_pos)
			end
		else
			local look_pos = focus_enemy.last_verified_pos or focus_enemy.verified_pos

			if my_data.attention_unit ~= look_pos then
				CopLogicBase._set_attention_on_pos(data, mvector3.copy(look_pos))

				my_data.attention_unit = mvector3.copy(look_pos)
			end
		end
		
		if not my_data.shooting and not my_data.spooc_attack and not data.unit:movement():chk_action_forbidden("action") then
			local shoot_action = {
				body_part = 3,
				type = "shoot"
			}

			if data.unit:brain():action_request(shoot_action) then
				my_data.shooting = true
			end
		end
	else
		if not data.unit:movement():chk_action_forbidden("action") and not data.unit:anim_data().reload and CopLogicAttack._check_needs_reload(data, my_data) then
			if my_data.shooting then
				local new_action = {
					body_part = 3,
					type = "idle"
				}

				data.unit:brain():action_request(new_action)
			end
		end
		
		if my_data.advancing then
			local walk_action = my_data.advancing 
			
			if not walk_action._expired and walk_action._init_called and walk_action._footstep_pos then --did the init get fucking called properly? yes? please start checking the walk direction
				local walk_pos = mvector3.copy(data.m_pos)
				local pos_for_dir = walk_action._footstep_pos
				local walk_dir_pos = pos_for_dir - walk_pos
				mvec3_norm(walk_dir_pos)
				mvec3_mul(walk_dir_pos, 500)

				mvec3_add(walk_pos, walk_dir_pos)
				mvec3_add(walk_pos, math.UP * 165)
	
				if my_data.attention_unit ~= walk_pos then
					CopLogicBase._set_attention_on_pos(data, mvector3.copy(walk_pos))

					my_data.attention_unit = mvector3.copy(walk_pos)
				end
			elseif my_data.attention_unit then
				CopLogicBase._reset_attention(data)

				my_data.attention_unit = nil
			end
		elseif my_data.attention_unit then
			CopLogicBase._reset_attention(data)

			my_data.attention_unit = nil
		end
	end
	
	if not my_data.advancing and CopLogicAttack.chk_should_turn(data, my_data) and my_data.attention_unit then
		local enemy_pos
		
		if my_data.attention_unit ~= focus_enemy.u_key then
			enemy_pos = my_data.attention_unit
		else
			enemy_pos = focus_enemy.m_pos
		end

		CopLogicAttack._chk_request_action_turn_to_enemy(data, my_data, data.m_pos, enemy_pos)
	end
	
	if focus_enemy and AIAttentionObject.REACT_COMBAT <= focus_enemy.reaction then
		if LIES.settings.enemy_reaction_level < 3 and not data.unit:in_slot(16) then
			if not focus_enemy.react_t then
				focus_enemy.react_t = data.t
			end
		
			if not focus_enemy.verified_t or data.t - focus_enemy.verified_t > 2 then
				focus_enemy.react_t = data.t
			end
		
			local react_t = 2 / LIES.settings.enemy_reaction_level
		
			if data.t - focus_enemy.react_t < react_t then
				shoot = nil
			end
		end
	end

	CopLogicAttack.aim_allow_fire(shoot, aim, data, my_data)
end

function CopLogicAttack._chk_request_action_turn_to_enemy(data, my_data, my_pos, enemy_pos)
	local fwd = data.unit:movement():m_fwd()
	local target_vec = temp_vec1
	mvector3.direction(target_vec, my_pos, enemy_pos)
	mvec3_set_z(target_vec, 0)
	local error_spin = target_vec:to_polar_with_reference(fwd, math.UP).spin

	if math.abs(error_spin) > 27 then
		local new_action_data = {
			type = "turn",
			body_part = 2,
			angle = error_spin
		}

		if data.unit:brain():action_request(new_action_data) then
			my_data.turning = new_action_data.angle

			return true
		end
	end
end

function CopLogicAttack._peek_for_pos_sideways(data, my_data, from_racker, peek_to_pos, height, short_back_vec)
	local unit = data.unit
	local my_tracker = from_racker
	local enemy_pos = peek_to_pos
	local my_pos = unit:movement():m_pos()
	local back_vec = my_pos - enemy_pos
	
	if short_back_vec then
		mvector3.set_z(back_vec, 0)
		mvector3.set_length(back_vec, 30)
	else
		mvector3.set_z(back_vec, 0)
		mvector3.set_length(back_vec, 75)
	end
	
	local back_pos = my_pos + back_vec
	local ray_params = {
		allow_entry = true,
		trace = true,
		tracker_from = my_tracker,
		pos_to = back_pos
	}
	local ray_res = managers.navigation:raycast(ray_params)
	back_pos = ray_params.trace[1]
	local back_polar = (back_pos - my_pos):to_polar()
	local right_polar = back_polar:with_spin(back_polar.spin + 90):with_r(100 + 80 * my_data.cover_test_step)
	local right_vec = right_polar:to_vector()
	local right_pos = back_pos + right_vec
	ray_params.pos_to = right_pos
	local ray_res = managers.navigation:raycast(ray_params)
	local shoot_from_pos, found_shoot_from_pos = nil
	local ray_softness = 60
	local stand_ray = World:raycast("ray", ray_params.trace[1] + math.UP * height, enemy_pos, "slot_mask", data.visibility_slotmask, "ray_type", "ai_vision")

	if not stand_ray or mvector3.distance(stand_ray.position, enemy_pos) < ray_softness then
		shoot_from_pos = ray_params.trace[1]
		found_shoot_from_pos = true
	end

	if not found_shoot_from_pos then
		local left_pos = back_pos - right_vec
		ray_params.pos_to = left_pos
		local ray_res = managers.navigation:raycast(ray_params)
		local stand_ray = World:raycast("ray", ray_params.trace[1] + math.UP * height, enemy_pos, "slot_mask", data.visibility_slotmask, "ray_type", "ai_vision")

		if not stand_ray or mvector3.distance(stand_ray.position, enemy_pos) < ray_softness then
			shoot_from_pos = ray_params.trace[1]
			found_shoot_from_pos = true
		end
	end

	return shoot_from_pos
end

function CopLogicAttack._chk_enrage(data, focus_enemy)
	if not data.char_tweak or not data.char_tweak.enrages then
		return
	end
	
	local enrage_data = data.enrage_data or {
		enrage_meter = 0,
		last_chk_t = data.t - 0.2,
		enraged = false,
		enrage_max = 5 + math.random(0, 5)
	}
	
	local dt = data.t - enrage_data.last_chk_t

	local increase = nil
	
	if focus_enemy then
		if AIAttentionObject.REACT_COMBAT <= focus_enemy.reaction and focus_enemy.dis < 1000 then
			if focus_enemy.verified or focus_enemy.verified_t and data.t - focus_enemy.verified_t < 2 then
				increase = true
			end
		end
	end
	
	if increase and not enrage_data.enraged then
		enrage_data.enrage_meter = enrage_data.enrage_meter + dt
		
		if enrage_data.enrage_meter >= enrage_data.enrage_max then
			enrage_data.enraged = true
			enrage_data.enrage_buff_id = data.unit:base():add_buff("base_damage", 1)
			
			if not data.internal_data.turning then
				if not data.unit:movement():chk_action_forbidden("walk") then
					local action_data = {
						variant = "surprised",
						body_part = 1,
						type = "act",
						blocks = {
							action = -1,
							walk = -1
						}
					}

					data.unit:brain():action_request(action_data)
					
				end
			end
			
			data.unit:sound():play("tire_blow", nil, true)
			data.unit:sound():play("kick_metal_door", nil, true)
			data.unit:sound():play("security_camera_explode", nil, true)
			data.unit:sound():play("pot_large_shatter", nil, true)
			
			if enrage_data.played_warning then
				data.unit:sound():play("slot_machine_win", nil, true)
				enrage_data.played_warning = nil
			end
			
			enrage_data.enrage_meter = 5
		elseif not enrage_data.played_warning and enrage_data.enrage_meter > enrage_data.enrage_max * 0.75 then
			data.unit:sound():play("slot_machine_rolling_loop", nil, true)
			data.unit:sound():play("light_bulb_smash", nil, true)

			enrage_data.played_warning = true
		end
	else
		enrage_data.enrage_meter = enrage_data.enrage_meter - dt
		
		if enrage_data.enrage_meter <= 0 then
			if enrage_data.enraged then
				enrage_data.enrage_max = 5 + math.random(0, 5)
			end
			
			enrage_data.enrage_meter = 0
			enrage_data.enraged = false
			
			if enrage_data.enrage_buff_id then
				data.unit:base():remove_buff_by_id("base_damage", enrage_data.enrage_buff_id)
				
				enrage_data.enrage_buff_id = nil
			end
		end
		
		if enrage_data.played_warning then
			data.unit:sound():play("slot_machine_loose", nil, true)
			data.unit:sound():play("trombone_break", nil, true)
			enrage_data.played_warning = nil
		end
	end
	
	enrage_data.last_chk_t = data.t
	
	data.enrage_data = data.enrage_data or enrage_data
end

function CopLogicAttack.aim_allow_fire(shoot, aim, data, my_data)
	local focus_enemy = data.attention_obj
	
	if shoot then 	
		if not my_data.firing then		
			data.unit:movement():set_allow_fire(true)

			my_data.firing = true
			
			if focus_enemy and AIAttentionObject.REACT_COMBAT <= focus_enemy.reaction and not data.unit:in_slot(16) and data.char_tweak.chatter then
				if alive(focus_enemy.unit) and focus_enemy.unit:base() and focus_enemy.unit:base().sentry_gun and data.char_tweak.chatter.ready then
					managers.groupai:state():chk_say_enemy_chatter(data.unit, data.m_pos, "sentry")
				elseif data.char_tweak.chatter.aggressive then
					if managers.groupai:state():is_detection_persistent() or not data.unit:base():has_tag("law") then
						if data.important or data.unit:base():has_tag("special") then
							local said = managers.groupai:state():chk_say_enemy_chatter(data.unit, data.m_pos, "aggressive")
							
							if not said and data.unit:base():has_tag("special") then
								if not data.next_priority_speak_t or data.next_priority_speak_t < data.t then
									if data.unit:sound():say("g90", true) then
										data.next_priority_speak_t = data.t + 4
									end
								end
							end
						end
					end
				end
			end
		end
	elseif my_data.firing then
		data.unit:movement():set_allow_fire(false)

		my_data.firing = nil
	end
	
	CopLogicBase.upd_falloff_sim(data)
end

function CopLogicAttack._move_back_into_field_position(data, my_data)
	local my_tracker = data.unit:movement():nav_tracker()
	
	if my_tracker:lost() then
		local field_position = my_tracker:field_position()
		
		if mvec3_dis_sq(data.m_pos, field_position) > 900 then	
			local path = {
				mvector3.copy(data.m_pos),
				field_position
			}

			return CopLogicAttack._chk_request_action_walk_to_cover_shoot_pos(data, my_data, path, "walk")
		end
	else
		local position = managers.navigation:pad_out_position(data.m_pos, 4, data.char_tweak.wall_fwd_offset)
		
		if mvec3_dis_sq(data.m_pos, position) > 100 then	
			local path = {
				mvector3.copy(data.m_pos),
				position
			}

			return CopLogicAttack._chk_request_action_walk_to_cover_shoot_pos(data, my_data, path, "walk")
		end
	end
end

function CopLogicAttack._get_cover_offset_pos(data, cover_data, threat_pos)
	local threat_vec = threat_pos - cover_data[1][1]

	mvector3.set_z(threat_vec, 0)

	local threat_polar = threat_vec:to_polar_with_reference(cover_data[1][2], math.UP)
	local threat_spin = threat_polar.spin
	local rot = nil

	if threat_spin < -20 then
		rot = Rotation(90)
	elseif threat_spin > 20 then
		rot = Rotation(-90)
	else
		rot = Rotation(180)
	end

	local yaw = mvector3.copy(cover_data[1][2])

	mvector3.rotate_with(yaw, rot)
	
	local offset_pos = mvector3.copy(yaw)
	
	mvector3.set_length(offset_pos, 25)
	mvector3.add(offset_pos, cover_data[1][1])

	local ray_params = {
		trace = true,
		tracker_from = cover_data[1][3],
		pos_to = offset_pos
	}

	managers.navigation:raycast(ray_params)
	
	mvector3.normalize(yaw)
	
	return ray_params.trace[1], yaw
end

function CopLogicAttack._verify_cover(cover, threat_pos, min_dis, max_dis)
	local threat_dis = mvector3.direction(temp_vec1, cover[1], threat_pos)

	if min_dis and threat_dis < min_dis or max_dis and max_dis < threat_dis then
		return
	end
	
	local cover_dot = mvector3.dot(temp_vec1, cover[2])

	if cover_dot < 0.7 then
		return
	end

	return true
end

function CopLogicAttack._process_pathing_results(data, my_data)
	if not data.pathing_results then
		return
	end

	local pathing_results = data.pathing_results
	data.pathing_results = nil
	
	local path = pathing_results[my_data.cover_path_search_id]

	if path then
		my_data.processing_cover_path = nil
		my_data.cover_path_search_id = nil
	
		if path ~= "failed" then
			my_data.cover_path = path
			my_data.cover_path_failed_t = nil
		else
			CopLogicAttack._set_best_cover(data, my_data, nil)

			my_data.cover_path_failed_t = TimerManager:game():time()
			
			if my_data.flank_cover then
				my_data.flank_cover.failed = true
			end
		end
	end

	path = pathing_results[my_data.charge_path_search_id]

	if path then
		my_data.charge_path_search_id = nil
		my_data.charge_pos = nil
	
		if path ~= "failed" then
			my_data.charge_path = path
			my_data.charge_path_failed_t = nil
		else
			my_data.charge_path_failed_t = TimerManager:game():time()
		end	
	end
	
	path = pathing_results[my_data.hide_path_search_id]
	
	if path then
		my_data.hide_path_search_id = nil
	
		if path ~= "failed" then
			my_data.flank_path = path
			my_data.flank_path_failed_t = nil
		else
			my_data.flank_path_failed_t = TimerManager:game():time()
		end	
	end

	path = pathing_results[my_data.expected_pos_path_search_id]

	if path then
		if path ~= "failed" then
			my_data.expected_pos_path = path
		end

		my_data.expected_pos_path_search_id = nil
	end
end

function CopLogicAttack._find_charge_pos(data, my_data, enemy_tracker, max_dist)
	local pos = enemy_tracker:position()
	local vec_to_pos = pos - data.m_pos

	mvector3.set_z(vec_to_pos, 0)

	local max_dis = max_dist or 1500

	mvector3.set_length(vec_to_pos, max_dis)

	local accross_positions = managers.navigation:find_walls_accross_tracker(enemy_tracker, vec_to_pos, 360, 9)

	if accross_positions then
		local optimal_dis = max_dis
		local best_error_dis, best_pos, best_is_hit, best_is_miss, best_has_too_much_error = nil

		for _, accross_pos in ipairs(accross_positions) do
			local error_dis = math.abs(mvector3.distance(accross_pos[1], pos) - optimal_dis)
			local too_much_error = error_dis / optimal_dis > 0.2
			
			if not best_error_dis or error_dis < best_error_dis then
				local reservation = {
					radius = 30,
					position = accross_pos[1],
					filter = data.pos_rsrv_id
				}

				if managers.navigation:is_pos_free(reservation) then
					best_pos = accross_pos[1]
					best_error_dis = error_dis
					best_has_too_much_error = too_much_error
				end
			end
		end

		return best_pos
	end
end

function CopLogicAttack._find_flank_pos(data, my_data, flank_tracker, max_dist)
	local pos = flank_tracker:position()
	local vec_to_pos = pos - data.m_pos

	mvector3.set_z(vec_to_pos, 0)

	local max_dis = max_dist or 1500

	mvector3.set_length(vec_to_pos, max_dis)

	local accross_positions = managers.navigation:find_walls_accross_tracker(flank_tracker, vec_to_pos, 160, 9)

	if accross_positions then
		local optimal_dis = max_dis
		local best_error_dis, best_pos, best_is_hit, best_is_miss, best_has_too_much_error = nil

		for _, accross_pos in ipairs(accross_positions) do
			local error_dis = math.abs(mvector3.distance(accross_pos[1], pos) - optimal_dis)
			local too_much_error = error_dis / optimal_dis > 0.2
			
			if not best_error_dis or error_dis < best_error_dis then
				local reservation = {
					radius = 30,
					position = accross_pos[1],
					filter = data.pos_rsrv_id
				}

				if managers.navigation:is_pos_free(reservation) then
					best_pos = accross_pos[1]
					best_error_dis = error_dis
					best_has_too_much_error = too_much_error
				end
			end
		end

		return best_pos
	end
end

function CopLogicAttack._chk_start_action_move_out_of_the_way(data, my_data)
	local my_tracker = data.unit:movement():nav_tracker()
	local reservation = {
		radius = 30,
		position = data.m_pos,
		filter = data.pos_rsrv_id
	}

	if not managers.navigation:is_pos_free(reservation) then
		local to_pos = CopLogicTravel._get_pos_on_wall(data.m_pos, 500, nil, nil, nil, data.pos_rsrv_id)

		if to_pos then
			local path = {
				my_tracker:position(),
				to_pos
			}

			local new_action_data = {
				variant = "walk",
				body_part = 2,
				type = "walk",
				nav_path = path
			}
			my_data.advancing = data.unit:brain():action_request(new_action_data)

			if my_data.advancing then
				my_data.surprised = true

				return true
			end
		end
	end
end

function CopLogicAttack._chk_start_action_move_back(data, my_data, focus_enemy, engage)
	if not my_data.surprised and focus_enemy and focus_enemy.nav_tracker and focus_enemy.verified and CopLogicAttack._can_move(data) then
		local from_pos = mvector3.copy(data.m_pos)
		local threat_tracker = focus_enemy.nav_tracker
		local threat_head_pos = focus_enemy.m_head_pos
		local max_walk_dis = 400
		local vis_required = engage
		local retreat_to, is_fail = CopLogicAttack._find_retreat_position(data, from_pos, focus_enemy.m_pos, threat_head_pos, threat_tracker, max_walk_dis, vis_required)
		
		if retreat_to then
			local to_pos = retreat_to
			local second_retreat_pos, retry_is_fail
			
			if is_fail then
				second_retreat_pos, retry_is_fail = CopLogicAttack._find_retreat_position(data, retreat_to, focus_enemy.m_pos, threat_head_pos, threat_tracker, max_walk_dis, vis_required)
				
				if not retry_is_fail then
					to_pos = second_retreat_pos
				else
					second_retreat_pos = nil
				end
			end
		
			local dis = mvec3_dis_sq(from_pos, to_pos)
			
			if dis > 10000 then
				local retreat_path = {
					retreat_to
				}
				
				if second_retreat_pos then
					retreat_path[#retreat_path + 1] = second_retreat_pos
				end
				
				CopLogicAttack._correct_path_start_pos(data, retreat_path)
			
				CopLogicAttack._cancel_cover_pathing(data, my_data)

				local end_pose = "crouch"

				if data.char_tweak.allowed_poses then
					if not data.char_tweak.allowed_poses.crouch then
						end_pose = "stand"
					elseif not data.char_tweak.allowed_poses.stand then
						end_pose = "crouch"
					end
				end
				
				local speed = "walk"
				
				if not vis_required and not is_fail and dis > 40000 then
					speed = "run"
					
					if dis > 160000 and (not data.char_tweak.allowed_poses or data.char_tweak.allowed_poses.stand) then
						pose = "stand"
					end
				end

				local new_action_data = {
					variant = speed,
					body_part = 2,
					type = "walk",	
					end_pose = end_pose,
					pose = pose,
					nav_path = retreat_path
				}
				my_data.advancing = data.unit:brain():action_request(new_action_data)

				if my_data.advancing then
					my_data.surprised = true

					return true
				end
			end
		end
	end
end

function CopLogicAttack._find_retreat_position(data, from_pos, threat_pos, threat_head_pos, threat_tracker, max_dist, vis_required)
	local nav_manager = managers.navigation
	local nr_rays = 9
	local ray_dis = max_dist or 1000
	local step = 216 / nr_rays
	local offset = math.random(step)
	local dir = math.random() < 0.5 and -1 or 1
	step = step * dir
	local step_rot = Rotation(step)
	local offset_rot = Rotation(offset)
	local offset_vec = mvector3.copy(threat_pos)

	mvector3.subtract(offset_vec, from_pos)
	mvector3.normalize(offset_vec)
	mvector3.multiply(offset_vec, ray_dis)
	mvector3.rotate_with(offset_vec, Rotation((90 + offset) * dir))

	local to_pos = nil
	local is_fail_condition = nil
	local from_tracker = nav_manager:create_nav_tracker(from_pos)
	local ray_params = {
		trace = true,
		tracker_from = from_tracker
	}
	local rsrv_desc = {
		filter = data.pos_rsrv_id,
		radius = 60
	}
	local fail_position = nil
	local confirm_retreat_f = data.logic._confirm_retreat_position and data.logic._confirm_retreat_position or CopLogicAttack._confirm_retreat_position
	local confirm_retreat_visless_f = data.logic._confirm_retreat_position_visless and data.logic._confirm_retreat_position_visless or CopLogicAttack._confirm_retreat_position_visless

	repeat
		to_pos = mvector3.copy(from_pos)

		mvector3.add(to_pos, offset_vec)

		ray_params.pos_to = to_pos
		local ray_res = nav_manager:raycast(ray_params)

		if ray_res then
			local position = ray_params.trace[1]
			
			if vis_required then
				position = confirm_retreat_f(position, threat_pos, threat_head_pos, threat_tracker)
				
				if not position then
					if not fail_position then
						rsrv_desc.position = ray_params.trace[1]
						local is_free = nav_manager:is_pos_free(rsrv_desc)

						if is_free then
							fail_position = ray_params.trace[1]
							is_fail_condition = true
						end
					end
				end
			elseif not confirm_retreat_visless_f(position, threat_pos, threat_head_pos, threat_tracker) then
				if not fail_position then
					rsrv_desc.position = ray_params.trace[1]
					local is_free = nav_manager:is_pos_free(rsrv_desc)

					if is_free then
						fail_position = ray_params.trace[1]
						is_fail_condition = true
					end
				elseif mvec3_dis_sq(ray_params.trace[1], threat_pos) > mvec3_dis_sq(fail_position, threat_pos) then
					rsrv_desc.position = ray_params.trace[1]
					local is_free = nav_manager:is_pos_free(rsrv_desc)

					if is_free then
						fail_position = ray_params.trace[1]
						is_fail_condition = true
					end
				end
				
				position = nil
			end
			
			if position then
				rsrv_desc.position = position
				local is_free = nav_manager:is_pos_free(rsrv_desc)

				if is_free then
					managers.navigation:destroy_nav_tracker(from_tracker)

					return position
				end
			end
		else
			local position = ray_params.trace[1]

			if vis_required then
				position = confirm_retreat_f(position, threat_pos, threat_head_pos, threat_tracker)
			elseif not confirm_retreat_visless_f(position, threat_pos, threat_head_pos, threat_tracker) then
				position = nil
			end
			
			if position and (not fail_position or is_fail_condition or mvec3_dis_sq(position, threat_pos) > mvec3_dis_sq(fail_position, threat_pos)) then
				rsrv_desc.position = position
				local is_free = nav_manager:is_pos_free(rsrv_desc)

				if is_free then
					fail_position = position
					is_fail_condition = nil
				end
			end
		end

		mvector3.rotate_with(offset_vec, step_rot)

		nr_rays = nr_rays - 1
	until nr_rays == 0

	managers.navigation:destroy_nav_tracker(from_tracker)

	if fail_position then
		return fail_position, is_fail_condition
	end

	return nil
end

function CopLogicAttack._confirm_retreat_position_visless(retreat_pos, threat_pos, threat_head_pos, threat_tracker)
	local retreat_head_pos = mvector3.copy(retreat_pos)

	mvector3.add(retreat_head_pos, Vector3(0, 0, 90))

	local slotmask = managers.slot:get_mask("AI_visibility") + managers.slot:get_mask("enemy_shield_check")
	local ray_res = World:raycast("ray", retreat_head_pos, threat_head_pos, "slot_mask", slotmask, "ray_type", "ai_vision", "report")

	if ray_res then
		return true
	end

	return false
end

function CopLogicAttack._upd_pose(data, my_data)
	local unit_can_stand = not data.char_tweak.allowed_poses or data.char_tweak.allowed_poses.stand
	local unit_can_crouch = not data.char_tweak.allowed_poses or data.char_tweak.allowed_poses.crouch
	local stand_objective = data.objective and data.objective.pose == "stand"
	local crouch_objective = data.objective and data.objective.pose == "crouch"
	local need_cover = my_data.want_to_take_cover and (not my_data.in_cover or not my_data.in_cover[4])
	
	if not unit_can_stand or need_cover and my_data.cover_test_step and my_data.cover_test_step < 3 then
		if not data.unit:anim_data().crouch and unit_can_crouch then
			return CopLogicAttack._chk_request_action_crouch(data)
		end
	else
		if not data.unit:anim_data().stand and unit_can_stand then
			return CopLogicAttack._chk_request_action_stand(data)
		end
	end
end

function CopLogicAttack.action_complete_clbk(data, action)
	local my_data = data.internal_data
	local action_type = action:type()

	if action_type == "walk" then
		my_data.advancing = nil
		my_data.old_action_advancing = nil
		my_data.in_cover = nil
		
		CopLogicAttack._cancel_cover_pathing(data, my_data)
		CopLogicAttack._cancel_charge(data, my_data)
		
		if my_data.surprised then
			my_data.surprised = false
		elseif my_data.moving_to_cover then
			if action:expired() then
				my_data.in_cover = my_data.moving_to_cover
				my_data.in_cover[7] = nil
				my_data.cover_enter_t = data.t
				my_data.cover_test_step = 0
				my_data.flank_cover = nil
			end

			my_data.moving_to_cover = nil
		elseif my_data.walking_to_cover_shoot_pos then
			my_data.walking_to_cover_shoot_pos = nil
			my_data.charging = nil
			
			if action:expired() then
				my_data.at_cover_shoot_pos = true
			end
		end
		
		if action:expired() then
			if data.attention_obj and AIAttentionObject.REACT_COMBAT <= data.attention_obj.reaction then
				data.logic._update_cover(data)
				data.logic._upd_combat_movement(data)
				data.logic._upd_aim(data, my_data)
			end
		end
	elseif action_type == "act" then
		if not my_data.advancing and action:expired() then
			if data.attention_obj and AIAttentionObject.REACT_COMBAT <= data.attention_obj.reaction then
				data.logic._update_cover(data)
				data.logic._upd_combat_movement(data)
				data.logic._upd_aim(data, my_data)
			end
		end
	elseif action_type == "shoot" then
		my_data.shooting = nil
	elseif action_type == "turn" then
		my_data.turning = nil
		
		if action:expired() then
			CopLogicAttack._upd_aim(data, my_data) --check if i need to turn again
		end
	elseif action_type == "heal" then
		CopLogicAttack._cancel_cover_pathing(data, my_data)
		
		if action:expired() then
			data.logic._upd_aim(data, my_data)
		end
	elseif action_type == "hurt" or action_type == "healed" then
		CopLogicAttack._cancel_cover_pathing(data, my_data)

		if action:expired() then
			if data.is_converted or not CopLogicBase.chk_start_action_dodge(data, "hit") then
				data.logic._upd_aim(data, my_data)
			end
		end
	elseif action_type == "dodge" then
		local timeout = action:timeout()

		if timeout then
			data.dodge_timeout_t = TimerManager:game():time() + math.lerp(timeout[1], timeout[2], math.random())
		end

		CopLogicAttack._cancel_cover_pathing(data, my_data)

		if action:expired() then
			CopLogicAttack._upd_aim(data, my_data)
		end
	end
end

function CopLogicAttack._correct_path_start_pos(data, path)
	local first_nav_point = path[1]
	local my_pos = data.m_pos

	if first_nav_point.x ~= my_pos.x or first_nav_point.y ~= my_pos.y then
		if path[2] then
			if LIES:_path_is_straight_line(my_pos, path[2], data) then
				path[1] = mvector3.copy(my_pos)
			else
				table.insert(path, 1, mvector3.copy(my_pos))
			end
		else
			table.insert(path, 1, mvector3.copy(my_pos))
		end
	end
end

function CopLogicAttack._chk_request_action_walk_to_cover_offset_pos(data, my_data, path)
	CopLogicAttack._correct_path_start_pos(data, path)

	local haste = nil
	local pose = nil
	local i = 1
	local travel_dis = 0
	
	repeat
		if path[i + 1] then
			travel_dis = travel_dis + mvector3.distance_sq(path[i], path[i + 1])
			i = i + 1
		else
			break
		end
	until travel_dis > 160000 or i >= #path
	
	if not data.char_tweak.walk_only then
		if travel_dis > 40000 then
			haste = "run"
		end
	end
		
	if travel_dis > 160000 then
		pose = "stand"
	else
		pose = data.unit:anim_data().crouch and "crouch"
	end

	haste = haste or "walk"
	pose = pose or "stand"

	if pose == "crouch" and data.char_tweak.crouch_move ~= true then
		pose = "stand"
	end
	
	local end_pose = my_data.in_cover[4] and "stand" or "crouch"

	if data.char_tweak.allowed_poses then
		if not data.char_tweak.allowed_poses.crouch then
			pose = "stand"
			end_pose = "stand"
		elseif not data.char_tweak.allowed_poses.stand then
			pose = "crouch"
			end_pose = "crouch"
		end
	end

	local new_action_data = {
		type = "walk",
		body_part = 2,
		nav_path = path,
		variant = haste,
		pose = pose,
		end_pose = end_pose
	}
	my_data.advancing = data.unit:brain():action_request(new_action_data)

	if my_data.advancing then
		my_data.moving_to_cover = my_data.in_cover
		my_data.at_cover_shoot_pos = nil
		my_data.in_cover = nil
		
		CopLogicAttack._upd_aim(data, my_data)

		data.brain:rem_pos_rsrv("path")
	end
end

function CopLogicAttack._chk_request_action_walk_to_cover(data, my_data)
	CopLogicAttack._correct_path_start_pos(data, my_data.cover_path)

	local haste = nil
	local pose = nil
	local i = 1
	local travel_dis = 0
	
	repeat
		if my_data.cover_path[i + 1] then
			travel_dis = travel_dis + mvector3.distance_sq(my_data.cover_path[i], my_data.cover_path[i + 1])
			i = i + 1
		else
			break
		end
	until travel_dis > 160000 or i >= #my_data.cover_path
	
	if not data.char_tweak.walk_only then
		if travel_dis > 40000 then
			haste = "run"
		end
	end
	
	if travel_dis > 160000 then
		pose = "stand"
	else
		pose = data.unit:anim_data().crouch and "crouch"
	end

	haste = haste or "walk"
	pose = pose or "stand"

	if pose == "crouch" and data.char_tweak.crouch_move ~= true then
		pose = "stand"
	end
	
	local end_pose = my_data.best_cover[4] and "stand" or "crouch"

	if data.char_tweak.allowed_poses then
		if not data.char_tweak.allowed_poses.crouch then
			pose = "stand"
			end_pose = "stand"
		elseif not data.char_tweak.allowed_poses.stand then
			pose = "crouch"
			end_pose = "crouch"
		end
	end

	local new_action_data = {
		type = "walk",
		body_part = 2,
		nav_path = my_data.cover_path,
		variant = haste,
		pose = pose,
		end_pose = end_pose
	}
	
	my_data.cover_path = nil
	my_data.advancing = data.unit:brain():action_request(new_action_data)

	if my_data.advancing then
		my_data.moving_to_cover = my_data.best_cover
		my_data.at_cover_shoot_pos = nil
		my_data.in_cover = nil

		CopLogicAttack._upd_aim(data, my_data)

		data.brain:rem_pos_rsrv("path")
	end
end

function CopLogicAttack.is_available_for_assignment(data, new_objective)
	local my_data = data.internal_data

	if my_data.exiting then
		return
	end
	
	if new_objective and new_objective.attitude then
		my_data.attitude = new_objective.attitude
	end

	if new_objective and new_objective.forced then
		return true
	end
	
	if new_objective and new_objective.is_default then
		return true
	end

	if data.unit:movement():chk_action_forbidden("walk") then
		return
	end

	if data.path_fail_t and data.t - data.path_fail_t > 3 then
		return
	end
	
	if CopLogicBase.check_sabotage_objective_not_allowed(data, new_objective) then
		return
	end

	local att_obj = data.attention_obj

	if not att_obj or att_obj.reaction < AIAttentionObject.REACT_AIM then
		return true
	end

	if not new_objective or new_objective.type == "free" then
		return true
	end

	if new_objective then
		local allow_trans, obj_fail = CopLogicBase.is_obstructed(data, new_objective, 0.2)

		if obj_fail then
			return
		end
	end

	return true
end

function CopLogicAttack._chk_covered(data, cover_pos, threat_pos, slotmask)
	local ray_from = temp_vec1

	mvec3_set(ray_from, math.UP)
	mvec3_mul(ray_from, 90)
	mvec3_add(ray_from, cover_pos)

	local ray_to_pos = threat_pos

	local low_ray = data.unit:raycast("ray", ray_from, ray_to_pos, "slot_mask", slotmask, "ray_type", "ai_vision", "report")
	local high_ray = nil

	if low_ray then		
		mvec3_set_z(ray_from, ray_from.z + 90)

		high_ray = data.unit:raycast("ray", ray_from, ray_to_pos, "slot_mask", slotmask, "ray_type", "ai_vision", "report")
	end

	return low_ray, high_ray
end

function CopLogicAttack._can_move(data)
	return not data.objective or not data.objective.pos
end

function CopLogicAttack._upd_stop_old_action(data, my_data)
	if data.unit:anim_data().to_idle or data.unit:anim_data().hurt then
		return
	end
	
	if my_data.advancing and my_data.old_action_advancing then
		if not data.unit:movement():chk_action_forbidden("walk") then
			data.unit:brain():action_request({
				body_part = 2,
				type = "idle"
			})
		end
	end
	
	if data.unit:movement():chk_action_forbidden("walk") then
		if not data.unit:movement():chk_action_forbidden("idle") then
			CopLogicIdle._start_idle_action_from_act(data)
		end
	elseif data.unit:anim_data().act and data.unit:anim_data().needs_idle then
		CopLogicIdle._start_idle_action_from_act(data)
	end

	CopLogicIdle._chk_has_old_action(data, my_data)
end

function CopLogicAttack._find_friend_pos(data, my_data)
	local look_for_shields = true
	
	local best_pos, best_dis, has_shield, has_medic, has_tank, chosen_u_data, best_rank
	local m_tracker = data.unit:movement():nav_tracker()
	local m_field_pos = m_tracker:field_position()
	local dis_sq = mvec3_dis_sq
	local m_key = data.key
	local focus_enemy = data.attention_obj
	
	if data.group then
		for u_key, u_data in pairs(data.group.units) do
			if u_key ~= m_key then
				local is_shield = look_for_shields and u_data.unit:base():has_tag("shield")
				local is_medic = u_data.unit:base():has_tag("medic")
				local is_tank = u_data.unit:base():has_tag("tank")

				if is_medic and is_tank or is_shield or is_medic or not has_medic and is_tank then
					local buddy_logic_data = u_data.unit:brain()._logic_data
					
					if buddy_logic_data and buddy_logic_data.name ~= "inactive" then
						local advance_pos = u_data.unit:brain() and u_data.unit:brain():is_advancing()
						local follow_unit_pos = advance_pos or u_data.unit:movement():nav_tracker():field_position()
						
						if follow_unit_pos then
							local m_dis = dis_sq(m_field_pos, follow_unit_pos)
							
							if not best_dis or best_dis < m_dis then
								best_dis = m_dis
								best_pos = follow_unit_pos
								has_shield = is_shield
								has_medic = is_medic
								has_tank = is_tank
								best_rank = u_data.rank
								chosen_u_data = u_data
								look_for_shields = not is_medic
							end
						end
					end
				end
			end
		end
	end
	
	if not best_pos and data.important then
		for u_key, u_data in pairs(managers.enemy:all_enemies()) do
			if u_key ~= m_key and alive(u_data.unit) and not u_data.unit:movement():team().foes[data.team.id] then
				local is_shield = look_for_shields and u_data.unit:base():has_tag("shield")
				local is_medic = u_data.unit:base():has_tag("medic")
				local is_tank = u_data.unit:base():has_tag("tank")

				if is_medic and is_tank or is_shield or is_medic or not has_medic and is_tank then
					local buddy_logic_data = u_data.unit:brain()._logic_data
					
					if buddy_logic_data and buddy_logic_data.name ~= "inactive" then
						local advance_pos = u_data.unit:brain() and u_data.unit:brain():is_advancing()
						local follow_unit_pos = advance_pos or u_data.unit:movement():nav_tracker():field_position()
						
						if follow_unit_pos then
							local m_dis = dis_sq(m_field_pos, follow_unit_pos)
							
							if m_dis < 1000000 then
								if not best_dis or best_dis < m_dis then
									best_dis = m_dis
									best_pos = follow_unit_pos
									has_shield = is_shield
									has_medic = is_medic
									has_tank = is_tank
									best_rank = u_data.rank
									chosen_u_data = u_data
									look_for_shields = not is_medic
								end
							end
						end
					end
				end
			end
		end
	end
	
	if best_pos then
		if look_for_path then
			my_data.hide_path_search_id = "hide" .. tostring(data.key)

			if data.unit:brain():search_for_path(my_data.hide_path_search_id, best_pos, nil, nil, nil) then
				return true
			end
		else
			if not has_medic and not has_tank then
				if alive(chosen_u_data.unit) and chosen_u_data.unit:brain() then
					if chosen_u_data.unit:brain().request_stillness then
						 chosen_u_data.unit:brain():request_stillness(7.5)
					end
				end
			end
		
			return best_pos
		end
	end
end

function CopLogicAttack._update_cover(data)
	local my_data = data.internal_data
	local cover_release_dis_sq = 10000
	local best_cover = my_data.best_cover
	local satisfied = true
	local my_pos = data.m_pos

	if data.attention_obj and data.attention_obj.nav_tracker and AIAttentionObject.REACT_COMBAT <= data.attention_obj.reaction then
		local find_new = not my_data.moving_to_cover and not my_data.walking_to_cover_shoot_pos and not my_data.surprised and not my_data.advancing and not my_data.processing_cover_path and not my_data.charge_path_search_id

		if find_new then
			local enemy_tracker = data.attention_obj.nav_tracker
			local threat_pos = enemy_tracker:field_position()
			local want_to_take_cover = my_data.want_to_take_cover
			local friend_pos
			
			if want_to_take_cover or data.tactics and data.tactics.sniper then
				friend_pos = CopLogicAttack._find_friend_pos(data, my_data)
			end
			
			if friend_pos then
				my_data.flank_cover = nil
				
				if not best_cover or mvec3_dis_sq(best_cover[1][1], friend_pos) > 40000 or not CopLogicAttack._verify_cover(best_cover[1], threat_pos) then
					local nav_seg_id = managers.navigation:get_nav_seg_from_pos(friend_pos, true)
					local found_cover
					
					if LIES.settings.lua_cover > 1 then
						local optimal_threat_dis = mvec3_dis(friend_pos, threat_pos) + 30
						
						found_cover = managers.navigation:find_cover_from_threat(nav_seg_id, optimal_threat_dis, friend_pos, threat_pos)
					else
						found_cover = managers.navigation:find_cover_away_from_pos(friend_pos, threat_pos, nav_seg_id)
					end

					if found_cover and (not best_cover or best_cover[1] ~= found_cover) then
						--log("IT'S HAPPY HOUR!!!")
						satisfied = true
						local better_cover = {
							found_cover
						}
						
						if not best_cover or best_cover[1] ~= found_cover then
							CopLogicAttack._set_best_cover(data, my_data, better_cover)
						end

						local offset_pos, yaw = CopLogicAttack._get_cover_offset_pos(data, better_cover, threat_pos)

						if offset_pos then
							better_cover[5] = offset_pos
							better_cover[6] = yaw
						end
					end
				end
			elseif data.objective and data.objective.follow_unit and alive(data.objective.follow_unit) then
				my_data.flank_cover = nil
				
				local advance_pos = data.objective.follow_unit:brain() and data.objective.follow_unit:brain():is_advancing() --this is fucking crashing
				local near_pos = advance_pos or data.objective.follow_unit:movement():m_pos()
				local dis = data.objective.distance and data.objective.distance * 0.6 or 450
				
				if not best_cover or mvec3_dis_sq(near_pos, best_cover[1][1]) > dis * dis or not CopLogicAttack._verify_cover(best_cover[1], threat_pos) then
					local follow_unit_seg = data.objective.follow_unit:movement():nav_tracker():nav_segment()
					local found_cover = managers.navigation:find_cover_in_nav_seg_3(follow_unit_seg, dis, near_pos, threat_pos)

					if found_cover and (not best_cover or best_cover[1] ~= found_cover) then
						satisfied = true
						local better_cover = {
							found_cover
						}

						if not best_cover or best_cover[1] ~= found_cover then
							CopLogicAttack._set_best_cover(data, my_data, better_cover)
							
							my_data.flank_cover = nil
						elseif my_data.flank_cover then
							my_data.flank_cover.failed = true
						end

						local offset_pos, yaw = CopLogicAttack._get_cover_offset_pos(data, better_cover, threat_pos)

						if offset_pos then
							better_cover[5] = offset_pos
							better_cover[6] = yaw
						end
					end
				end
			else
				local want_to_take_cover = my_data.want_to_take_cover
				local flank_cover = my_data.flank_cover
				local min_dis, max_dis = nil

				if want_to_take_cover then
					min_dis = my_data.weapon_range.close
				else
					max_dis = my_data.weapon_range.optimal
					min_dis = 400
				end

				if not best_cover or flank_cover or not CopLogicAttack._verify_cover(best_cover[1], threat_pos, min_dis, max_dis) then
					satisfied = false
					local my_vec = my_pos - threat_pos

					if flank_cover then
						mvector3.rotate_with(my_vec, Rotation(flank_cover.angle))
					end

					local optimal_dis = my_vec:length()

					if want_to_take_cover then
						if optimal_dis < my_data.weapon_range.optimal then
							optimal_dis = optimal_dis + 500

							mvector3.set_length(my_vec, optimal_dis)
						end
					elseif my_data.wanted_attack_range and optimal_dis > my_data.wanted_attack_range then
						optimal_dis = my_data.wanted_attack_range
						
						mvector3.set_length(my_vec, optimal_dis)
					elseif optimal_dis > my_data.weapon_range.close then
						optimal_dis = my_data.weapon_range.close

						mvector3.set_length(my_vec, optimal_dis)
					end
					
					local max_dis = optimal_dis + 800

					local my_side_pos = threat_pos + my_vec

					mvector3.set_length(my_vec, max_dis)

					local furthest_side_pos = threat_pos + my_vec

					if flank_cover then
						local angle = flank_cover.angle
						local sign = flank_cover.sign

						if math.sign(angle) ~= sign then
							angle = -angle + flank_cover.step * sign

							if math.abs(angle) > 90 then
								flank_cover.failed = true
							else
								flank_cover.angle = angle
							end
						else
							flank_cover.angle = -angle
						end
					end

					local min_threat_dis = 750
					local cone_angle = nil

					if flank_cover then
						cone_angle = flank_cover.step
					else
						cone_angle = math.lerp(90, 30, math.min(1, optimal_dis / 3000))
					end

					local search_nav_seg = nil

					if data.objective and data.objective.type == "defend_area" then
						search_nav_seg = data.objective.nav_seg
					end
					
					local found_cover = managers.navigation:find_cover_in_cone_from_threat_pos_1(threat_pos, furthest_side_pos, my_side_pos, nil, cone_angle, min_threat_dis, search_nav_seg, nil, data.pos_rsrv_id)

					if found_cover and (not best_cover or best_cover[1] ~= found_cover) then
						satisfied = true
						local better_cover = {
							found_cover
						}

						CopLogicAttack._set_best_cover(data, my_data, better_cover)

						local offset_pos, yaw = CopLogicAttack._get_cover_offset_pos(data, better_cover, threat_pos)

						if offset_pos then
							my_data.best_cover[5] = offset_pos
							my_data.best_cover[6] = yaw
						end
					elseif my_data.flank_cover then
						my_data.flank_cover.failed = true
					end
				end
			end
		end
		
		if my_data.best_cover and cover_release_dis_sq >= mvector3.distance_sq(my_data.best_cover[1][1], my_pos) and (not my_data.in_cover or my_data.in_cover[1] ~= my_data.best_cover[1]) then
			my_data.in_cover = my_data.best_cover
			
			my_data.cover_enter_t = data.t
		end

		local in_cover = my_data.in_cover

		if in_cover then
			if cover_release_dis_sq >= mvector3.distance_sq(in_cover[1][1], my_pos) then
				local threat_pos = data.attention_obj.verified_pos
				local offset_pos, yaw = CopLogicAttack._get_cover_offset_pos(data, in_cover, threat_pos)
				
				if offset_pos then
					if in_cover[6] then
						local cover_dot = mvector3.dot(yaw, in_cover[6])

						if cover_dot < 0.9 then
							my_data.in_cover[7] = true
						end
					else
						my_data.in_cover[7] = true
					end
					
					my_data.in_cover[5] = offset_pos
					my_data.in_cover[6] = yaw
				end
				
				local peek_pos = offset_pos or in_cover[1][1]
				
				local slotmask = data.visibility_slotmask + managers.slot:get_mask("enemy_shield_check")
				
				in_cover[3], in_cover[4] = CopLogicAttack._chk_covered(data, peek_pos, threat_pos, data.visibility_slotmask)
			else
				my_data.in_cover = nil
			end
		end
	elseif best_cover and cover_release_dis_sq < mvector3.distance_sq(best_cover[1][1], my_pos) then
		CopLogicAttack._set_best_cover(data, my_data, nil)
	end
end
