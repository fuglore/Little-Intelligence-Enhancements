local tmp_vec1 = Vector3()

function TeamAILogicIdle._check_should_relocate(data, my_data, objective)
	if data.cool then
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