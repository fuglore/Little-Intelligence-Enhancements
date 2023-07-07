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
	
	local key_str = tostring(data.key)

	if data.is_tied then
		managers.groupai:state():on_hostage_state(true, data.key, nil, true)

		my_data.is_hostage = true
	else
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

function CivilianLogicTravel.update(data)
	local my_data = data.internal_data
	local unit = data.unit
	local objective = data.objective
	local t = data.t

	if my_data.has_old_action then
		CivilianLogicTravel._upd_stop_old_action(data, my_data)
		
		if my_data.has_old_action then
			return
		end
	end
	
	if not my_data.detection_task_key and data.tied then
		CivilianLogicTravel._stop_for_criminal(data, my_data)
		
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
		local was_processing_advance = my_data.processing_advance_path and true
		CivilianLogicEscort._upd_pathing(data, my_data)
		
		if was_processing_advance and my_data.advance_path then
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
		elseif my_data.coarse_path then
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
		end
	elseif my_data.advancing then
		-- Nothing
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
		if not my_data.coarse_path and my_data.is_hostage then
			local nav_seg = nil

			if objective.follow_unit then
				nav_seg = objective.follow_unit:movement():nav_tracker():nav_segment()
			else
				nav_seg = objective.nav_seg
			end
		
			my_data.coarse_path = unit:brain():search_for_coarse_immediate(my_data.coarse_path_search_id, nav_seg)
			
			if my_data.coarse_path then
				my_data.coarse_path_index = 1
			end
		end
	
		if my_data.coarse_path then
			local coarse_path = my_data.coarse_path
			local cur_index = my_data.coarse_path_index
			local total_nav_points = #coarse_path

			if cur_index >= total_nav_points then
				if my_data.is_hostage then
					if CopLogicIdle._chk_relocate(data) then
						return
					end
					
					if data.objective.relocated_to and mvector3.distance_sq(data.m_pos, data.objective.relocated_to) > 3600 then
						my_data.coarse_path = nil
						my_data.coarse_path_index = nil
						
						return
					end
				end
				
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
		
		return
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

function CivilianLogicTravel._stop_for_criminal(data, my_data)
	local objective = data.objective

	if not objective or objective.type ~= "follow" or data.unit:movement():chk_action_forbidden("walk") or data.unit:anim_data().act_idle then
		return
	end

	if not my_data.coarse_path_index or my_data.coarse_path and #my_data.coarse_path - 1 == 1 then
		return
	end
	
	if not objective.follow_unit or not alive(objective.follow_unit) then
		return
	end
	
	local follow_unit = objective.follow_unit
	local my_nav_seg_id = data.unit:movement():nav_tracker():nav_segment()
	local my_areas = managers.groupai:state():get_areas_from_nav_seg_id(my_nav_seg_id)
	local follow_unit_nav_seg_id = follow_unit:movement():nav_tracker():nav_segment()
	local should_try_stop = nil
	
	if my_nav_seg_id == follow_unit_nav_seg_id then
		if mvector3.distance_sq(data.m_pos, follow_unit:movement():nav_tracker():field_position()) < 3600 then
			objective.in_place = true

			data.logic.on_new_objective(data)
			
			return
		end
	
		should_try_stop = true
	else
		for _, area in ipairs(my_areas) do
			if area.nav_segs[follow_unit_nav_seg_id] then
				should_try_stop = true
				
				break
			end
		end
	end
	
	if not should_try_stop then
		local obj_nav_seg = my_data.coarse_path[#my_data.coarse_path][1]
		local obj_areas = managers.groupai:state():get_areas_from_nav_seg_id(obj_nav_seg)
		local follow_unit_areas = managers.groupai:state():get_areas_from_nav_seg_id(follow_unit_nav_seg_id)
		local dontcheckdis, dis
		
		for _, area in ipairs(obj_areas) do
			if area.nav_segs[follow_unit_nav_seg_id] then
				dontcheckdis = true
				
				break
			end
		end
		
		if not dontcheckdis and #obj_areas > 0 and #follow_unit_areas > 0 then
			if mvector3.distance_sq(obj_areas[1].pos, follow_unit_areas[1].pos) > 10000 or math.abs(obj_areas[1].pos.z - follow_unit:movement():nav_tracker():field_position().z) > 250 then
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