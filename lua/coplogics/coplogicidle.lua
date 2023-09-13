local AI_REACT_IDLE = AIAttentionObject.REACT_IDLE
local AI_REACT_SCARED = AIAttentionObject.REACT_SCARED
local AI_REACT_AIM = AIAttentionObject.REACT_AIM
local AI_REACT_SHOOT = AIAttentionObject.REACT_SHOOT
local AI_REACT_COMBAT = AIAttentionObject.REACT_COMBAT
local AI_REACT_SPECIAL_ATTACK = AIAttentionObject.REACT_SPECIAL_ATTACK
local temp_vec1 = Vector3()
local temp_vec2 = Vector3()
local temp_vec3 = Vector3()
local mvec3_dir = mvector3.direction
local mvec3_set_z = mvector3.set_z
local mvec3_dot = mvector3.dot
local mvec3_dis_sq = mvector3.distance_sq

function CopLogicIdle.enter(data, new_logic_name, enter_params)
	CopLogicBase.enter(data, new_logic_name, enter_params)

	local my_data = {
		unit = data.unit
	}
	local is_cool = data.unit:movement():cool()

	if is_cool then
		my_data.detection = data.char_tweak.detection.ntl
	else
		my_data.detection = data.char_tweak.detection.idle
	end

	local old_internal_data = data.internal_data

	if old_internal_data then
		my_data.current_undetected_criminal_key = old_internal_data.current_undetected_criminal_key
		my_data.detected_criminal = old_internal_data.detected_criminal
		
		if my_data.detected_criminal then --we're coming in from another logic, we should reset in case of chase
			my_data.needs_logic_reset = true
		end
		
		
		my_data.turning = old_internal_data.turning

		if old_internal_data.firing then
			data.unit:movement():set_allow_fire(false)
		end

		if old_internal_data.shooting then
			data.unit:brain():action_request({
				body_part = 3,
				type = "idle"
			})
		end

		local lower_body_action = data.unit:movement()._active_actions[2]
		my_data.advancing = lower_body_action and lower_body_action:type() == "walk" and lower_body_action

		if old_internal_data.best_cover then
			my_data.best_cover = old_internal_data.best_cover

			managers.navigation:reserve_cover(my_data.best_cover[1], data.pos_rsrv_id)
		end

		if old_internal_data.nearest_cover then
			my_data.nearest_cover = old_internal_data.nearest_cover

			managers.navigation:reserve_cover(my_data.nearest_cover[1], data.pos_rsrv_id)
		end
	end

	data.internal_data = my_data
	local key_str = tostring(data.unit:key())
	my_data.detection_task_key = "CopLogicIdle.update" .. key_str

	CopLogicBase.queue_task(my_data, my_data.detection_task_key, CopLogicIdle.queued_update, data, data.t)

	local objective = data.objective
	
	if objective then
		my_data.scan = objective.scan
		my_data.rubberband_rotation = objective.rubberband_rotation and data.unit:movement():m_rot():y()
	else
		my_data.scan = true
	end

	if my_data.scan then
		my_data.stare_path_search_id = "stare" .. key_str
		my_data.wall_stare_task_key = "CopLogicIdle._chk_stare_into_wall" .. key_str
	end

	CopLogicIdle._chk_has_old_action(data, my_data)

	if my_data.scan and (not objective or not objective.action) then
		CopLogicBase.queue_task(my_data, my_data.wall_stare_task_key, CopLogicIdle._chk_stare_into_wall_1, data, data.t)
	end

	if is_cool then
		data.unit:brain():set_attention_settings({
			peaceful = true
		})
	else
		data.unit:brain():set_attention_settings({
			cbt = true
		})
	end
	
	--enemies can come out of coplogicintimidated without a fucking gun for some goddamn reason
	local usage = data.unit:inventory():equipped_unit() and alive(data.unit:inventory():equipped_unit()) and data.unit:inventory():equipped_unit():base():weapon_tweak_data().usage
	my_data.weapon_range = usage and (data.char_tweak.weapon[usage] or {}).range
	
	if not my_data.weapon_range then
		my_data.weapon_range = {
			optimal = 2000,
			far = 5000,
			close = 1000
		}
	end

	data.unit:brain():set_update_enabled_state(false)
	
	if not my_data.detected_criminal then
		CopLogicIdle._perform_objective_action(data, my_data, objective)
	end
	
	data.unit:movement():set_allow_fire(false)

	if my_data ~= data.internal_data then
		return
	end
end

function CopLogicIdle._chk_has_old_action(data, my_data)
	local anim_data = data.unit:anim_data()
	my_data.has_old_action = anim_data.act or anim_data.act_idle
	local lower_body_action = data.unit:movement()._active_actions[2]
	my_data.advancing = lower_body_action and lower_body_action:type() == "walk" and lower_body_action
	
	if my_data.advancing then
		my_data.old_action_advancing = my_data.advancing
	end
end

function CopLogicIdle._on_player_slow_pos_rsrv_upd(data)
	local my_data = data.internal_data

	if data.is_converted or data.check_crim_jobless or data.unit:in_slot(16) then
		if not data.objective or data.objective.type == "free" then
			if not data.path_fail_t or data.t - data.path_fail_t > 3 then
				managers.groupai:state():on_criminal_jobless(data.unit)

				if my_data ~= data.internal_data then
					CopLogicBase.cancel_queued_tasks(my_data)
				
					return
				end
			end
		end
	end
	
	if CopLogicIdle._chk_relocate(data) then
		if my_data ~= data.internal_data then
			CopLogicBase.cancel_queued_tasks(my_data)
		end
		
		return
	end
end

function CopLogicIdle.queued_update(data)
	local my_data = data.internal_data
	local delay = data.logic._upd_enemy_detection(data)

	if data.internal_data ~= my_data then
		CopLogicBase._report_detections(data.detected_attention_objects)

		return
	end

	local objective = data.objective

	if my_data.has_old_action or my_data.old_action_advancing then
		CopLogicIdle._upd_stop_old_action(data, my_data, objective)
		
		if my_data.has_old_action or my_data.old_action_advancing then
			CopLogicBase.queue_task(my_data, my_data.detection_task_key, CopLogicIdle.queued_update, data, data.t + delay, data.important and true)

			return
		end
	end

	if data.is_converted or data.check_crim_jobless or data.unit:in_slot(16) then
		if not data.objective or data.objective.type == "free" then
			if not data.path_fail_t or data.t - data.path_fail_t > 3 then
				managers.groupai:state():on_criminal_jobless(data.unit)

				if my_data ~= data.internal_data then
					return
				end
			end
		end
	end

	if CopLogicIdle._chk_exit_non_walkable_area(data) then
		return
	end
	
	if CopLogicIdle._chk_relocate(data) then
		return
	end
	
	CopLogicTravel._update_cover(nil, data)
	
	if data.cool then
		if not my_data.detected_criminal and my_data.needs_logic_reset then
			if my_data.action_expired then
				data.objective_complete_clbk(data.unit, data.objective)
				
				CopLogicBase._report_detections(data.detected_attention_objects)
				
				return
			else
				if data.objective then
					data.objective.in_place = nil
				end
				
				CopLogicIdle.on_new_objective(data)
				
				if data.internal_data ~= my_data then
					CopLogicBase._report_detections(data.detected_attention_objects)

					return
				end
			end
		elseif not my_data.detected_criminal then
			CopLogicIdle._perform_objective_action(data, my_data, objective)
		end
	else
		CopLogicIdle._perform_objective_action(data, my_data, objective)
	end
		
	CopLogicIdle._upd_stance_and_pose(data, my_data, objective)
	CopLogicIdle._upd_pathing(data, my_data)
	
	CopLogicIdle._upd_scan(data, my_data)
		
	if my_data.action_started and my_data.action_started == true then
		if not data.cool then
			CopLogicIdle._check_needs_reload(data, my_data)
		end
		
		CopLogicIdle._chk_start_action_move_out_of_the_way(data, my_data)
	end

	if data.cool then
		CopLogicIdle.upd_suspicion_decay(data)
	end

	if data.internal_data ~= my_data then
		CopLogicBase._report_detections(data.detected_attention_objects)

		return
	end
	
	if LIES.settings.extra_chatter and data.cool and not my_data.advancing and data.char_tweak.chatter and data.char_tweak.chatter.criminalhasgun then
		if not data.last_calm_chatter_t or data.t - data.last_calm_chatter_t > (data.important and 45 or 120) then
			if my_data.action_started ~= true then
				if data.unit:sound():say("a06", true) then
					data.last_calm_chatter_t = data.t - math.lerp(0, 30, math.random())
				end
			elseif (not data.last_calm_chatter_t or data.t - data.last_calm_chatter_t > 60) and data.unit:sound():say("a05", true) then
				data.last_calm_chatter_t = data.t - math.lerp(0, 30, math.random())
			end
		end
	end

	CopLogicBase.queue_task(my_data, my_data.detection_task_key, CopLogicIdle.queued_update, data, data.t + delay, data.important and true)
