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

function CopLogicPhalanxVip.breakup(remote_call)
	print("CopLogicPhalanxVip.breakup")

	local groupai = managers.groupai:state()
	local phalanx_vip = groupai:phalanx_vip()

	if phalanx_vip and alive(phalanx_vip) then
		groupai:unit_leave_group(phalanx_vip, false)
		managers.groupai:state():unregister_phalanx_vip()

		local nav_seg = phalanx_vip:movement():nav_tracker():nav_segment()
		local ignore_segments = {}
		local data = phalanx_vip:brain()._logic_data
		local flee_pos = managers.groupai:state():flee_point(data.unit:movement():nav_tracker():nav_segment(), ignore_segments)
	
		if not flee_pos then
			managers.groupai:state():detonate_smoke_grenade(data.m_pos + math.UP * 10, data.unit:movement():m_head_pos(), 5, false)
			
			data.unit:brain():set_active(false)
			data.unit:base():set_slot(data.unit, 0)
			
			if not remote_call then
				CopLogicPhalanxMinion.breakup(true)
			end
			
			return
		end

		local iterations = 1
		local coarse_path = nil
		local my_data = data.internal_data
		local search_params = {
			from_tracker = data.unit:movement():nav_tracker(),
			id = "CopLogicFlee._get_coarse_flee_path" .. tostring(data.key),
			access_pos = data.char_tweak.access,
			verify_clbk = callback(CopLogicTravel, CopLogicTravel, "_investigate_coarse_path_verify_clbk")
		}
		local max_attempts = 5

		while iterations < max_attempts do
			local nav_seg = managers.navigation:get_nav_seg_from_pos(flee_pos)
			search_params.to_seg = nav_seg
			
			if search_params.verify_clbk and iterations > 4 then
				search_params.verify_clbk = nil
				iterations = 1
				ignore_segments = {}
			end
			
			coarse_path = managers.navigation:search_coarse(search_params)

			if not coarse_path then
				coarse_path = nil

				table.insert(ignore_segments, nav_seg)
			else
				break
			end

			iterations = iterations + 1

			if max_attempts > iterations then
				flee_pos = managers.groupai:state():flee_point(data.unit:movement():nav_tracker():nav_segment(), ignore_segments)

				if not flee_pos then
					break
				end
			end
		end

		if flee_pos then
			local flee_nav_seg = managers.navigation:get_nav_seg_from_pos(flee_pos)
			local new_objective = {
				attitude = "avoid",
				type = "flee",
				pos = flee_pos,
				nav_seg = flee_nav_seg
			}

			if phalanx_vip:brain():objective() then
				print("Setting VIP flee objective!")
				phalanx_vip:brain():set_objective(new_objective)
				phalanx_vip:sound():say("cpw_a04", true, true)
			end
		else
			managers.groupai:state():detonate_smoke_grenade(data.m_pos + math.UP * 10, data.unit:movement():m_head_pos(), 5, false)
	
			data.unit:brain():set_active(false)
			data.unit:base():set_slot(data.unit, 0)
		end
	end

	if not remote_call then
		CopLogicPhalanxMinion.breakup(true)
	end
end