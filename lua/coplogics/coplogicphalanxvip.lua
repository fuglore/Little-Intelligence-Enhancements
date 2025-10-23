function CopLogicPhalanxVip.enter(data, new_logic_name, enter_params)
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
	my_data.detection_task_key = "CopLogicPhalanxVip.update" .. key_str

	CopLogicBase.queue_task(my_data, my_data.detection_task_key, CopLogicPhalanxVip.queued_update, data, data.t)

	local objective = data.objective

	CopLogicPhalanxVip._chk_has_old_action(data, my_data)

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

	CopLogicPhalanxVip.calc_initial_phalanx_pos(data.m_pos, objective)
	data.unit:brain():set_update_enabled_state(false)
	CopLogicPhalanxVip._perform_objective_action(data, my_data, objective)
	managers.groupai:state():phalanx_damage_reduction_enable()
	CopLogicPhalanxVip._set_final_health_limit(data)
	
end

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
			phalanx_objective.pos = CopLogicPhalanxMinion._calc_pos_on_phalanx_circle(unit:brain()._logic_data, center_pos, angle_to_move_to, phalanx_minion_count)
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

function CopLogicPhalanxVip.do_vip_flee(unit)
	if not alive(unit) then
		return
	end

	local group_ai_state = managers.groupai:state()
	local nav_seg = unit:movement():nav_tracker():nav_segment()
	local flee_pos = group_ai_state:flee_point(nav_seg)

	if flee_pos then
		local flee_nav_seg = managers.navigation:get_nav_seg_from_pos(flee_pos)

		unit:brain():set_objective({
			forced = true,
			attitude = "avoid",
			type = "flee",
			pos = flee_pos,
			nav_seg = flee_nav_seg
		})
	else
		managers.groupai:state():detonate_smoke_grenade(unit:position() + math.UP * 10, unit:movement():m_head_pos(), 5, false)
		
		unit:brain():set_active(false)
		unit:base():set_slot(data.unit, 0)
		
		return
	end
end