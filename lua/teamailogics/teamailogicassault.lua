TeamAILogicAssault._COVER_CHK_INTERVAL = 0.7

function TeamAILogicAssault.enter(data, new_logic_name, enter_params)
	TeamAILogicBase.enter(data, new_logic_name, enter_params)
	data.unit:brain():cancel_all_pathing_searches()

	local old_internal_data = data.internal_data
	local my_data = {
		unit = data.unit
	}
	data.internal_data = my_data
	my_data.detection = data.char_tweak.detection.combat
	my_data.cover_chk_t = 0
	my_data.weapon_range = data.char_tweak.weapon[data.unit:inventory():equipped_unit():base():weapon_tweak_data().usage].range

	if old_internal_data then
		my_data.turning = old_internal_data.turning
		my_data.firing = old_internal_data.firing
		my_data.shooting = old_internal_data.shooting
		my_data.attention_unit = old_internal_data.attention_unit

		CopLogicAttack._set_best_cover(data, my_data, old_internal_data.best_cover)
	end

	local key_str = tostring(data.key)
	my_data.detection_task_key = "TeamAILogicAssault._upd_enemy_detection" .. key_str

	CopLogicBase.queue_task(my_data, my_data.detection_task_key, TeamAILogicAssault._upd_enemy_detection, data, data.t)
	
	CopLogicIdle._chk_has_old_action(data, my_data)

	if data.objective then
		my_data.attitude = data.objective.attitude
	end

	data.unit:movement():set_cool(false)
	data.unit:movement():set_stance("hos")

	my_data.weapon_range = data.char_tweak.weapon[data.unit:inventory():equipped_unit():base():weapon_tweak_data().usage].range
	my_data.cover_test_step = 0
end

function TeamAILogicAssault.update(data)
	local my_data = data.internal_data
	local t = data.t
	local unit = data.unit
	
	if my_data.has_old_action or my_data.old_action_advancing then
		CopLogicAttack._upd_stop_old_action(data, my_data)
		
		--log("yippie!")
		
		if my_data.has_old_action or my_data.old_action_advancing then
			return
		end
	end
	
	local focus_enemy = data.attention_obj

	CopLogicAttack._process_pathing_results(data, my_data)

	local focus_enemy = data.attention_obj

	if not focus_enemy or focus_enemy.reaction < AIAttentionObject.REACT_AIM then
		TeamAILogicAssault._upd_enemy_detection(data, true)

		if my_data ~= data.internal_data or not data.attention_obj or data.attention_obj.reaction <= AIAttentionObject.REACT_SCARED then
			return
		end

		focus_enemy = data.attention_obj
	end
	
	local action_taken = my_data.advancing or my_data.turning or data.unit:movement():chk_action_forbidden("walk") or my_data.moving_to_cover or my_data.walking_to_cover_shoot_pos or my_data._turning_to_intimidate
	
	local enemy_visible = focus_enemy.verified
		
	my_data.want_to_take_cover = TeamAILogicAssault._chk_wants_to_take_cover(data, my_data)
	local want_to_take_cover = my_data.want_to_take_cover
	action_taken = action_taken or CopLogicAttack._upd_pose(data, my_data)
	
	if not data.unit:movement()._should_stay then
		if my_data.cover_chk_t < data.t then
			CopLogicAttack._update_cover(data)

			my_data.cover_chk_t = data.t + TeamAILogicAssault._COVER_CHK_INTERVAL
		end
	
		
		local in_cover = my_data.in_cover
		local best_cover = my_data.best_cover
		
		if in_cover and best_cover and in_cover[1] ~= best_cover[1] then
			in_cover = false
		end

		if action_taken then
			-- Nothing
		else
			if not in_cover then
				if my_data.cover_path then
					action_taken = CopLogicAttack._chk_request_action_walk_to_cover(data, my_data)
				elseif best_cover and (not my_data.cover_path_failed_t or data.t - my_data.cover_path_failed_t > 2) then
					CopLogicAttack._cancel_cover_pathing(data, my_data)
				
					local search_id = tostring(data.key) .. "cover"

					if data.unit:brain():search_for_path_to_cover(search_id, best_cover[1], best_cover[5]) then
						my_data.cover_path_search_id = search_id
						my_data.processing_cover_path = best_cover
					end
					
					action_taken = true
				end
				
				action_taken = action_taken or CopLogicAttack._chk_start_action_move_out_of_the_way(data, my_data)
			else
				local my_tracker = unit:movement():nav_tracker()
				local m_tracker_pos = my_tracker:position()
				
				if not action_taken and my_data.in_cover[7] then
					local path = {
						mvector3.copy(m_tracker_pos),
						mvector3.copy(my_data.in_cover[5])
					}
					
					action_taken = CopLogicAttack._chk_request_action_walk_to_cover_offset_pos(data, my_data, path)
				end
				
				action_taken = action_taken or CopLogicAttack._chk_start_action_move_out_of_the_way(data, my_data)
			end
		end
	end

	if not data.objective and (not data.path_fail_t or data.t - data.path_fail_t > 1) then
		managers.groupai:state():on_criminal_jobless(unit)

		if my_data ~= data.internal_data then
			return
		end
	end
