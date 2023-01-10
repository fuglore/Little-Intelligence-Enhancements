if not Iter then

function CivilianLogicEscort.enter(data, new_logic_name, enter_params)
	CopLogicBase.enter(data, new_logic_name, enter_params)
	data.unit:brain():cancel_all_pathing_searches()

	local old_internal_data = data.internal_data
	local my_data = {
		unit = data.unit
	}

	data.unit:brain():set_update_enabled_state(true)

	if data.char_tweak.escort_idle_talk then
		my_data._say_random_t = Application:time() + 45
	end

	CivilianLogicEscort._get_objective_path_data(data, my_data)
	
	managers.groupai:state():_register_escort(data.unit)

	data.internal_data = my_data

	data.unit:contour():add("highlight")
	data.unit:movement():set_cool(false, "escort")
	data.unit:movement():set_stance(data.is_tied and "cbt" or "hos")

	my_data.advance_path_search_id = "CivilianLogicEscort_detailed" .. tostring(data.key)
	my_data.coarse_path_search_id = "CivilianLogicEscort_coarse" .. tostring(data.key)

	if data.unit:anim_data().tied then
		local action_data = {
			clamp_to_graph = true,
			variant = "panic",
			body_part = 1,
			type = "act"
		}

		data.unit:brain():action_request(action_data)
	end

	if not data.been_outlined and data.char_tweak.outline_on_discover then
		my_data.outline_detection_task_key = "CivilianLogicIdle._upd_outline_detection" .. tostring(data.key)

		CopLogicBase.queue_task(my_data, my_data.outline_detection_task_key, CivilianLogicIdle._upd_outline_detection, data, data.t)
	end

	local attention_settings = {
		"civ_enemy_cbt",
		"civ_civ_cbt"
	}

	data.unit:brain():set_attention_settings(attention_settings)
end

function CivilianLogicEscort.exit(data, new_logic_name, enter_params)
	CopLogicBase.exit(data, new_logic_name, enter_params)
	managers.groupai:state():_unregister_escort(data.key)

	local my_data = data.internal_data

	data.unit:brain():cancel_all_pathing_searches()
	CopLogicBase.cancel_queued_tasks(my_data)
	data.unit:contour():remove("highlight")

	if new_logic_name ~= "inactive" then
		data.unit:brain():set_update_enabled_state(true)
	end
end

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