end

function CopLogicIdle._upd_pathing(data, my_data)
	if not data.pathing_results then
		return
	end

	local path = my_data.chase_crim_path_id and data.pathing_results[my_data.chase_crim_path_id]
	
	if path then
		data.pathing_results[my_data.chase_crim_path_id] = nil
		my_data.chase_crim_path_id = nil

		if path ~= "failed" then
			my_data.chase_crim_path = path
			
			if data.cool and my_data.current_undetected_criminal_key and data.detected_attention_objects[my_data.current_undetected_criminal_key] then
				local attention_info = data.detected_attention_objects[my_data.current_undetected_criminal_key]
				
				return CopLogicIdle._upd_focus_on_undetected_criminal(data, my_data, attention_info)
			end
		else
			my_data.chase_crim_path_failed_t = data.t
			my_data.chase_pos = nil
			
			--log("waaaa")	
		end
		
	
	end
end

function CopLogicIdle.clbk_action_timeout(ignore_this, data)
	local my_data = data.internal_data

	CopLogicBase.on_delayed_clbk(my_data, my_data.action_timeout_clbk_id)

	my_data.action_timeout_clbk_id = nil

	if not data.objective then
		debug_pause_unit(data.unit, "[CopLogicIdle.clbk_action_timeout] missing objective")

		return
	end

	my_data.action_expired = true

	if data.unit:anim_data().act and data.unit:anim_data().needs_idle then
		CopLogicIdle._start_idle_action_from_act(data)
	end
	
	if not my_data.detected_criminal then
		data.objective_complete_clbk(data.unit, data.objective)
	end
end

function CopLogicIdle._chk_turn_needed(data, my_data, my_pos, look_pos)
	local fwd = data.unit:movement():m_rot():y()
	local target_vec = temp_vec1
	mvec3_dir(target_vec, my_pos, look_pos)
	mvec3_set_z(target_vec, 0)
	local error_spin = target_vec:to_polar_with_reference(fwd, math.UP).spin
	
	if math.abs(error_spin) > 27 then
		--log("jungus")
		return error_spin
	end
end

function CopLogicIdle._chk_focus_on_attention_object(data, my_data)
	local current_attention = data.attention_obj

	if not current_attention then
		local set_attention = data.unit:movement():attention()

		if set_attention and set_attention.handler then
			CopLogicBase._reset_attention(data)
		end

		return
	end

	if my_data.turning then
		return
	end

	if (current_attention.reaction == AIAttentionObject.REACT_CURIOUS or current_attention.reaction == AIAttentionObject.REACT_SUSPICIOUS) and CopLogicIdle._upd_curious_reaction(data) then
		return true
	end

	if data.logic.is_available_for_assignment(data) and not data.unit:movement():chk_action_forbidden("walk") then
		local attention_pos = current_attention.handler:get_attention_m_pos(current_attention.settings)
		local turn_angle = CopLogicIdle._chk_turn_needed(data, my_data, data.m_pos, attention_pos)

		if turn_angle and current_attention.reaction < AIAttentionObject.REACT_CURIOUS then
			if math.abs(turn_angle) > 70 then
				return
			end
		end

		if turn_angle then
			local err_to_correct_abs = math.abs(turn_angle)
			local angle_str = nil

			if err_to_correct_abs > 27 then
				if not CopLogicIdle._turn_by_spin(data, my_data, turn_angle) then
					return
				end

				if my_data.rubberband_rotation then
					my_data.fwd_offset = true
				end
			end
		end
	end

	local set_attention = data.unit:movement():attention()

	if not set_attention or set_attention.u_key ~= current_attention.u_key then
		CopLogicBase._set_attention(data, current_attention, nil)
	end

	return true
end

function CopLogicIdle._upd_curious_reaction(data)
	local my_data = data.internal_data
	local unit = data.unit
	local my_pos = data.unit:movement():m_head_pos()
	--local turn_spin = 27
	local attention_obj = data.attention_obj
	local dis = attention_obj.dis
	local is_suspicious = data.cool and attention_obj.reaction == AIAttentionObject.REACT_SUSPICIOUS
	local set_attention = data.unit:movement():attention()

	if not set_attention or set_attention.u_key ~= attention_obj.u_key then
		CopLogicBase._set_attention(data, attention_obj)
	end

	local turned_around = nil

	if (not attention_obj.settings.turn_around_range or dis < attention_obj.settings.turn_around_range) and (not data.objective or not data.objective.rot) then
	
		if data.logic.is_available_for_assignment(data) and not data.unit:movement():chk_action_forbidden("walk") then
			local turn_angle = CopLogicIdle._chk_turn_needed(data, my_data, data.m_pos, attention_obj.m_pos)

			if turn_angle then
				CopLogicIdle._turn_by_spin(data, my_data, turn_angle)

				if my_data.rubberband_rotation then
					my_data.fwd_offset = true
				end

				turned_around = true
			end
		end
	end

	if is_suspicious then
		return CopLogicBase._upd_suspicion(data, my_data, attention_obj)
	end
end

