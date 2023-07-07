function CopLogicPhalanxVip.exit(data, new_logic_name, enter_params)
	CopLogicBase.exit(data, new_logic_name, enter_params)

	local my_data = data.internal_data

	data.unit:brain():cancel_all_pathing_searches()
	CopLogicBase.cancel_queued_tasks(my_data)
	CopLogicBase.cancel_delayed_clbks(my_data)
	data.brain:rem_pos_rsrv("path")
	
	if not data.objective or data.objective.type ~= "phalanx" or new_logic_name == "inactive" then
		managers.groupai:state():phalanx_damage_reduction_disable()
		managers.groupai:state():force_end_assault_phase()
		
		for achievement_id, achievement_data in pairs(tweak_data.achievement.enemy_kill_achievements) do
			if achievement_data.is_vip then
				local all_pass, mutators_pass = nil
				mutators_pass = managers.mutators:check_achievements(achievement_data)
				all_pass = mutators_pass

				if all_pass then
					managers.achievment:_award_achievement(achievement_data, achievement_id)

					if Network:is_server() then
						managers.network:session():send_to_peers("sync_phalanx_vip_achievement_unlocked", achievement_id)
					end
				end
			end
		end
	end
end

function CopLogicPhalanxVip._reposition_VIP_team()
	local phalanx_minion_count = managers.groupai:state():get_phalanx_minion_count()
	local center_pos = managers.groupai:state()._phalanx_center_pos
	fixed_angle = fixed_angle or CopLogicPhalanxMinion._get_random_angle()
	fixed_angle = math.round(fixed_angle, 2)
	local phalanx_minions = managers.groupai:state():phalanx_minions()
	local diffs_to_fixed_angle = {}
	local fixed_angle_free = true
	
	if managers.groupai:state():phalanx_vip() then
		local unit = managers.groupai:state():phalanx_vip()
		
		if alive(unit) then
			if unit:brain() and unit:brain():objective() then
				local phalanx_objective = unit:brain():objective()
				phalanx_objective.type = "phalanx"
				phalanx_objective.pos = center_pos
				phalanx_objective.in_place = nil

				unit:brain():set_objective(phalanx_objective)
			end
		end
	end

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
			phalanx_objective.pos = CopLogicPhalanxMinion._calc_pos_on_phalanx_circle(center_pos, angle_to_move_to, phalanx_minion_count)
			phalanx_objective.in_place = nil

			unit:brain():set_objective(phalanx_objective)
		end
	end	
end

function CopLogicPhalanxVip.is_available_for_assignment(data, objective)
	if data.objective and data.objective.type == "flee" then
		return false
	end

	if objective and objective.grp_objective and objective.grp_objective.type and objective.grp_objective.type == "create_phalanx" then
		return true
	end

	return false
end