end

function TeamAILogicAssault._on_player_slow_pos_rsrv_upd(data)
	local my_data = data.internal_data

	local objective = data.objective

	if objective and objective.type == "follow" and TeamAILogicIdle._check_should_relocate(data, my_data, objective) and not data.unit:movement():chk_action_forbidden("walk") then
		objective.in_place = nil

		TeamAILogicBase._exit(data.unit, "travel")
		
		if my_data ~= data.internal_data then
			CopLogicBase.cancel_queued_tasks(my_data)
		
			return
		end
	elseif not objective then
		if not data.path_fail_t or data.t - data.path_fail_t > 1 then
			managers.groupai:state():on_criminal_jobless(unit)

			if my_data ~= data.internal_data then
				CopLogicBase.cancel_queued_tasks(my_data)
				
				return
			end
		end
	end
end

function TeamAILogicAssault._upd_enemy_detection(data, is_synchronous)
	managers.groupai:state():on_unit_detection_updated(data.unit)

	data.t = TimerManager:game():time()
	local my_data = data.internal_data
	local max_reaction, min_reaction

	if data.cool then
		max_reaction = AIAttentionObject.REACT_SURPRISED
	else
		min_reaction = AIAttentionObject.REACT_AIM
	end	
	
	local delay = CopLogicBase._upd_attention_obj_detection(data, min_reaction, max_reaction)
	local new_attention, new_prio_slot, new_reaction = TeamAILogicIdle._get_priority_attention(data, data.detected_attention_objects, nil)
	local old_att_obj = data.attention_obj

	TeamAILogicBase._set_attention_obj(data, new_attention, new_reaction)
	
	local chk_exit_logic = true
	
	if new_attention and (new_attention.nearly_visible or new_attention.verified) and new_reaction and AIAttentionObject.REACT_COMBAT <= new_reaction and new_attention.dis < 2000 then
		data.last_engage_t = data.t
		chk_exit_logic = nil
	end

	if chk_exit_logic then
		if not data.last_engage_t or data.t - data.last_engage_t > 7 then
			TeamAILogicAssault._chk_exit_attack_logic(data, new_reaction)
		end
	end

	if my_data ~= data.internal_data then
		return
	end

	if data.objective and data.objective.type == "follow" and TeamAILogicIdle._check_should_relocate(data, my_data, data.objective) and not data.unit:movement():chk_action_forbidden("walk") then
		data.objective.in_place = nil

		if new_prio_slot and new_prio_slot > 7 then
			data.objective.called = true
		end

		TeamAILogicBase._exit(data.unit, "travel")

		return
	end

	CopLogicAttack._upd_aim(data, my_data)

	if not my_data._intimidate_t or my_data._intimidate_t + 2 < data.t and not my_data._turning_to_intimidate and data.unit:character_damage():health_ratio() > 0.5 then
		local can_turn = not data.unit:movement():chk_action_forbidden("turn") and new_prio_slot and new_prio_slot > 7
		local is_assault = managers.groupai:state():get_assault_mode()
		local civ = TeamAILogicIdle.find_civilian_to_intimidate(data.unit, can_turn and 180 or 60, is_assault and 800 or 1200)

		if civ then
			my_data._intimidate_t = data.t

			if can_turn and CopLogicAttack._chk_request_action_turn_to_enemy(data, my_data, data.unit:movement():m_pos(), civ:movement():m_pos()) then
				my_data._turning_to_intimidate = true
				my_data._primary_intimidation_target = civ
			else
				TeamAILogicIdle.intimidate_civilians(data, data.unit, true, false)
			end
		elseif LIES.settings.teamaihelpers then
			TeamAILogicIdle.intimidate_others(data, my_data, can_turn)
		end
	end

	if data.attention_obj and (not TeamAILogicAssault._mark_special_chk_t or TeamAILogicAssault._mark_special_chk_t + 0.2 < data.t) and (not TeamAILogicAssault._mark_special_t or TeamAILogicAssault._mark_special_t + 6 < data.t) and not my_data.acting and not data.unit:sound():speaking() then
		local nmy = TeamAILogicAssault.find_enemy_to_mark(data)
		TeamAILogicAssault._mark_special_chk_t = data.t

		if nmy then
			TeamAILogicAssault._mark_special_t = data.t

			TeamAILogicAssault.mark_enemy(data, data.unit, nmy, true, true)
		end
	end

	TeamAILogicAssault._chk_request_combat_chatter(data, my_data)

	if not is_synchronous then
		CopLogicBase.queue_task(my_data, my_data.detection_task_key, TeamAILogicAssault._upd_enemy_detection, data, data.t + delay)
	end
