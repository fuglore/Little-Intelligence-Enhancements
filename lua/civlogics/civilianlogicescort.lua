if not Iter then

function CivilianLogicEscort._get_objective_path_data(data, my_data)
	local objective = data.objective
	local path_data = objective.path_data
	local path_style = objective.path_style

	if path_data then
		if path_style == "precise" then
			local path = {
				mvector3.copy(data.m_pos)
			}

			for _, point in ipairs(path_data.points) do
				table.insert(path, point.position)
			end
			
			if LIES:_path_is_straight_line(data.m_pos, path[#path], data) then
				path = {
					path[1],
					path[#path]
				}
			else
				path = LIES:_optimize_path(path, data)
			end

			my_data.advance_path = path
			my_data.coarse_path_index = 1
			local start_seg = data.unit:movement():nav_tracker():nav_segment()
			local end_pos = mvector3.copy(path[#path])
			local end_seg = managers.navigation:get_nav_seg_from_pos(end_pos)
			my_data.coarse_path = {
				{
					start_seg
				},
				{
					end_seg,
					end_pos
				}
			}
		elseif path_style == "coarse" then
			local t_ins = table.insert
			my_data.coarse_path_index = 1
			local m_tracker = data.unit:movement():nav_tracker()
			local start_seg = m_tracker:nav_segment()
			my_data.coarse_path = {
				{
					start_seg
				}
			}
			local points = path_data.points
			local i_point = 1
			
			local target_pos = points[#path_data.points].position
			local target_seg = managers.navigation:get_nav_seg_from_pos(target_pos)
			
			local alt_coarse_params = {
				from_tracker = m_tracker,
				to_pos = target_pos,
				access = {
					"walk"
				},
				id = "CivilianLogicEscort.alt_coarse_search" .. tostring(data.key),
				access_pos = data.char_tweak.access
			}
			
			local alt_coarse = managers.navigation:search_coarse(alt_coarse_params)

			if alt_coarse and #alt_coarse <= #points then
				my_data.coarse_path = alt_coarse
			else
				local coarse_path = my_data.coarse_path
				
				while i_point <= #path_data.points do
					local next_pos = points[i_point].position
					local next_seg = managers.navigation:get_nav_seg_from_pos(next_pos)

					t_ins(coarse_path, {
						next_seg,
						mvector3.copy(next_pos)
					})

					i_point = i_point + 1
				end
			end
			
		elseif path_style == "destination" then
			my_data.coarse_path_index = 1
			local start_seg = data.unit:movement():nav_tracker():nav_segment()
			local end_pos = mvector3.copy(path_data.points[#path_data.points].position)
			local end_seg = managers.navigation:get_nav_seg_from_pos(end_pos)
			my_data.coarse_path = {
				{
					start_seg
				},
				{
					end_seg,
					end_pos
				}
			}
		end
	end
end

function CivilianLogicEscort.action_complete_clbk(data, action)
	local my_data = data.internal_data
	local action_type = action:type()

	if action_type == "walk" then
		my_data.advancing = nil

		if action:expired() then
			my_data.coarse_path_index = my_data.coarse_path_index + 1
		end
	elseif action_type == "act" and my_data.getting_up then
		my_data.getting_up = nil
	end
end

end