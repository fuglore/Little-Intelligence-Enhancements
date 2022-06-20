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

function CopLogicPhalanxMinion._calc_pos_on_phalanx_circle(center_pos, angle, phalanx_minion_count)
	local radius = CopLogicPhalanxMinion._calc_phalanx_circle_radius(phalanx_minion_count)
	local result = center_pos + Vector3(radius):rotate_with(Rotation(angle))
	local pos_tracker = managers.navigation:create_nav_tracker(result)
	result = mvector3.copy(pos_tracker:field_position())
	managers.navigation:destroy_nav_tracker(pos_tracker)

	return result
end