end

function TeamAILogicAssault.find_enemy_to_mark(data)
	if data.attention_obj and data.attention_obj.unit and alive(data.attention_obj.unit) and data.attention_obj.is_alive then
		if AIAttentionObject.REACT_COMBAT <= data.attention_obj.reaction and data.attention_obj.verified then
			local my_head_pos = data.unit:movement():m_head_pos()
			local my_look_vec = data.unit:movement():m_rot():y()
			local max_marking_angle = 30
			local vec = data.attention_obj.m_head_pos - my_head_pos
			local angle = vec:normalized():angle(my_look_vec)

			if angle < max_marking_angle and data.attention_obj.dis <= tweak_data.player.long_dis_interaction.highlight_range then
				if data.attention_obj.is_person then
					if data.attention_obj.char_tweak.priority_shout and (not data.attention_obj.char_tweak.priority_shout_max_dis or data.attention_obj.dis < data.attention_obj.char_tweak.priority_shout_max_dis) then
						return data.attention_obj.unit
					end
				elseif data.attention_obj.is_deployable and data.attention_obj.unit:contour() then
					local contour_ext = data.attention_obj.unit:contour()
					
					local callout = not data.unit:brain()._last_mark_shout or tweak_data.sound.criminal_sound.ai_callout_cooldown < TimerManager:game():time() - data.unit:brain()._last_mark_shout

					if callout then
						data.unit:sound():say("f44x_any", true)
						data.unit:brain()._last_mark_shout = TimerManager:game():time()
					end

					if not data.unit:movement():chk_action_forbidden("action") then
						local redir_name = "cmd_point"

						if data.unit:movement():play_redirect(redir_name) then
							managers.network:session():send_to_peers_synched("play_distance_interact_redirect", data.unit, redir_name)
						end
					end
					
					local alert_rad = 500
					local alert = {
						"vo_cbt",
						data.unit:movement():m_head_pos(),
						alert_rad,
						data.SO_access,
						data.unit
					}

					managers.groupai:state():propagate_alert(alert)
					
					contour_ext:add("mark_unit_dangerous", true)
					TeamAILogicAssault._mark_special_t = data.t
				end
			end
		end
	end
end

function TeamAILogicAssault.mark_enemy(data, criminal, to_mark, play_sound, play_action)
	if play_sound then
		local callout = not criminal:brain()._last_mark_shout or tweak_data.sound.criminal_sound.ai_callout_cooldown < TimerManager:game():time() - criminal:brain()._last_mark_shout

		if callout then
			criminal:sound():say(to_mark:base():char_tweak().priority_shout .. "x_any", true)

			criminal:brain()._last_mark_shout = TimerManager:game():time()
		end
	end

	if not data.unit:movement():chk_action_forbidden("action") then
		local redir_name = "cmd_point"

		if data.unit:movement():play_redirect(redir_name) then
			managers.network:session():send_to_peers_synched("play_distance_interact_redirect", data.unit, redir_name)
		end
	end

	to_mark:contour():add("mark_enemy", true)
end

function TeamAILogicAssault.action_complete_clbk(data, action)
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
				my_data.cover_test_step = 3
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
				data.logic._upd_aim(data, my_data)
			end
		end
	elseif action_type == "shoot" then
		my_data.shooting = nil
	elseif action_type == "turn" then
		my_data.turning = nil

		if my_data._turning_to_intimidate then
			my_data._turning_to_intimidate = nil

			TeamAILogicIdle.intimidate_civilians(data, data.unit, true, true, my_data._primary_intimidation_target)

			my_data._primary_intimidation_target = nil
		end
		
		if action:expired() then
			data.logic._upd_aim(data, my_data)
		end
		
		if data.attention_obj and (not TeamAILogicAssault._mark_special_t or TeamAILogicAssault._mark_special_t + 6 < data.t) and not my_data.acting and not data.unit:sound():speaking() then
			local nmy = TeamAILogicAssault.find_enemy_to_mark(data)
			TeamAILogicAssault._mark_special_chk_t = data.t

			if nmy then
				TeamAILogicAssault._mark_special_t = data.t

				TeamAILogicAssault.mark_enemy(data, data.unit, nmy, true, true)
			end
		end
	elseif action_type == "hurt" then
		if action:expired() then
			CopLogicAttack._upd_aim(data, my_data)
		end
	elseif action_type == "dodge" then
		CopLogicAttack._upd_aim(data, my_data)
	end
end

function TeamAILogicAssault._chk_wants_to_take_cover(data, my_data)
	if not data.attention_obj or data.attention_obj.reaction < AIAttentionObject.REACT_COMBAT then
		return
	end

	if my_data.moving_to_cover then 
		return true
	end
	
	if data.unit:character_damage()._health_ratio < 0.75 then
		return true
	end
	
	if data.attention_obj and data.attention_obj.dangerous_special then
		return true
	end
end