function CivilianLogicTravel.enter(data, new_logic_name, enter_params)
	CopLogicBase.enter(data, new_logic_name, enter_params)
	data.unit:brain():cancel_all_pathing_searches()

	local old_internal_data = data.internal_data
	local my_data = {
		unit = data.unit
	}
	data.internal_data = my_data
	local is_cool = data.unit:movement():cool()

	if is_cool then
		my_data.detection = data.char_tweak.detection.ntl
	else
		my_data.detection = data.char_tweak.detection.cbt
	end
	
	data.unit:brain():set_update_enabled_state(true)
	
	CivilianLogicEscort._get_objective_path_data(data, my_data)
	
	--if data.objective.element and data.objective.type == "act" and data.char_tweak.is_escort then
		--managers.groupai:state():print_objective(data.objective)
	--end
	
	local key_str = tostring(data.key)

	if data.is_tied then
		managers.groupai:state():on_hostage_state(true, data.key, nil, true)

		my_data.is_hostage = true
	elseif not data.char_tweak.is_escort and not data.unit:base()._tweak_table == "drunk_pilot" then
		data.unit:brain():set_update_enabled_state(false)
		
		my_data.upd_task_key = "CivilianLogicTravel_queued_update" .. key_str
	end
	
	if not data.been_outlined and data.char_tweak.outline_on_discover then
		my_data.outline_detection_task_key = "CivilianLogicIdle._upd_outline_detection" .. key_str

		CopLogicBase.queue_task(my_data, my_data.outline_detection_task_key, CivilianLogicIdle._upd_outline_detection, data, data.t + 2)
	end
	
	if not data.is_tied then
		my_data.detection_task_key = "CivilianLogicTravel_upd_detection" .. key_str

		CopLogicBase.queue_task(my_data, my_data.detection_task_key, CivilianLogicIdle._upd_detection, data, data.t)
	end

	my_data.advance_path_search_id = "CivilianLogicTravel_detailed" .. tostring(data.key)
	my_data.coarse_path_search_id = "CivilianLogicTravel_coarse" .. tostring(data.key)

	if not data.unit:movement():cool() then
		my_data.registered_as_fleeing = true

		managers.groupai:state():register_fleeing_civilian(data.key, data.unit)
	end

	if data.objective and data.objective.stance then
		data.unit:movement():set_stance(data.objective.stance)
	end

	CivilianLogicTravel._chk_has_old_action(data, my_data)

	local objective = data.objective
	local path_data = objective.path_data

	if objective.path_style == "warp" then
		my_data.warp_pos = objective.pos
	end

	local attention_settings = nil

	if is_cool then
		attention_settings = {
			"civ_all_peaceful"
		}
	else
		attention_settings = {
			"civ_enemy_cbt",
			"civ_civ_cbt",
			"civ_murderer_cbt"
		}
	end

	data.unit:brain():set_attention_settings(attention_settings)

	my_data.state_enter_t = TimerManager:game():time()
	
	if my_data.upd_task_key then
		CivilianLogicTravel.queued_update(data, my_data)
	end
end

function CivilianLogicTravel.action_complete_clbk(data, action)
	local my_data = data.internal_data
	local action_type = action:type()

	if action_type == "walk" then
		if action:expired() and not my_data.starting_advance_action and my_data.coarse_path_index and not my_data.has_old_action and not my_data.old_action_advancing and my_data.advancing then
			if my_data.going_to_index then
				my_data.coarse_path_index = my_data.going_to_index
			else
				my_data.coarse_path_index = my_data.coarse_path_index + 1
			end

			if my_data.coarse_path_index > #my_data.coarse_path then
				my_data.coarse_path_index = my_data.coarse_path_index - 1
			end
		end
	
		my_data.old_action_advancing = nil
		my_data.advancing = nil
	elseif action_type == "act" and my_data.getting_up then
		my_data.getting_up = nil
	end
end

