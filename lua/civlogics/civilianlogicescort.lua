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

			my_data.advance_path = path
			my_data.coarse_path_index = 1
			local start_seg = data.unit:movement():nav_tracker():nav_segment()
			local end_pos = mvector3.copy(path[#path])
			local end_seg = managers.navigation:get_nav_seg_from_pos(end_pos)
			my_data.path_is_precise = true
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
			local start_seg = data.unit:movement():nav_tracker():nav_segment()
			my_data.coarse_path = {
				{
					start_seg
				}
			}
			local coarse_path = my_data.coarse_path
			local points = path_data.points
			local i_point = 1

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

function CivilianLogicEscort._begin_advance_action(data, my_data)
	CopLogicAttack._correct_path_start_pos(data, my_data.advance_path)

	local objective = data.objective
	local haste = objective and objective.haste or "run"
	local new_action_data = {
		type = "walk",
		body_part = 2,
		nav_path = my_data.advance_path,
		variant = haste
	}
	local going_to_index = my_data.coarse_path_index + 1
	
	if my_data.coarse_path and going_to_index == #my_data.coarse_path then
		new_action_data.end_rot = objective.rot
	end
	
	my_data.advancing = data.unit:brain():action_request(new_action_data)

	if my_data.advancing then
		data.brain:rem_pos_rsrv("path")

		my_data.advance_path = nil
	else
		debug_pause("[CivilianLogicEscort._begin_advance_action] failed to start")
	end
end

function CivilianLogicEscort.too_scared_to_move(data)
	local my_data = data.internal_data
	local m_com = data.unit:movement():m_com()
	local m_head_pos = data.unit:movement():m_head_pos()
	
	if data.unit:raycast("ray", m_com, m_head_pos, "slot_mask", data.visibility_slotmask, "ray_type", "ai_vision", "report") then
		my_data.commanded_to_move = "temp"
		
		return
	end

	local nobody_close = true
	local min_dis_sq = 1000000

	for c_key, c_data in pairs(managers.groupai:state():all_char_criminals()) do
		if mvector3.distance_sq(c_data.m_pos, data.m_pos) < min_dis_sq then
			nobody_close = nil

			break
		end
	end

	if nobody_close then
		return "abandoned"
	end

	local player_team_id = tweak_data.levels:get_default_team_ID("player")
	local nobody_close = true
	local min_dis_sq = data.char_tweak.escort_scared_dist
	min_dis_sq = min_dis_sq * min_dis_sq

	for c_key, c_data in pairs(managers.enemy:all_enemies()) do
		if not c_data.unit:anim_data().surrender and c_data.unit:brain()._current_logic_name ~= "trade" and not not c_data.unit:movement():team().foes[player_team_id] and mvector3.distance_sq(c_data.m_pos, data.m_pos) < min_dis_sq and math.abs(c_data.m_pos.z - data.m_pos.z) < 250 then
			
			if not data.unit:raycast("ray", m_head_pos, c_data.unit:movement():m_head_pos(), "slot_mask", data.visibility_slotmask, "ray_type", "ai_vision", "ignore_unit", c_data.unit, "report") then
				nobody_close = nil

				break
			end
		end
	end

	if not nobody_close then
		return "pigs"
	end
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


end