function CopLogicIdle._upd_scan(data, my_data)
	if CopLogicIdle._chk_focus_on_attention_object(data, my_data) then
		return
	end
	
	if LIES.settings.hhtacs and CopLogicIdle._chk_focus_on_undetected_criminal(data, my_data) then
		return
	end

	if not data.logic.is_available_for_assignment(data) or data.unit:movement():chk_action_forbidden("walk") then
		return
	end
	
	do return end

	if not my_data.stare_pos or not my_data.next_scan_t or data.t < my_data.next_scan_t then
		if not my_data.turning and my_data.fwd_offset then
			local return_spin = my_data.rubberband_rotation:to_polar_with_reference(data.unit:movement():m_rot():y(), math.UP).spin

			if math.abs(return_spin) < 15 then
				my_data.fwd_offset = nil
			end

			CopLogicIdle._turn_by_spin(data, my_data, return_spin)
		end

		return
	end

	local beanbag = my_data.scan_beanbag

	if not beanbag then
		beanbag = {}

		for i_pos, pos in ipairs(my_data.stare_pos) do
			table.insert(beanbag, pos)
		end

		my_data.scan_beanbag = beanbag
	end

	local nr_pos = #beanbag
	local scan_pos = nil
	local lucky_i_pos = math.random(nr_pos)
	scan_pos = beanbag[lucky_i_pos]

	if #beanbag == 1 then
		my_data.scan_beanbag = nil
	else
		beanbag[lucky_i_pos] = beanbag[#beanbag]

		table.remove(beanbag)
	end

	CopLogicBase._set_attention_on_pos(data, scan_pos)

	if CopLogicIdle._chk_request_action_turn_to_look_pos(data, my_data, data.m_pos, scan_pos) then
		if my_data.rubberband_rotation then
			my_data.fwd_offset = true
		end

		local upper_body_action = data.unit:movement()._active_actions[3]

		if not upper_body_action then
			local idle_action = {
				body_part = 3,
				type = "idle"
			}

			data.unit:movement():action_request(idle_action)
		end
	end

	my_data.next_scan_t = data.t + math.random(3, 10)
end

function CopLogicIdle._chk_focus_on_undetected_criminal(data, my_data)
	if not data.cool then		
		my_data.current_undetected_criminal_key = nil
		my_data.detected_criminal = nil
		
		my_data.chase_pos = nil
		my_data.chase_crim_path = nil

		if my_data.chase_crim_path_id then
			if data.active_searches[my_data.chase_crim_path_id] then
				managers.navigation:cancel_pathing_search(my_data.chase_crim_path_id)

				data.active_searches[my_data.chase_crim_path_id] = nil
			elseif data.pathing_results then
				data.pathing_results[my_data.chase_crim_path_id] = nil
			end

			my_data.chase_crim_path_id = nil
		end
		
		my_data.chasing = nil
		
		return
	end
		
	if my_data.current_undetected_criminal_key and data.detected_attention_objects[my_data.current_undetected_criminal_key] then
		local attention_info = data.detected_attention_objects[my_data.current_undetected_criminal_key]
		
		return CopLogicIdle._upd_focus_on_undetected_criminal(data, my_data, attention_info)
	else
		if my_data.detected_criminal then
			my_data.needs_logic_reset = true
		end
	
		my_data.current_undetected_criminal_key = nil
		my_data.detected_criminal = nil
		my_data.chasing = nil
		
		my_data.chase_pos = nil
		my_data.chase_crim_path = nil

		if my_data.chase_crim_path_id then
			if data.active_searches[my_data.chase_crim_path_id] then
				managers.navigation:cancel_pathing_search(my_data.chase_crim_path_id)

				data.active_searches[my_data.chase_crim_path_id] = nil
			elseif data.pathing_results then
				data.pathing_results[my_data.chase_crim_path_id] = nil
			end

			my_data.chase_crim_path_id = nil
		end
	
		local best_angle, best_dis, best_att_key
		local fwd = data.unit:movement():m_rot():y()
		local target_vec = temp_vec1
		local my_pos = data.m_pos
		
		local function _get_spin(look_pos)
			mvec3_dir(target_vec, my_pos, look_pos)
			mvec3_set_z(target_vec, 0)
			return target_vec:to_polar_with_reference(fwd, math.UP).spin
		end
		
		for u_key, attention_info in pairs(data.detected_attention_objects) do
			if not attention_info.identified and AIAttentionObject.REACT_SCARED <= attention_info.settings.reaction then
				if attention_info.notice_t and data.t - attention_info.notice_t <= 10 and attention_info.notice_pos then
					local attention_pos = attention_info.handler:get_detection_m_pos()
					local angle = _get_spin(attention_pos)
					
					if not best_angle or math.abs(angle) < math.abs(best_angle) then
						if not best_dis or attention_info.dis < best_dis then
							best_angle = angle
							best_dis = attention_info.dis
							best_att_key = u_key
						end
					end
				end
			end
		end
		
		if best_att_key then
			my_data.current_undetected_criminal_key = best_att_key
			local attention_info = data.detected_attention_objects[my_data.current_undetected_criminal_key]
			
			return CopLogicIdle._upd_focus_on_undetected_criminal(data, my_data, attention_info)
		else
			data.unit:movement():set_stance("ntl")
		end
	end
end

function CopLogicIdle._upd_focus_on_undetected_criminal(data, my_data, attention_info)
	if not attention_info then
		return
	end

	if attention_info.identified then
		my_data.current_undetected_criminal_key = nil
		my_data.detected_criminal = nil
		
		my_data.chase_pos = nil
		my_data.chase_crim_path = nil

		if my_data.chase_crim_path_id then
			if data.active_searches[my_data.chase_crim_path_id] then
				managers.navigation:cancel_pathing_search(my_data.chase_crim_path_id)

				data.active_searches[my_data.chase_crim_path_id] = nil
			elseif data.pathing_results then
				data.pathing_results[my_data.chase_crim_path_id] = nil
			end

			my_data.chase_crim_path_id = nil
		end
		
		my_data.chasing = nil
		
		return
	end
	
	local attention_pos = attention_info.last_notice_pos
	local to_chase_pos = attention_info.notice_pos

	local visible = attention_info.noticed
	local visible_soft = visible
	
	if not visible_soft then
		local attention_real_pos = attention_info.handler:get_detection_m_pos()
	
		local lerp = math.clamp(mvector3.distance(attention_real_pos, attention_info.last_notice_pos) / 400)
						
		if attention_info.notice_t and data.t - attention_info.notice_t < math.lerp(5, 1, lerp) then
			visible_soft = true
		end
	end
	
	local should_turn = my_data.chasing or attention_info.notice_progress and attention_info.notice_progress > 0.1
	local should_chase = my_data.chase_crim_path or my_data.chasing or attention_info.notice_progress and attention_info.notice_progress > 0.5 and attention_info.dis <= 2000
	local turn_to_real_pos
	
	local chase_pos
	
	if (not my_data.chase_duration or my_data.chase_duration < data.t) and not my_data.chasing_run then
		attention_info.being_chased = nil
	end
	
	if not my_data.chasing_run then
		if should_chase and my_data.chase_crim_path and my_data.chase_pos then
			local new_chase_pos = to_chase_pos
			
			if mvector3.distance(my_data.chase_pos, new_chase_pos) > 600 then
				--log("chase reset 1")
				my_data.chase_pos = nil
				my_data.chase_crim_path = nil

				if my_data.chase_crim_path_id then
					if data.active_searches[my_data.chase_crim_path_id] then
						managers.navigation:cancel_pathing_search(my_data.chase_crim_path_id)

						data.active_searches[my_data.chase_crim_path_id] = nil
					elseif data.pathing_results then
						data.pathing_results[my_data.chase_crim_path_id] = nil
					end

					my_data.chase_crim_path_id = nil
				end
			elseif data.unit:raycast("ray", data.unit:movement():m_head_pos(), to_chase_pos:with_z(attention_info.real_pos.z), "slot_mask", data.visibility_slotmask, "ray_type", "ai_vision", "report") then
				mvec3_dir(temp_vec1, data.m_pos, my_data.chase_pos)
				mvec3_set_z(temp_vec1, 0)
				mvec3_dir(temp_vec2, data.m_pos, new_chase_pos)
				mvec3_set_z(temp_vec2, 0)
				
				local dot = mvec3_dot(temp_vec1, temp_vec2)
				
				if dot < 0.34 then
					--log("chase reset 2")
					my_data.chase_pos = nil
					my_data.chase_crim_path = nil

					if my_data.chase_crim_path_id then
						if data.active_searches[my_data.chase_crim_path_id] then
							managers.navigation:cancel_pathing_search(my_data.chase_crim_path_id)

							data.active_searches[my_data.chase_crim_path_id] = nil
						elseif data.pathing_results then
							data.pathing_results[my_data.chase_crim_path_id] = nil
						end

						my_data.chase_crim_path_id = nil
					end
				end
			end
		end
		
		if should_chase and not my_data.chase_pos then
			if math.abs(to_chase_pos.z - data.m_pos.z) < 250 then
				chase_pos = managers.navigation:clamp_position_to_field(to_chase_pos)
				local chase_pos_vis = chase_pos:with_z(attention_info.real_pos.z)
				
				if mvec3_dis_sq(data.m_pos, chase_pos) < 3600 or mvec3_dis_sq(data.unit:movement():m_head_pos(), chase_pos_vis) < 160000 and not data.unit:raycast("ray", data.unit:movement():m_head_pos(), chase_pos_vis, "slot_mask", data.visibility_slotmask, "ray_type", "ai_vision", "report") then
					--log("chase failed 2")
					should_chase = nil
					turn_to_real_pos = true
				end
			else
				--log("chase failed 1")
				should_chase = nil
			end
		end
	end
	
	if not my_data.turning and should_chase and not my_data.chasing_run and (chase_pos or my_data.chase_crim_path) and not data.unit:movement():chk_action_forbidden("walk") then
		--log("chase")
		my_data.detected_criminal = true
		
		if not attention_info.detected_criminal then
			attention_info.detected_criminal = true
		end
		
		if data.objective and data.objective.type ~= "free" and not data.objective.pos then
			data.objective.pos = mvector3.copy(data.m_pos) --we can walk back to our position later when we're done dealing with this idiot
		end
		
		local stance = "hos"
	
		if data.char_tweak.allowed_stances and not data.char_tweak.allowed_stances["hos"] then
			stance = "cbt"
		end
		
		local upper_body_action = data.unit:movement()._active_actions[3]

		if not upper_body_action or upper_body_action:type() ~= "shoot" then
			data.unit:movement():set_stance(stance)
		end

		if my_data.chase_crim_path then
			local chase_see_pos = my_data.chase_pos:with_z(attention_info.real_pos.z)
			local path = my_data.chase_crim_path
		
			my_data.chase_pos = nil
			my_data.chase_crim_path = nil
			
			if path then
				--log("argh")
				CopLogicAttack._correct_path_start_pos(data, path)
				
				local new_action_data = {
					body_part = 2,
					type = "walk",
					nav_path = path,
					variant = "run"
				}
				
				my_data.advancing = data.unit:brain():action_request(new_action_data)

				if my_data.advancing then
					my_data.chasing_run = true
					my_data.chasing = true
					my_data.chase_duration = data.t + 5
					attention_info.being_chased = true
				end
			end
		elseif not my_data.chase_crim_path_id and (not my_data.chase_crim_path_failed_t or data.t - my_data.chase_crim_path_failed_t > 1) then
			my_data.chase_pos = chase_pos			
			my_data.chase_crim_path_id = "chase_crim" .. tostring(data.key)
			
			data.unit:brain():search_for_path(my_data.chase_crim_path_id, chase_pos, nil, nil, nil)
		end

		return true
	elseif not my_data.turning and (data.unit:anim_data().act_idle or data.unit:anim_data().idle) and not my_data.chasing_run and should_turn then
		--log("turn")
		my_data.detected_criminal = true
		
		if not attention_info.detected_criminal then
			attention_info.detected_criminal = true
		end
		
		if my_data.chasing and not turn_to_real_pos and not visible_soft and (not my_data.next_chase_turn_t or my_data.next_chase_turn_t < data.t) then
			local vec_to_pos = attention_info.notice_pos - data.m_pos
			mvec3_set_z(vec_to_pos, 0)
			
			local max_dis = math.lerp(700, 2000, math.random())

			mvector3.set_length(vec_to_pos, max_dis)

			local accross_positions = managers.navigation:find_walls_accross_tracker(data.unit:movement():nav_tracker(), vec_to_pos, 360, 8)
			
			if accross_positions then
				local optimal_dis = max_dis
				local best_error_dis, best_pos, best_is_hit, best_is_miss, best_has_too_much_error = nil

				for _, accross_pos in ipairs(accross_positions) do
					local hit_dis = mvector3.distance(accross_pos[1], attention_info.notice_pos)
					--local too_much_error = error_dis / optimal_dis > 0.2
					
					if hit_dis > 400 then -- dont fuckin https://media.tenor.com/laSBfhRhTEYAAAAM/guy-arguing.gif the wall
						local error_dis = math.abs(mvector3.distance(accross_pos[1], attention_info.notice_pos) - optimal_dis) * (0.5 + math.random())
						
						if not best_error_dis or error_dis < best_error_dis then
							best_pos = accross_pos[1]
							best_error_dis = error_dis
						end
					end
				end
				
				if best_pos then
					mvec3_set_z(best_pos, best_pos.z + 140)
					CopLogicBase._set_attention_on_pos(data, best_pos)

					if data.unit:anim_data().act_idle and not data.unit:anim_data().to_idle then
						CopLogicIdle._start_idle_action_from_act(data)
					end
				
					local turn_angle = CopLogicIdle._chk_turn_needed(data, my_data, data.m_pos, best_pos)
					
					if turn_angle then
						CopLogicIdle._turn_by_spin(data, my_data, turn_angle)

						if my_data.turning then
							my_data.next_chase_turn_t = data.t + math.lerp(2, 3, math.random())
							if my_data.rubberband_rotation then
								my_data.fwd_offset = true
							end
						end
					end
				end
			end
		else
			local turn_to_pos = attention_pos
			
			if turn_to_real_pos then
				turn_to_pos = attention_info.real_pos
			elseif mvec3_dis_sq(data.unit:movement():m_head_pos(), attention_info.real_pos) < 160000 and not data.unit:raycast("ray", data.unit:movement():m_head_pos(), attention_info.real_pos, "slot_mask", data.visibility_slotmask, "ray_type", "ai_vision", "report") then
				turn_to_pos = attention_info.real_pos
			end
		
			CopLogicBase._set_attention_on_pos(data, turn_to_pos)
			
			if data.unit:anim_data().act_idle and not data.unit:anim_data().to_idle then
				CopLogicIdle._start_idle_action_from_act(data)
			end
		
			local turn_angle = CopLogicIdle._chk_turn_needed(data, my_data, data.m_pos, turn_to_pos)
			
			if turn_angle then
				CopLogicIdle._turn_by_spin(data, my_data, turn_angle)
				
				if my_data.turning then
					if my_data.rubberband_rotation then
						my_data.fwd_offset = true
					end
				end
			end
		end
		
		return true
	elseif not should_chase and not should_turn and not my_data.chasing_run and not my_data.chasing then
		data.unit:movement():set_stance("ntl")
		
		return true
	end
end


function CopLogicIdle._upd_stance_and_pose(data, my_data, objective)
	if data.unit:movement():chk_action_forbidden("walk") then
		return
	end

	local obj_has_stance, obj_has_pose = nil

	if objective then
		if not my_data.detected_criminal and objective.stance and (not data.char_tweak.allowed_stances or data.char_tweak.allowed_stances[objective.stance]) then
			obj_has_stance = true
			local upper_body_action = data.unit:movement()._active_actions[3]

			if not upper_body_action or upper_body_action:type() ~= "shoot" then
				data.unit:movement():set_stance(objective.stance)
			end
		end

		if objective.pose and (not data.char_tweak.allowed_poses or data.char_tweak.allowed_poses[objective.pose]) then
			obj_has_pose = true

			if objective.pose == "crouch" then
				CopLogicAttack._chk_request_action_crouch(data)
			elseif objective.pose == "stand" then
				CopLogicAttack._chk_request_action_stand(data)
			end
		end
	end

	if not my_data.detected_criminal and not obj_has_stance and data.char_tweak.allowed_stances and not data.char_tweak.allowed_stances[data.unit:anim_data().stance] then
		for stance_name, state in pairs(data.char_tweak.allowed_stances) do
			if state then
				data.unit:movement():set_stance(stance_name)

				break
			end
		end
	end

	if not obj_has_pose then
		if data.char_tweak.allowed_poses and not data.char_tweak.allowed_poses[data.unit:anim_data().pose] then
			for pose_name, state in pairs(data.char_tweak.allowed_poses) do
				if state then
					if pose_name == "crouch" then
						CopLogicAttack._chk_request_action_crouch(data)

						break
					end

					if pose_name == "stand" then
						CopLogicAttack._chk_request_action_stand(data)
					end

					break
				end
			end
		end
	end
end

function CopLogicIdle._get_all_paths(data)
	return {
		stare_path = data.internal_data.stare_path,
		chase_crim_path = data.internal_data.chase_crim_path
	}
end

function CopLogicIdle._set_verified_paths(data, verified_paths)
	data.internal_data.stare_path = verified_paths.stare_path
	data.internal_data.chase_crim_path = verified_paths.chase_crim_path
end

function CopLogicIdle.is_available_for_assignment(data, objective)
	if objective and objective.forced then
		return true
	end
	
	local my_data = data.internal_data
	
	if my_data.detected_criminal then
		return
	end

	if data.objective and data.objective.action then
		if my_data.action_started then
			if not data.unit:anim_data().act_idle then
				return
			end
		else
			return
		end
	end

	if my_data.exiting or data.path_fail_t and data.t < data.path_fail_t + 3 then
		return
	end

	return true
end

function CopLogicIdle.exit(data, new_logic_name, enter_params)
	CopLogicBase.exit(data, new_logic_name, enter_params)

	local my_data = data.internal_data

	data.unit:brain():cancel_all_pathing_searches()
	CopLogicBase.cancel_queued_tasks(my_data)
	CopLogicBase.cancel_delayed_clbks(my_data)

	if my_data.best_cover then
		managers.navigation:release_cover(my_data.best_cover[1])
	end

	if my_data.nearest_cover then
		managers.navigation:release_cover(my_data.nearest_cover[1])
	end

	data.brain:rem_pos_rsrv("path")
end

function CopLogicIdle._check_needs_reload(data, my_data)
	if data.unit:anim_data().reload then
		return
	end
	
	local weapon, weapon_base, ammo_max, ammo

	if alive(data.unit) and data.unit:inventory() then
		weapon = data.unit:inventory():equipped_unit()
	
		if weapon and alive(weapon) then
			weapon_base = weapon and weapon:base()
			ammo_max, ammo = weapon_base:ammo_info()
			local state = data.name
			
			if ammo / ammo_max >= 0.5 then
				if my_data.shooting then
					local new_action = {
						body_part = 3,
						type = "idle"
					}

					data.unit:brain():action_request(new_action)
				end
				
				return
			end
		end
	end
	
	if not ammo then
		return
	end
	
	local needs_reload = nil
	
	if ammo / ammo_max < 0.5 then
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

function CopLogicIdle._upd_enemy_detection(data)
	managers.groupai:state():on_unit_detection_updated(data.unit)

	data.t = TimerManager:game():time()
	local my_data = data.internal_data
	local min_reaction = not data.cool and AIAttentionObject.REACT_SCARED
	CopLogicBase._upd_attention_obj_detection(data, min_reaction, nil)
	
	local delay = 0
	
	if not managers.groupai:state():whisper_mode() then
		delay = (data.unit:anim_data().hide or data.unit:anim_data().hide_loop) and 0.5 or data.important and 0.7 or 1.4
	end
	
	local new_attention, new_prio_slot, new_reaction = CopLogicIdle._get_priority_attention(data, data.detected_attention_objects)

	CopLogicBase._set_attention_obj(data, new_attention, new_reaction)

	if new_reaction and AIAttentionObject.REACT_SUSPICIOUS < new_reaction then
		local objective = data.objective
		local wanted_state = nil
		local allow_trans, obj_failed = CopLogicBase.is_obstructed(data, objective, nil, new_attention)

		if allow_trans then
			wanted_state = CopLogicBase._get_logic_state_from_reaction(data)
		end

		if wanted_state and wanted_state ~= data.name then
			if obj_failed then
				data.objective_failed_clbk(data.unit, data.objective)
			end

			if my_data == data.internal_data then
				CopLogicBase._exit(data.unit, wanted_state)
			end
		end
	end

	if my_data == data.internal_data then
		CopLogicBase._chk_call_the_police(data)

		if my_data ~= data.internal_data then
			return delay
		end
	end

	return delay
end

function CopLogicIdle._chk_reaction_to_attention_object(data, attention_data, stationary)
	local record = attention_data.criminal_record
	local can_arrest = CopLogicBase._can_arrest(data)

	if not record or not attention_data.is_person then
		if attention_data.settings.reaction == AIAttentionObject.REACT_ARREST and not can_arrest then
			return AIAttentionObject.REACT_AIM
		else
			return attention_data.settings.reaction
		end
	end

	local att_unit = attention_data.unit

	if attention_data.is_deployable or data.t < record.arrest_timeout then
		return math.min(attention_data.settings.reaction, AIAttentionObject.REACT_COMBAT)
	end

	local visible = attention_data.verified

	if record.status == "dead" then
		return math.min(attention_data.settings.reaction, AIAttentionObject.REACT_AIM)	
	elseif record.status == "disabled" then
		if LIES.settings.hhtacs then
			if data.tactics and data.tactics.murder then
				return math.min(attention_data.settings.reaction, AIAttentionObject.REACT_COMBAT)
			end
		end
	
		if record.assault_t and record.assault_t - record.disabled_t > 0.6 then
			return math.min(attention_data.settings.reaction, AIAttentionObject.REACT_COMBAT)
		else
			return math.min(attention_data.settings.reaction, AIAttentionObject.REACT_AIM)
		end
	elseif record.being_arrested then
		return math.min(attention_data.settings.reaction, AIAttentionObject.REACT_AIM)
	elseif can_arrest and (not record.assault_t or att_unit:base():arrest_settings().aggression_timeout < data.t - record.assault_t) and record.arrest_timeout < data.t and not record.status then
		local under_threat = nil

		if attention_data.dis < 2000 then
			for u_key, other_crim_rec in pairs(managers.groupai:state():all_criminals()) do
				local other_crim_attention_info = data.detected_attention_objects[u_key]

				if other_crim_attention_info and (other_crim_attention_info.is_deployable or other_crim_attention_info.verified and other_crim_rec.assault_t and data.t - other_crim_rec.assault_t < other_crim_rec.unit:base():arrest_settings().aggression_timeout) then
					under_threat = true

					break
				end
			end
		end

		if under_threat then
			
		elseif attention_data.dis < 2000 and visible then
			return math.min(attention_data.settings.reaction, AIAttentionObject.REACT_ARREST)
		else
			return math.min(attention_data.settings.reaction, AIAttentionObject.REACT_AIM)
		end
	end

	return math.min(attention_data.settings.reaction, AIAttentionObject.REACT_COMBAT)
end

function CopLogicIdle._get_priority_attention(data, attention_objects, reaction_func)
	local best_target, best_target_priority_slot, best_target_priority, best_target_reaction = nil
	
	if data.is_converted or data.char_tweak.buddy then
		best_target, best_target_priority_slot, best_target_reaction = TeamAILogicIdle._get_priority_attention(data, attention_objects, reaction_func)
		
		return best_target, best_target_priority_slot, best_target_reaction
	end

	reaction_func = reaction_func or CopLogicIdle._chk_reaction_to_attention_object
	local forced_attention_data = managers.groupai:state():force_attention_data(data.unit)

	if forced_attention_data then
		if data.attention_obj and data.attention_obj.unit == forced_attention_data.unit then
			return data.attention_obj, 1, AIAttentionObject.REACT_SHOOT
		end

		local forced_attention_object = managers.groupai:state():get_AI_attention_object_by_unit(forced_attention_data.unit)

		if forced_attention_object then
			for u_key, attention_info in pairs(forced_attention_object) do
				if forced_attention_data.ignore_vis_blockers then
					local vis_ray = World:raycast("ray", data.unit:movement():m_head_pos(), attention_info.handler:get_detection_m_pos(), "slot_mask", data.visibility_slotmask, "ray_type", "ai_vision")

					if not vis_ray or vis_ray.unit:key() == u_key or not vis_ray.unit:visible() then
						best_target = CopLogicBase._create_detected_attention_object_data(data.t, data.unit, u_key, attention_info, attention_info.handler:get_attention(data.SO_access), true)
						best_target.verified = true
					end
				else
					best_target = CopLogicBase._create_detected_attention_object_data(data.t, data.unit, u_key, attention_info, attention_info.handler:get_attention(data.SO_access), true)
				end
			end
		else
			Application:error("[CopLogicIdle._get_priority_attention] No attention object available for unit", inspect(forced_attention_data))
		end

		if best_target then
			return best_target, 1, AIAttentionObject.REACT_SHOOT
		end
	end

	local near_threshold = data.internal_data.weapon_range.optimal
	local too_close_threshold = data.internal_data.weapon_range.close
	local tactics_harass = data.tactics and data.tactics.harass
	local tactics_dg = data.tactics and data.tactics.deathguard
	local hhtacs = LIES.settings.hhtacs
	local rescueable_hostages, all_civilians

	for u_key, attention_data in pairs(attention_objects) do
		local att_unit = attention_data.unit
		local crim_record = attention_data.criminal_record

		if not attention_data.identified then
			if data.cool then
				if AIAttentionObject.REACT_SUSPICIOUS <= attention_data.reaction then
					if attention_data.notice_progress > (hhtacs and 0.1 or 0) then
						if not attention_data.reacted_to then
							if crim_record then
								if math.random() <= 0.25 then
									data.unit:sound():say("a07a", true)
								end
							else
								if math.random() <= 0.25 then
									data.unit:sound():say("a07b", true)
								end
							end
							
							attention_data.reacted_to = true
						end
					elseif attention_data.reacted_to then
						attention_data.reacted_to = nil
					end
				end
			end
		elseif attention_data.pause_expire_t then
			if attention_data.pause_expire_t < data.t then
				if not attention_data.settings.attract_chance or math.random() < attention_data.settings.attract_chance then
					attention_data.pause_expire_t = nil
				else
					debug_pause_unit(data.unit, "[ CopLogicIdle._get_priority_attention] skipping attraction")

					attention_data.pause_expire_t = data.t + math.lerp(attention_data.settings.pause[1], attention_data.settings.pause[2], math.random())
				end
			end
		elseif attention_data.stare_expire_t and attention_data.stare_expire_t < data.t then
			if attention_data.settings.pause then
				attention_data.stare_expire_t = nil
				attention_data.pause_expire_t = data.t + math.lerp(attention_data.settings.pause[1], attention_data.settings.pause[2], math.random())
			end
		else
			local distance = attention_data.dis
			local reaction = reaction_func(data, attention_data, not CopLogicAttack._can_move(data))

			if data.cool and AIAttentionObject.REACT_SCARED <= reaction then
				data.unit:movement():set_cool(false, managers.groupai:state().analyse_giveaway(data.unit:base()._tweak_table, att_unit))
				
				if data.char_tweak.chatter and data.unit:base():has_tag("law") then
					if crim_record and not crim_record.is_deployable then
						if not crim_record.det_t or data.t - crim_record.det_t > 15 or crim_record.gun_called_out then
							data.unit:sound():say("a08", true)
						elseif not crim_record.gun_called_out and data.char_tweak.chatter.criminalhasgun then
							crim_record.gun_called_out = managers.groupai:state():chk_say_enemy_chatter(data.unit, data.m_pos, "criminalhasgun")
						end
					end
				end
			end

			local reaction_too_mild = nil

			if not reaction or best_target_reaction and reaction < best_target_reaction then
				reaction_too_mild = true
			elseif reaction == AIAttentionObject.REACT_IDLE then
				reaction_too_mild = true
			end

			if not reaction_too_mild then
				local aimed_at = CopLogicIdle.chk_am_i_aimed_at(data, attention_data, attention_data.aimed_at and 0.95 or 0.985)
				attention_data.aimed_at = aimed_at
				local alert_dt = attention_data.alert_t and data.t - attention_data.alert_t or 10000
				local dmg_dt = attention_data.dmg_t and data.t - attention_data.dmg_t or 10000
				local status = crim_record and crim_record.status
				local nr_enemies = crim_record and crim_record.engaged_force
				local old_enemy = false

				if data.attention_obj and data.attention_obj.u_key == u_key and data.t - attention_data.acquire_t < 4 then
					old_enemy = true
				end

				local weight_mul = attention_data.settings.weight_mul

				if attention_data.is_local_player then
					local cur_state = att_unit:movement():current_state()
					
					if not cur_state._moving and cur_state:ducking() then
						weight_mul = (weight_mul or 1) * managers.player:upgrade_value("player", "stand_still_crouch_camouflage_bonus", 1)
					end

					if managers.player:has_activate_temporary_upgrade("temporary", "chico_injector") and managers.player:upgrade_value("player", "chico_preferred_target", false) then
						weight_mul = (weight_mul or 1) * 1000
					end

					if _G.IS_VR and tweak_data.vr.long_range_damage_reduction_distance[1] < distance then
						local mul = math.clamp(distance / tweak_data.vr.long_range_damage_reduction_distance[2] / 2, 0, 1) + 1
						weight_mul = (weight_mul or 1) * mul
					end
					
					if tactics_harass then
						if cur_state:_is_reloading() or cur_state:_interacting() or cur_state:is_equipping() then
							weight_mul = (weight_mul or 1) * 1.25
						end
					elseif not tactics_dg then
						local iparams = att_unit:movement():current_state()._interact_params

						if iparams and managers.criminals:character_name_by_unit(iparams.object) ~= nil then
							weight_mul = (weight_mul or 1) * 0.75
						end
					end
				elseif att_unit:base() and att_unit:base().upgrade_value then
					if att_unit:movement() and not att_unit:movement()._move_data and att_unit:movement()._pose_code and att_unit:movement()._pose_code == 2 then
						weight_mul = (weight_mul or 1) * (att_unit:base():upgrade_value("player", "stand_still_crouch_camouflage_bonus") or 1)
					end

					if att_unit:base().has_activate_temporary_upgrade and att_unit:base():has_activate_temporary_upgrade("temporary", "chico_injector") and att_unit:base():upgrade_value("player", "chico_preferred_target") then
						weight_mul = (weight_mul or 1) * 1000
					end

					if att_unit:movement().is_vr and att_unit:movement():is_vr() and tweak_data.vr.long_range_damage_reduction_distance[1] < distance then
						local mul = math.clamp(distance / tweak_data.vr.long_range_damage_reduction_distance[2] / 2, 0, 1) + 1
						weight_mul = (weight_mul or 1) * mul
					end
					
					if tactics_harass and att_unit:anim_data() then
						local att_anim_data = att_unit:anim_data()

						if att_anim_data.interact or att_anim_data.reload or att_anim_data.switch_weapon or att_anim_data.revive then
							weight_mul = (weight_mul or 1) * 1.25
						end
					elseif not tactics_dg and att_unit:anim_data() and att_unit:anim_data().revive then
						weight_mul = (weight_mul or 1) * 0.75
					end
				end
				
				if hhtacs then
					if crim_record and attention_data.nav_tracker and AIAttentionObject.REACT_COMBAT <= reaction then
						local hostages = 0
						local hostage_blocked = false
						
						if not rescueable_hostages then
							rescueable_hostages = managers.groupai:state():rescueable_hostages()
						end
						
						for hos_key, hos_table in pairs(rescueable_hostages) do
							local hos_area = hos_table.area
							local hos_pos = hos_table.pos
							
							if hos_area.nav_segs[attention_data.nav_tracker:nav_segment()] or math.abs(hos_pos.z - attention_data.m_pos.z) < 250 and mvector3.distance_sq(attention_data.m_pos, hos_pos) < 250000 then
								hostages = hostages + 1
									
								if hostages > 1 then
									hostage_blocked = true
									
									break
								end
							end
						end

						if not hostage_blocked then
							if not all_civilians then
								all_civilians = managers.enemy:all_civilians()
							end
						
							for civ_key, civ_data in pairs(all_civilians) do
								if not rescueable_hostages[civ_key] and alive(civ_data.unit) then
									local civ_area = managers.groupai:state():get_area_from_nav_seg_id(civ_data.tracker:nav_segment())
									
									if civ_area.nav_segs[attention_data.nav_tracker:nav_segment()] or math.abs(civ_data.m_pos.z - attention_data.m_pos.z) < 250 and mvector3.distance_sq(attention_data.m_pos, civ_data.m_pos) < 250000 then
										hostages = hostages + 1
								
										if hostages > 1 then
											hostage_blocked = true
											
											break
										end
									end
								end
							end
						end
						
						attention_data.hostage_blocked = hostage_blocked
					elseif attention_data.hostage_blocked then
						attention_data.hostage_blocked = nil
					end
				end
				
				if weight_mul and weight_mul ~= 1 then
					weight_mul = 1 / weight_mul
					alert_dt = alert_dt and alert_dt * weight_mul
					dmg_dt = dmg_dt and dmg_dt * weight_mul
					distance = distance * weight_mul
				end

				local assault_reaction = reaction == AIAttentionObject.REACT_SPECIAL_ATTACK
				local visible = attention_data.verified
				local near = distance < near_threshold
				local too_near = distance < too_close_threshold and math.abs(attention_data.m_pos.z - data.m_pos.z) < 250
				local free_status = status == nil
				local has_alerted = alert_dt < 3.5
				local has_damaged = dmg_dt < 5
				local reviving = nil

				local target_priority = distance
				local target_priority_slot = 0

				if visible or data.logic._keep_player_focus_t and attention_data.is_human_player and attention_data.verified_t and data.t - attention_data.verified_t < data.logic._keep_player_focus_t then
					if distance < 500 then
						target_priority_slot = 2
					elseif distance < 1500 then
						target_priority_slot = 4
					else
						target_priority_slot = 6
					end
					
					if free_status and assault_reaction then
						target_priority_slot = math.min(target_priority_slot, 3)
					elseif has_damaged then
						target_priority_slot = target_priority_slot - 2
					elseif has_alerted then
						target_priority_slot = target_priority_slot - 1
					end
					
					
					local target_vec = temp_vec3
					mvec3_dir(target_vec, data.m_pos, attention_data.m_pos)
					mvec3_set_z(target_vec, 0)
					local my_fwd = data.unit:movement():m_fwd()
					local dot = mvec3_dot(target_vec, my_fwd)
					
					if dot < 0.6 then
						target_priority_slot = target_priority_slot + 1
					end
					
					if old_enemy then
						target_priority_slot = target_priority_slot - 3
					end
					
					if data.logic._keep_player_focus_t and not attention_data.is_human_player then
						target_priority_slot = target_priority_slot + 3
					end

					target_priority_slot = math.clamp(target_priority_slot, 1, 10)
				elseif free_status then
					target_priority_slot = 11
					
					if old_enemy then
						target_priority_slot = target_priority_slot - 3
					elseif has_damaged then
						target_priority_slot = target_priority_slot - 2
					elseif has_alerted then
						target_priority_slot = target_priority_slot - 1
					end
				end

				if reaction < AIAttentionObject.REACT_COMBAT then
					target_priority_slot = 11 + target_priority_slot + math.max(0, AIAttentionObject.REACT_COMBAT - reaction)
				end

				if target_priority_slot ~= 0 then
					local best = false

					if not best_target then
						best = true
					elseif target_priority_slot < best_target_priority_slot then
						best = true
					elseif target_priority_slot == best_target_priority_slot and target_priority < best_target_priority then
						best = true
					end

					if best then
						best_target = attention_data
						best_target_reaction = reaction
						best_target_priority_slot = target_priority_slot
						best_target_priority = target_priority
					end
				end
			end
		end
	end

	return best_target, best_target_priority_slot, best_target_reaction
end

function CopLogicIdle.on_new_objective(data, old_objective)
	local new_objective = data.objective

	CopLogicBase.on_new_objective(data, old_objective)

	local my_data = data.internal_data

	if new_objective then
		local objective_type = new_objective.type

		if CopLogicIdle._chk_objective_needs_travel(data, new_objective) then
			CopLogicBase._exit(data.unit, "travel")
		elseif objective_type == "guard" then
			CopLogicBase._exit(data.unit, "guard")
		elseif objective_type == "security" then
			CopLogicBase._exit(data.unit, "idle")
		elseif objective_type == "sniper" then
			CopLogicBase._exit(data.unit, "sniper")
		elseif objective_type == "phalanx" then
			CopLogicBase._exit(data.unit, "phalanx")
		elseif objective_type == "surrender" then
			CopLogicBase._exit(data.unit, "intimidated", new_objective.params)
		elseif objective_type == "free" and my_data.exiting then
			-- Nothing
		elseif new_objective.action or not data.attention_obj or AIAttentionObject.REACT_AIM > data.attention_obj.reaction then
			CopLogicBase._exit(data.unit, "idle")
		elseif data.name ~= "attack" then
			CopLogicBase._exit(data.unit, "attack")
		else
			my_data.attitude = new_objective.attitude or my_data.attitude
		end
	elseif not my_data.exiting then
		if data.attention_obj and AIAttentionObject.REACT_AIM <= data.attention_obj.reaction then
			CopLogicBase._exit(data.unit, "attack")
		else
			CopLogicBase._exit(data.unit, "idle")
		end
	end

	if new_objective and new_objective.stance then
		if new_objective.stance == "ntl" then
			--data.unit:movement():set_cool(true)
		else
			--data.unit:movement():set_cool(false)
		end
	end

	if old_objective and old_objective.fail_clbk then
		old_objective.fail_clbk(data.unit)
	end
end

function CopLogicIdle.damage_clbk(data, damage_info)
	local enemy = damage_info.attacker_unit
	local enemy_data = nil

	if enemy and enemy:in_slot(data.enemy_slotmask) then
		local my_data = data.internal_data
		local enemy_key = enemy:key()
		enemy_data = data.detected_attention_objects[enemy_key]
		local t = TimerManager:game():time()

		if enemy_data then
			enemy_data.dmg_t = t
			enemy_data.alert_t = t
			enemy_data.notice_delay = nil

			if not enemy_data.identified then
				enemy_data.identified = true
				enemy_data.identified_t = t
				enemy_data.notice_progress = nil
				enemy_data.prev_notice_chk_t = nil

				if enemy_data.settings.notice_clbk then
					enemy_data.settings.notice_clbk(data.unit, true)
				end

				data.logic.on_attention_obj_identified(data, enemy_key, enemy_data)
			end
		else
			local attention_info = managers.groupai:state():get_AI_attention_objects_by_filter(data.SO_access_str)[enemy_key]

			if attention_info then
				local settings = attention_info.handler:get_attention(data.SO_access, nil, nil, data.team)

				if settings then
					enemy_data = CopLogicBase.identify_attention_obj_instant(data, enemy_key)
					enemy_data.dmg_t = t
					enemy_data.alert_t = t
					enemy_data.identified = true
					enemy_data.identified_t = t
					enemy_data.notice_progress = nil
					enemy_data.prev_notice_chk_t = nil

					if enemy_data.settings.notice_clbk then
						enemy_data.settings.notice_clbk(data.unit, true)
					end

					data.detected_attention_objects[enemy_key] = enemy_data

					data.logic.on_attention_obj_identified(data, enemy_key, enemy_data)
				end
			end
		end
	end

	if enemy_data and enemy_data.criminal_record then
		if data.group then
			managers.groupai:state():criminal_spotted(enemy, true)
			managers.groupai:state():report_aggression(enemy)
		end
	end
end

function CopLogicIdle._chk_relocate(data)
	if not data.objective then
		return
	end

	if data.objective and data.objective.type == "follow" then
		if not data.objective.follow_unit or not alive(data.objective.follow_unit) then
			data.brain:set_objective(nil)
			
			return true
		end
	
		if data.is_converted or data.unit:in_slot(16) then
			if TeamAILogicIdle._check_should_relocate(data, data.internal_data, data.objective) then
				data.objective.in_place = nil

				data.logic._exit(data.unit, "travel")

				return true
			end

			return
		end

		if data.is_tied and data.objective.lose_track_dis and data.objective.lose_track_dis * data.objective.lose_track_dis < mvector3.distance_sq(data.m_pos, data.objective.follow_unit:movement():m_pos()) then
			data.brain:set_objective(nil)

			return true
		end

		local relocate = nil
		local follow_unit = data.objective.follow_unit
		local advance_pos = follow_unit:brain() and follow_unit:brain():is_advancing()
		local follow_unit_pos = advance_pos or follow_unit:movement():m_pos()

		if data.objective.relocated_to and mvector3.distance_sq(data.objective.relocated_to, follow_unit_pos) < 3600 then
			return
		end
		
		if data.is_tied and 60 < mvector3.distance(data.m_pos, follow_unit_pos) then
			relocate = true
		elseif data.objective.distance and data.objective.distance < mvector3.distance(data.m_pos, follow_unit_pos) then
			relocate = true
		end

		if not relocate then
			local ray_params = {
				pos_to = follow_unit_pos
			}
			
			if data.objective.relocated_to then
				ray_params.pos_from = data.objective.relocated_to
			else
				ray_params.tracker_from = data.unit:movement():nav_tracker()
			end
			
			local ray_res = managers.navigation:raycast(ray_params)

			if ray_res then
				relocate = true
			end
		end

		if relocate then
			data.objective.in_place = nil
			data.objective.nav_seg = follow_unit:movement():nav_tracker():nav_segment()
			data.objective.relocated_to = mvector3.copy(follow_unit_pos)

			data.logic._exit(data.unit, "travel")

			return true
		end
	end
end

function CopLogicIdle.action_complete_clbk(data, action)
	local action_type = action:type()

	if action_type == "turn" then
		data.internal_data.turning = nil

		if data.internal_data.fwd_offset then
			local return_spin = data.internal_data.rubberband_rotation:to_polar_with_reference(data.unit:movement():m_rot():y(), math.UP).spin

			if math.abs(return_spin) < 15 then
				data.internal_data.fwd_offset = nil
			end
		end
	elseif action_type == "act" then
		local my_data = data.internal_data

		if my_data.action_started == action then
			if my_data.scan and not my_data.exiting and (not my_data.queued_tasks or not my_data.queued_tasks[my_data.wall_stare_task_key]) and not my_data.stare_path_pos then
				CopLogicBase.queue_task(my_data, my_data.wall_stare_task_key, CopLogicIdle._chk_stare_into_wall_1, data, data.t)
			end

			if action:expired() then
				if not my_data.action_timeout_clbk_id then
					data.objective_complete_clbk(data.unit, data.objective)
				end
			elseif not my_data.action_expired and not my_data.detected_criminal then
				data.objective_failed_clbk(data.unit, data.objective)
			else
				my_data.action_started = nil
			end
		end
	elseif action_type == "shoot" then
		data.internal_data.shooting = nil
	elseif action_type == "walk" then		
		data.internal_data.advancing = nil
		data.internal_data.old_action_advancing = nil
		
		if data.internal_data.chasing_run then
			data.internal_data.chase_duration = data.t + 5
		end
		
		data.internal_data.chasing_run = nil
		
		
	elseif not data.is_converted and action_type == "hurt" and data.important and action:expired() then
		CopLogicBase.chk_start_action_dodge(data, "hit")
	end
end

function CopLogicIdle.on_alert(data, alert_data)
	local alert_type = alert_data[1]
	local alert_unit = alert_data[5]

	if CopLogicBase._chk_alert_obstructed(data.unit:movement():m_head_pos(), alert_data) then
		return
	end

	local was_cool = data.cool

	if CopLogicBase.is_alert_aggressive(alert_type) then
		data.unit:movement():set_cool(false, managers.groupai:state().analyse_giveaway(data.unit:base()._tweak_table, alert_data[5], alert_data))
	end

	if alert_unit and alive(alert_unit) and alert_unit:in_slot(data.enemy_slotmask) then
		local att_obj_data, is_new = CopLogicBase.identify_attention_obj_instant(data, alert_unit:key())

		if not att_obj_data then
			return
		end

		if alert_type == "bullet" or alert_type == "aggression" or alert_type == "explosion" then
			att_obj_data.alert_t = TimerManager:game():time()
		end

		local action_data = nil

		if was_cool and is_new and (not data.char_tweak.allowed_poses or data.char_tweak.allowed_poses.stand) and AIAttentionObject.REACT_SURPRISED <= att_obj_data.reaction and data.unit:anim_data().idle and not data.unit:movement():chk_action_forbidden("walk") then
			action_data = {
				variant = "surprised",
				body_part = 1,
				type = "act"
			}

			data.unit:brain():action_request(action_data)
		elseif not is_new and att_obj_data.is_person and att_obj_data.verified and att_obj_data.crim_record and not att_obj_data.crim_record.gun_called_out and data.char_tweak.chatter.criminalhasgun then
			if alert_type == "bullet" or alert_type == "aggression" or alert_type == "explosion" then
				new_crim_rec.gun_called_out = managers.groupai:state():chk_say_enemy_chatter(data.unit, data.m_pos, "criminalhasgun")
			end
		end

		if att_obj_data.criminal_record then
			if data.group then
				managers.groupai:state():criminal_spotted(alert_unit)

				if alert_type == "bullet" or alert_type == "aggression" or alert_type == "explosion" then
					managers.groupai:state():report_aggression(alert_unit)
				end
			end
		end
	elseif was_cool and (alert_type == "footstep" or alert_type == "bullet" or alert_type == "aggression" or alert_type == "explosion" or alert_type == "vo_cbt" or alert_type == "vo_intimidate" or alert_type == "vo_distress") then
		local attention_obj = alert_unit and alert_unit:brain() and alert_unit:brain()._logic_data and alert_unit:brain()._logic_data.attention_obj

		if attention_obj then
			local att_obj_data, is_new = CopLogicBase.identify_attention_obj_instant(data, attention_obj.u_key)
		end
	end
end

function CopLogicIdle._move_back_into_field_position(data, my_data)
	if data.unit:movement():chk_action_forbidden("walk") then
		return
	end

	local my_tracker = data.unit:movement():nav_tracker()
	
	if my_tracker:lost() then
		local field_position = my_tracker:field_position()
		
		if mvector3.distance_sq(data.m_pos, field_position) > 900 then	
			local path = {
				mvector3.copy(data.m_pos),
				field_position
			}

			local new_action_data = {
				type = "walk",
				body_part = 2,
				nav_path = path,
				variant = data.cool and "walk" or "run"
			}
			my_data.advancing = data.unit:brain():action_request(new_action_data)

			return my_data.advancing
		end
	end
end

function CopLogicIdle._chk_start_action_move_out_of_the_way(data, my_data)
	if data.unit:movement():chk_action_forbidden("walk") then
		return
	end

	local reservation = {
		radius = 30,
		position = data.m_pos,
		filter = data.pos_rsrv_id
	}

	if not managers.navigation:is_pos_free(reservation) then
		local to_pos = CopLogicTravel._get_pos_on_wall(data.m_pos, 500)

		if to_pos then
			local path = {
				mvector3.copy(data.m_pos),
				to_pos
			}

			local new_action_data = {
				type = "walk",
				body_part = 2,
				nav_path = path,
				variant = data.cool and "walk" or "run"
			}
			my_data.advancing = data.unit:brain():action_request(new_action_data)

			return my_data.advancing
		end
	end
end