function CivilianLogicTravel.update(data)
	local my_data = data.internal_data
	local unit = data.unit
	local objective = data.objective
	local t = data.t

	if my_data.has_old_action or my_data.old_action_advancing then
		CivilianLogicTravel._upd_stop_old_action(data, my_data)
		
		if my_data.has_old_action or my_data.old_action_advancing then
			return
		end
	end
	
	if my_data.is_hostage then
		CivilianLogicTravel._stop_for_criminal(data, my_data)
		
		if data.internal_data ~= my_data then
			return
		end
		
		CivilianLogicTravel._check_for_scare(data, my_data)
		
		if data.internal_data ~= my_data then
			return
		end
	end
	
	if my_data.warp_pos then
		local action_desc = {
			body_part = 1,
			type = "warp",
			position = mvector3.copy(objective.pos),
			rotation = objective.rot
		}

		if unit:movement():action_request(action_desc) then
			CivilianLogicTravel._on_destination_reached(data)
		end
	elseif my_data.processing_advance_path or my_data.processing_coarse_path then
		CivilianLogicEscort._upd_pathing(data, my_data)
		
		if data.internal_data ~= my_data then
			return
		end

		if not my_data.advance_path and my_data.coarse_path then
			local coarse_path = my_data.coarse_path
			local cur_index = my_data.coarse_path_index
			local total_nav_points = #coarse_path

			if cur_index >= total_nav_points then
				objective.in_place = true

				if objective.type ~= "escort" and objective.type ~= "act" and objective.type ~= "follow" and not objective.action_duration then
					data.objective_complete_clbk(unit, objective)
				else
					CivilianLogicTravel.on_new_objective(data)
				end

				return
			else
				data.brain:rem_pos_rsrv("path")

				local to_pos = nil

				if cur_index == total_nav_points - 1 then
					to_pos = CivilianLogicTravel._determine_exact_destination(data, objective)
				else
					to_pos = coarse_path[cur_index + 1][2]
				end

				my_data.processing_advance_path = true

				unit:brain():search_for_path(my_data.advance_path_search_id, to_pos)
			end
		elseif my_data.advance_path then
			CopLogicAttack._correct_path_start_pos(data, my_data.advance_path)

			if my_data.is_hostage then
				my_data.advance_path = LIES:_optimize_path(my_data.advance_path, data)
			end

			local end_rot = nil

			if my_data.coarse_path_index == #my_data.coarse_path - 1 then
				end_rot = objective and objective.rot
			end

			local haste = objective and objective.haste or "walk"
			local new_action_data = {
				type = "walk",
				body_part = 2,
				nav_path = my_data.advance_path,
				path_simplified = my_data.path_is_precise,
				variant = haste,
				end_rot = end_rot
			}
			my_data.starting_advance_action = true
			my_data.advancing = data.unit:brain():action_request(new_action_data)
			my_data.starting_advance_action = false

			if my_data.advancing then
				my_data.advance_path = nil

				data.brain:rem_pos_rsrv("path")
			end
		end
	elseif my_data.advancing then
		--a
	elseif my_data.advance_path then
		CopLogicAttack._correct_path_start_pos(data, my_data.advance_path)

		if my_data.is_hostage then
			my_data.advance_path = LIES:_optimize_path(my_data.advance_path, data)
		end

		local end_rot = nil

		if my_data.coarse_path_index == #my_data.coarse_path - 1 then
			end_rot = objective and objective.rot
		end

		local haste = objective and objective.haste or "walk"
		local new_action_data = {
			type = "walk",
			body_part = 2,
			nav_path = my_data.advance_path,
			path_simplified = my_data.path_is_precise,
			variant = haste,
			end_rot = end_rot
		}
		my_data.starting_advance_action = true
		my_data.advancing = data.unit:brain():action_request(new_action_data)
		my_data.starting_advance_action = false

		if my_data.advancing then
			my_data.advance_path = nil

			data.brain:rem_pos_rsrv("path")
		end
	elseif objective then
		if my_data.coarse_path then
			local coarse_path = my_data.coarse_path
			local cur_index = my_data.coarse_path_index
			local total_nav_points = #coarse_path

			if cur_index >= total_nav_points then
				objective.in_place = true

				if objective.type ~= "escort" and objective.type ~= "act" and objective.type ~= "follow" and not objective.action_duration then
					data.objective_complete_clbk(unit, objective)
				else
					CivilianLogicTravel.on_new_objective(data)
				end

				return
			else
				data.brain:rem_pos_rsrv("path")

				local to_pos = nil

				if cur_index == total_nav_points - 1 then
					to_pos = CivilianLogicTravel._determine_exact_destination(data, objective)
				else
					to_pos = coarse_path[cur_index + 1][2]
				end

				my_data.processing_advance_path = true

				unit:brain():search_for_path(my_data.advance_path_search_id, to_pos)
			end
		else
			local nav_seg = nil

			if objective.follow_unit then
				nav_seg = objective.follow_unit:movement():nav_tracker():nav_segment()
			else
				nav_seg = objective.nav_seg
			end

			if unit:brain():search_for_coarse_path(my_data.coarse_path_search_id, nav_seg) then
				my_data.processing_coarse_path = true
			end
		end
	else
		CopLogicBase._exit(data.unit, "idle")
	end
end

