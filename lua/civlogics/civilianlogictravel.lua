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