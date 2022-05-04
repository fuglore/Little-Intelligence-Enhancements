function CopLogicIdle.queued_update(data)
	local my_data = data.internal_data
	local delay = data.logic._upd_enemy_detection(data)

	if data.internal_data ~= my_data then
		CopLogicBase._report_detections(data.detected_attention_objects)

		return
	end

	local objective = data.objective

	if my_data.has_old_action then
		CopLogicIdle._upd_stop_old_action(data, my_data, objective)
		CopLogicBase.queue_task(my_data, my_data.detection_task_key, CopLogicIdle.queued_update, data, data.t + delay, data.important and true)

		return
	end

	if data.is_converted or data.check_crim_jobless or data.team.id == "criminal1" then
		if not data.objective or data.objective.type == "free" then
			if not data.path_fail_t or data.t - data.path_fail_t > 6 then
				managers.groupai:state():on_criminal_jobless(data.unit)

				if my_data ~= data.internal_data then
					return
				end
			end
		end
	end

	if CopLogicIdle._chk_exit_non_walkable_area(data) then
		return
	end

	if CopLogicIdle._chk_relocate(data) then
		return
	end

	CopLogicIdle._perform_objective_action(data, my_data, objective)
	CopLogicIdle._upd_stance_and_pose(data, my_data, objective)
	CopLogicIdle._upd_pathing(data, my_data)
	CopLogicIdle._upd_scan(data, my_data)

	if data.cool then
		CopLogicIdle.upd_suspicion_decay(data)
	end

	if data.internal_data ~= my_data then
		CopLogicBase._report_detections(data.detected_attention_objects)

		return
	end

	delay = data.important and 0 or delay or 0.3

	CopLogicBase.queue_task(my_data, my_data.detection_task_key, CopLogicIdle.queued_update, data, data.t + delay, data.important and true)
end

function CopLogicIdle.on_new_objective(data, old_objective)
	local new_objective = data.objective

	CopLogicBase.on_new_objective(data, old_objective)

	local my_data = data.internal_data

	if new_objective then
		local objective_type = new_objective.type

		if CopLogicIdle._chk_objective_needs_travel(data, new_objective) then
			CopLogicBase._exit(data.unit, "travel")
		elseif objective_type == "guard" then
			CopLogicBase._exit(data.unit, "guard")
		elseif objective_type == "security" then
			CopLogicBase._exit(data.unit, "idle")
		elseif objective_type == "sniper" then
			CopLogicBase._exit(data.unit, "sniper")
		elseif objective_type == "phalanx" then
			CopLogicBase._exit(data.unit, "phalanx")
		elseif objective_type == "surrender" then
			CopLogicBase._exit(data.unit, "intimidated", new_objective.params)
		elseif objective_type == "free" and my_data.exiting then
			-- Nothing
		elseif new_objective.action or not data.attention_obj or AIAttentionObject.REACT_AIM > data.attention_obj.reaction then
			CopLogicBase._exit(data.unit, "idle")
		elseif data.name ~= "attack" then
			CopLogicBase._exit(data.unit, "attack")
		else
			my_data.attitude = new_objective.attitude or my_data.attitude
		end
	elseif not my_data.exiting then
		if data.attention_obj and AIAttentionObject.REACT_AIM <= data.attention_obj.reaction then
			CopLogicBase._exit(data.unit, "attack")
		else
			CopLogicBase._exit(data.unit, "idle")
		end
	end

	if new_objective and new_objective.stance then
		if new_objective.stance == "ntl" then
			data.unit:movement():set_cool(true)
		else
			data.unit:movement():set_cool(false)
		end
	end

	if old_objective and old_objective.fail_clbk then
		old_objective.fail_clbk(data.unit)
	end
end

function CopLogicIdle._chk_relocate(data)
	if not data.objective then
		return
	end

	if data.objective and data.objective.type == "follow" then
		if data.is_converted or data.unit:in_slot(16) or data.team.id == tweak_data.levels:get_default_team_ID("player") or data.team.friends[tweak_data.levels:get_default_team_ID("player")] then
			if TeamAILogicIdle._check_should_relocate(data, data.internal_data, data.objective) then
				data.objective.in_place = nil

				data.logic._exit(data.unit, "travel")

				return true
			end

			return
		end

		if data.is_tied and data.objective.lose_track_dis and data.objective.lose_track_dis * data.objective.lose_track_dis < mvector3.distance_sq(data.m_pos, data.objective.follow_unit:movement():m_pos()) then
			data.brain:set_objective(nil)

			return true
		end

		local relocate = nil
		local follow_unit = data.objective.follow_unit
		local advance_pos = follow_unit:brain() and follow_unit:brain():is_advancing()
		local follow_unit_pos = advance_pos or follow_unit:movement():m_pos()

		if data.objective.relocated_to and mvector3.distance_sq(data.objective.relocated_to, follow_unit_pos) < 100 then
			return
		end

		if data.objective.distance and data.objective.distance < mvector3.distance(data.m_pos, follow_unit_pos) then
			relocate = true
		end

		if not relocate then
			local ray_params = {
				tracker_from = data.unit:movement():nav_tracker(),
				pos_to = follow_unit_pos
			}
			local ray_res = managers.navigation:raycast(ray_params)

			if ray_res then
				relocate = true
			end
		end

		if relocate then
			data.objective.in_place = nil
			data.objective.nav_seg = follow_unit:movement():nav_tracker():nav_segment()
			data.objective.relocated_to = mvector3.copy(follow_unit_pos)

			data.logic._exit(data.unit, "travel")

			return true
		end
	end
end