function CivilianLogicTravel.queued_update(data)
	local my_data = data.internal_data
	
	CivilianLogicTravel.update(data)
	
	if data.internal_data ~= my_data then
		return
	end
	
	CopLogicBase.queue_task(my_data, my_data.upd_task_key, CivilianLogicTravel.queued_update, data, data.t + 1)
end

function CivilianLogicTravel._check_for_scare(data, my_data)
	local objective = data.objective

	if not objective or objective.type ~= "follow" or data.unit:movement():chk_action_forbidden("walk") or data.unit:anim_data().act_idle then
		return
	end
	
	if not objective.follow_unit or not alive(objective.follow_unit) then
		return
	end
	
	local follow_unit = objective.follow_unit
	
	local follow_unit_far = true
	local max_dis_sq = 1000000

	if mvector3.distance_sq(follow_unit:movement():nav_tracker():position(), data.m_pos) < max_dis_sq then
		follow_unit_far = nil
	end
	
	if follow_unit_far then
		managers.groupai:state():on_civilian_objective_failed(data.unit, data.objective)
	
		return
	end
	
	local player_team_id = tweak_data.levels:get_default_team_ID("player")
	local enemies_close = nil
	local min_dis_sq = 250
	min_dis_sq = min_dis_sq * min_dis_sq

	for c_key, c_data in pairs(managers.enemy:all_enemies()) do
		if not c_data.unit:anim_data().surrender and c_data.unit:brain()._current_logic_name ~= "trade" and not not c_data.unit:movement():team().foes[player_team_id] and mvector3.distance_sq(c_data.m_pos, data.m_pos) < min_dis_sq and math.abs(c_data.m_pos.z - data.m_pos.z) < 250 then
			if not data.unit:raycast("ray", m_head_pos, c_data.unit:movement():m_head_pos(), "slot_mask", data.visibility_slotmask, "ray_type", "ai_vision", "ignore_unit", c_data.unit, "report") then
				enemies_close = true

				break
			end
		end
	end
	
	if enemies_close then
		managers.groupai:state():on_civilian_objective_failed(data.unit, data.objective)
	
		return
	end
end

function CivilianLogicTravel._stop_for_criminal(data, my_data)
	local objective = data.objective

	if not objective or objective.type ~= "follow" or data.unit:movement():chk_action_forbidden("walk") or data.unit:anim_data().act_idle then
		return
	end
	
	if not objective.follow_unit or not alive(objective.follow_unit) then
		return
	end
	
	if not my_data.coarse_path then
		return
	end
	
	local follow_unit = objective.follow_unit
	local my_nav_seg_id = data.unit:movement():nav_tracker():nav_segment()
	local my_areas = managers.groupai:state():get_areas_from_nav_seg_id(my_nav_seg_id)
	local follow_unit_nav_seg_id = follow_unit:movement():nav_tracker():nav_segment()
	
	if mvector3.distance_sq(data.m_pos, follow_unit:movement():nav_tracker():field_position()) < 3600 then
		objective.in_place = true

		data.logic.on_new_objective(data)
			
		return
	else
		local obj_nav_seg = my_data.coarse_path[#my_data.coarse_path][1]
		local obj_area = managers.groupai:state():get_area_from_nav_seg_id(obj_nav_seg)
		local follow_unit_area = managers.groupai:state():get_area_from_nav_seg_id(follow_unit_nav_seg_id)
		
		if obj_area and follow_unit_area then
			if mvector3.distance_sq(obj_area.pos, follow_unit_area.pos) > 10000 or math.abs(obj_area.pos.z - follow_unit:movement():nav_tracker():field_position().z) > 250 then
				objective.in_place = nil
				
				data.logic.on_new_objective(data)
		
				return
			end
		end
	end
end

function CivilianLogicTravel._determine_exact_destination(data, objective)
	if objective.pos then
		return objective.pos
	elseif objective.type == "follow" then
		local to_pos
		
		if not data.tied then
			local follow_pos, follow_nav_seg = nil
			follow_pos = objective.follow_unit:movement():nav_tracker():field_position()
			follow_nav_seg = objective.follow_unit:movement():nav_tracker():nav_segment()
			local distance = objective.distance and math.lerp(objective.distance * 0.5, objective.distance * 0.9, math.random()) or 700
			to_pos = CopLogicTravel._get_pos_on_wall(follow_pos, distance)
		else
			to_pos = mvector3.copy(objective.follow_unit:movement():nav_tracker():field_position())
		end
			
		return to_pos
	else
		return CopLogicTravel._get_pos_on_wall(managers.navigation._nav_segments[objective.nav_seg].pos, 700)
	end
end