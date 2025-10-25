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
			to_pos = CopLogicTravel._get_pos_on_wall(follow_pos, distance, nil, nil, nil, data.pos_rsrv_id)
		else
			to_pos = mvector3.copy(objective.follow_unit:movement():nav_tracker():field_position())
		end
			
		return to_pos
	else
		return CopLogicTravel._get_pos_on_wall(managers.navigation._nav_segments[objective.nav_seg].pos, 700, nil, nil, nil, data.pos_rsrv_id)
	end
end

function CivilianLogicTravel.update(data)
	local my_data = data.internal_data
	local unit = data.unit
	local objective = data.objective
	local t = data.t
	
	if not my_data.last_upd_t then
		my_data.last_upd_t = -1
	end
	
	if not data.char_tweak.is_escort and not data.unit:base()._tweak_table == "drunk_pilot" then
		if not data.tied and t - my_data.last_upd_t < 1 or t - my_data.last_upd_t < 0.5 then
			return
		end
	end

	my_data.last_upd_t = t

	if my_data.has_old_action then
		CivilianLogicTravel._upd_stop_old_action(data, my_data)
	elseif my_data.warp_pos then
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
	elseif my_data.advancing then
		-- Nothing
	elseif my_data.advance_path then
		CopLogicAttack._correct_path_start_pos(data, my_data.advance_path)

		local to_index = my_data.going_to_index or my_data.coarse_path_index + 1
		local end_rot = nil

		if to_index >= #my_data.coarse_path then
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

				if cur_index >= total_nav_points - 1 then
					to_pos = CivilianLogicTravel._determine_exact_destination(data, objective)
				else
					to_pos = coarse_path[#coarse_path][2]
				end
				
				my_data.going_to_index = total_nav_points
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
		my_data.going_to_index = nil
	elseif action_type == "act" and my_data.getting_up then
		my_data.getting_up = nil
	end
end

function CivilianLogicTravel._check_should_relocate(data, my_data, objective)
	if not objective or not objective.follow_unit then
		return
	end
	
	local m_pos = objective.relocate_pos or data.m_pos
	local follow_unit = objective.follow_unit
	local follow_pos = follow_unit:movement().m_newest_pos and follow_unit:movement():m_newest_pos() or follow_unit:movement():m_pos()
	local max_allowed_dis = 250
	local z_diff = math.abs(m_pos.z - follow_pos.z)
	
	if z_diff > 250 then
		objective.relocate_pos = mvector3.copy(follow_pos)
		return true
	else
		max_allowed_dis = math.lerp(max_allowed_dis, 0, z_diff / 250)
		
		if mvector3.distance(m_pos, follow_pos) > max_allowed_dis then
			objective.relocate_pos = mvector3.copy(follow_pos)
			return true
		end
	end
end