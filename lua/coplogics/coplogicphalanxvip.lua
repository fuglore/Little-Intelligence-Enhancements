function CopLogicPhalanxVip.exit(data, new_logic_name, enter_params)
	CopLogicBase.exit(data, new_logic_name, enter_params)

	local my_data = data.internal_data

	data.unit:brain():cancel_all_pathing_searches()
	CopLogicBase.cancel_queued_tasks(my_data)
	CopLogicBase.cancel_delayed_clbks(my_data)
	data.brain:rem_pos_rsrv("path")
	
	if data.objective and data.objective.type ~= "phalanx" then
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

function CopLogicPhalanxVip.is_available_for_assignment(data, objective)
	if data.objective and data.objective.type == "flee" then
		return false
	end

	if objective and objective.grp_objective and objective.grp_objective.type and objective.grp_objective.type == "create_phalanx" then
		return true
	end

	return false
end
