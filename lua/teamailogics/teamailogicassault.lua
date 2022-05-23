TeamAILogicAssault._COVER_CHK_INTERVAL = 0.7

function TeamAILogicAssault.update(data)
	local my_data = data.internal_data
	local t = data.t
	local unit = data.unit
	local focus_enemy = data.attention_obj
	local in_cover = my_data.in_cover
	local best_cover = my_data.best_cover

	CopLogicAttack._process_pathing_results(data, my_data)

	local focus_enemy = data.attention_obj

	if not focus_enemy or focus_enemy.reaction < AIAttentionObject.REACT_AIM then
		TeamAILogicAssault._upd_enemy_detection(data, true)

		if my_data ~= data.internal_data or not data.attention_obj or data.attention_obj.reaction <= AIAttentionObject.REACT_SCARED then
			return
		end

		focus_enemy = data.attention_obj
	end
	
	if not data.unit:movement()._should_stay then
		local enemy_visible = focus_enemy.verified
		local action_taken = my_data.turning or data.unit:movement():chk_action_forbidden("walk") or my_data.moving_to_cover or my_data.walking_to_cover_shoot_pos or my_data._turning_to_intimidate
		my_data.want_to_take_cover = true
		local want_to_take_cover = my_data.want_to_take_cover
		action_taken = action_taken or CopLogicAttack._upd_pose(data, my_data)
		local move_to_cover = nil

		if action_taken then
			-- Nothing
		elseif want_to_take_cover then
			move_to_cover = true
		end

		if not my_data.processing_cover_path and not my_data.cover_path and not my_data.charge_path_search_id and not action_taken and best_cover and (not in_cover or best_cover[1] ~= in_cover[1]) then
			CopLogicAttack._cancel_cover_pathing(data, my_data)

			local search_id = tostring(unit:key()) .. "cover"

			if data.unit:brain():search_for_path_to_cover(search_id, best_cover[1], best_cover[5]) then
				my_data.cover_path_search_id = search_id
				my_data.processing_cover_path = best_cover
			end
		end

		if not action_taken and move_to_cover and my_data.cover_path then
			action_taken = CopLogicAttack._chk_request_action_walk_to_cover(data, my_data)
		end
	end

	if not data.objective and (not data.path_fail_t or data.t - data.path_fail_t > 6) then
		managers.groupai:state():on_criminal_jobless(unit)

		if my_data ~= data.internal_data then
			return
		end
	end

	if my_data.cover_chk_t < data.t then
		CopLogicAttack._update_cover(data)

		my_data.cover_chk_t = data.t + TeamAILogicAssault._COVER_CHK_INTERVAL
	end
end

function TeamAILogicAssault._upd_enemy_detection(data, is_synchronous)
	managers.groupai:state():on_unit_detection_updated(data.unit)

	data.t = TimerManager:game():time()
	local my_data = data.internal_data
	local max_reaction, min_reaction = nil

	if data.cool then
		max_reaction = AIAttentionObject.REACT_SURPRISED
	else
		min_reaction = AIAttentionObject.REACT_AIM
	end	
	
	local delay = CopLogicBase._upd_attention_obj_detection(data, min_reaction, max_reaction)
	local new_attention, new_prio_slot, new_reaction = TeamAILogicIdle._get_priority_attention(data, data.detected_attention_objects, nil)
	local old_att_obj = data.attention_obj

	TeamAILogicBase._set_attention_obj(data, new_attention, new_reaction)
	
	if not data.attention_obj or not data.attention_obj.verified_t or data.attention_obj.verified_t > 7 then
		TeamAILogicAssault._chk_exit_attack_logic(data, new_reaction)
	end

	if my_data ~= data.internal_data then
		return
	end

	if data.objective and data.objective.type == "follow" and TeamAILogicIdle._check_should_relocate(data, my_data, data.objective) and not data.unit:movement():chk_action_forbidden("walk") then
		data.objective.in_place = nil

		if new_prio_slot and new_prio_slot > 3 then
			data.objective.called = true
		end

		TeamAILogicBase._exit(data.unit, "travel")

		return
	end

	CopLogicAttack._upd_aim(data, my_data)

	if not my_data._intimidate_t or my_data._intimidate_t + 2 < data.t and not my_data._turning_to_intimidate and data.unit:character_damage():health_ratio() > 0.5 then
		local can_turn = not data.unit:movement():chk_action_forbidden("turn") and new_prio_slot > 3
		local is_assault = managers.groupai:state():get_assault_mode()
		local civ = TeamAILogicIdle.find_civilian_to_intimidate(data.unit, can_turn and 180 or 60, is_assault and 800 or 1200)

		if civ and (not is_assault or civ:anim_data().run or civ:anim_data().stand) then
			my_data._intimidate_t = data.t

			if can_turn and CopLogicAttack._chk_request_action_turn_to_enemy(data, my_data, data.unit:movement():m_pos(), civ:movement():m_pos()) then
				my_data._turning_to_intimidate = true
				my_data._primary_intimidation_target = civ
			else
				TeamAILogicIdle.intimidate_civilians(data, data.unit, true, false)
			end
		end
	end

	if (not TeamAILogicAssault._mark_special_chk_t or TeamAILogicAssault._mark_special_chk_t + 0.75 < data.t) and (not TeamAILogicAssault._mark_special_t or TeamAILogicAssault._mark_special_t + 6 < data.t) and not my_data.acting and not data.unit:sound():speaking() then
		local nmy = TeamAILogicAssault.find_enemy_to_mark(data.detected_attention_objects)
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
