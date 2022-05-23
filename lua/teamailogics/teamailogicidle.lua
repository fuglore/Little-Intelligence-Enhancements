local tmp_vec1 = Vector3()

function TeamAILogicIdle._check_should_relocate(data, my_data, objective)
	if data.cool or data.unit:movement()._should_stay then
		return
	end

	local follow_unit = objective.follow_unit

	local max_allowed_dis_xy = 700
	local max_allowed_dis_z = 250

	mvector3.set(tmp_vec1, follow_unit:movement():m_pos())
	mvector3.subtract(tmp_vec1, data.m_pos)

	local too_far = nil

	if max_allowed_dis_z < math.abs(mvector3.z(tmp_vec1)) then
		too_far = true
	else
		mvector3.set_z(tmp_vec1, 0)

		if max_allowed_dis_xy < mvector3.length(tmp_vec1) then
			too_far = true
		end
	end

	if too_far then
		return true
	end
end

function TeamAILogicIdle.on_new_objective(data, old_objective)
	local new_objective = data.objective

	TeamAILogicBase.on_new_objective(data, old_objective)

	local my_data = data.internal_data

	if not my_data.exiting then
		if new_objective and not data.unit:movement()._should_stay then
			if (new_objective.nav_seg or new_objective.follow_unit) and not new_objective.in_place then
				if data._ignore_first_travel_order then
					data._ignore_first_travel_order = nil
				else
					CopLogicBase._exit(data.unit, "travel")
				end
			else
				CopLogicBase._exit(data.unit, "idle")
			end
		else
			CopLogicBase._exit(data.unit, "idle")
		end
	else
		debug_pause("[TeamAILogicIdle.on_new_objective] Already exiting", data.name, data.unit, old_objective and inspect(old_objective), new_objective and inspect(new_objective))
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