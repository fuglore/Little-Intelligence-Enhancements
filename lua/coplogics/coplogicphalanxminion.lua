function CopLogicPhalanxMinion.enter(data, new_logic_name, enter_params)
	CopLogicBase.enter(data, new_logic_name, enter_params)

	local my_data = {
		unit = data.unit
	}
	local is_cool = data.unit:movement():cool()
	my_data.detection = data.char_tweak.detection.combat
	local old_internal_data = data.internal_data

	if old_internal_data then
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
	end

	data.internal_data = my_data
	local key_str = tostring(data.unit:key())
	my_data.detection_task_key = "CopLogicPhalanxMinion.update" .. key_str

	CopLogicBase.queue_task(my_data, my_data.detection_task_key, CopLogicPhalanxMinion.queued_update, data, data.t)

	local objective = data.objective
	objective.attitude = "engage"

	CopLogicPhalanxMinion._chk_has_old_action(data, my_data)

	if is_cool then
		data.unit:brain():set_attention_settings({
			peaceful = true
		})
	else
		data.unit:brain():set_attention_settings({
			cbt = true
		})
	end

	my_data.weapon_range = data.char_tweak.weapon[data.unit:inventory():equipped_unit():base():weapon_tweak_data().usage].range

	CopLogicPhalanxMinion.calc_initial_phalanx_pos(data, data.m_pos, objective)
	data.unit:brain():set_update_enabled_state(false)
	CopLogicPhalanxMinion._perform_objective_action(data, my_data, objective)

	if my_data ~= data.internal_data then
		return
	end
end

function CopLogicPhalanxMinion.queued_update(data)
	local my_data = data.internal_data
	local delay = data.logic._upd_enemy_detection(data)

	if data.internal_data ~= my_data then
		CopLogicBase._report_detections(data.detected_attention_objects)

		return
	end

	local objective = data.objective

	if my_data.has_old_action then
		CopLogicPhalanxMinion._upd_stop_old_action(data, my_data, objective)
		
		if my_data.has_old_action then
			CopLogicBase.queue_task(my_data, my_data.detection_task_key, CopLogicPhalanxMinion.queued_update, data, data.t + delay, data.important and true)

			return
		end
	end

	if data.team.id == "criminal1" and (not data.objective or data.objective.type == "free") and (not data.path_fail_t or data.t - data.path_fail_t > 6) then
		managers.groupai:state():on_criminal_jobless(data.unit)

		if my_data ~= data.internal_data then
			return
		end
	end

	CopLogicPhalanxMinion._perform_objective_action(data, my_data, objective)
	CopLogicPhalanxMinion._upd_stance_and_pose(data, my_data, objective)

	if data.internal_data ~= my_data then
		CopLogicBase._report_detections(data.detected_attention_objects)

		return
	end

	delay = data.important and 0 or delay or 0.3

	CopLogicBase.queue_task(my_data, my_data.detection_task_key, CopLogicPhalanxMinion.queued_update, data, data.t + delay, data.important and true)
end

function CopLogicPhalanxMinion.is_available_for_assignment(data, objective)
	if data.objective and data.objective.type == "flee" then
		return false
	end

	if objective and objective.grp_objective and objective.grp_objective.type and objective.grp_objective.type == "create_phalanx" then
		return true
	end

	return false
end

function CopLogicPhalanxMinion._calc_pos_on_phalanx_circle(data, center_pos, angle, phalanx_minion_count)
	local radius = CopLogicPhalanxMinion._calc_phalanx_circle_radius(phalanx_minion_count)
	local result = center_pos + Vector3(radius):rotate_with(Rotation(angle))
	result = managers.navigation:clamp_position_to_field(result)
	
	local reservation = {
		radius = 30,
		position = result,
		filter = data.pos_rsrv_id
	}

	if not managers.navigation:is_pos_free(reservation) then
		result = CopLogicTravel._get_pos_on_wall(result, 90, nil, nil, nil, data.pos_rsrv_id)
	end

	return result
end

function CopLogicPhalanxMinion.calc_initial_phalanx_pos(data, own_pos, objective)
	if not objective.angle then
		local center_pos = managers.groupai:state()._phalanx_center_pos
		local phalanx_current_minion_count = managers.groupai:state():get_phalanx_minion_count()
		local total_minion_amount = tweak_data.group_ai.phalanx.minions.amount
		local fixed_angle = own_pos:angle(center_pos)
		fixed_angle = (fixed_angle + 180) % 360
		local angle_to_move_to = CopLogicPhalanxMinion._get_next_neighbour_angle(phalanx_current_minion_count - 1, total_minion_amount, fixed_angle)
		objective.angle = angle_to_move_to
		objective.pos = CopLogicPhalanxMinion._calc_pos_on_phalanx_circle(data, center_pos, angle_to_move_to, total_minion_amount)
		objective.in_place = nil
	end

	return objective.pos
end

function CopLogicPhalanxMinion._reposition_phalanx(fixed_angle)
	local phalanx_minion_count = managers.groupai:state():get_phalanx_minion_count()
	local center_pos = managers.groupai:state()._phalanx_center_pos
	fixed_angle = fixed_angle or CopLogicPhalanxMinion._get_random_angle()
	fixed_angle = math.round(fixed_angle, 2)
	local phalanx_minions = managers.groupai:state():phalanx_minions()
	local diffs_to_fixed_angle = {}
	local fixed_angle_free = true

	for unit_key, unit in pairs(phalanx_minions) do
		if unit:brain():objective() then
			local added_phalanx = false

			if not unit:brain():objective().angle then
				added_phalanx = true
			end

			local angle = unit:brain():objective().angle or fixed_angle
			local diff = CopLogicPhalanxMinion._get_diff_to_angle(fixed_angle, angle)

			if diffs_to_fixed_angle[diff] then
				if added_phalanx then
					local temp_unit = diffs_to_fixed_angle[diff]
					local temp_diff = diff + 1
					diffs_to_fixed_angle[temp_diff] = temp_unit
				else
					diff = diff + 1
				end
			end

			if diff == 0 then
				fixed_angle_free = false
			end

			diffs_to_fixed_angle[diff] = unit
		end
	end

	for diff, unit in pairs(diffs_to_fixed_angle) do
		local neighbour_num = CopLogicPhalanxMinion._i_am_nth_neighbour(diffs_to_fixed_angle, diff, fixed_angle_free)
		local angle_to_move_to = CopLogicPhalanxMinion._get_next_neighbour_angle(neighbour_num, phalanx_minion_count, fixed_angle)

		if unit:brain() and unit:brain():objective() then
			local phalanx_objective = unit:brain():objective()
			phalanx_objective.type = "phalanx"
			phalanx_objective.angle = angle_to_move_to
			phalanx_objective.pos = CopLogicPhalanxMinion._calc_pos_on_phalanx_circle(unit:brain()._logic_data, center_pos, angle_to_move_to, phalanx_minion_count)
			phalanx_objective.in_place = nil

			unit:brain():set_objective(phalanx_objective)
		end
	end
end
