function TeamAILogicTravel.enter(data, new_logic_name, enter_params)
	CopLogicBase.enter(data, new_logic_name, enter_params)
	data.unit:brain():cancel_all_pathing_searches()

	local old_internal_data = data.internal_data
	local my_data = {
		unit = data.unit,
		detection = data.char_tweak.detection.recon
	}

	if old_internal_data then
		my_data.attention_unit = old_internal_data.attention_unit

		if old_internal_data.nearest_cover then
			my_data.nearest_cover = old_internal_data.nearest_cover

			managers.navigation:reserve_cover(my_data.nearest_cover[1], data.pos_rsrv_id)
		end

		if old_internal_data.best_cover then
			my_data.best_cover = old_internal_data.best_cover

			managers.navigation:reserve_cover(my_data.best_cover[1], data.pos_rsrv_id)
		end
	end

	data.internal_data = my_data
	local key_str = tostring(data.key)

	if not data.unit:movement():cool() then
		my_data.detection_task_key = "TeamAILogicTravel._upd_enemy_detection" .. key_str

		CopLogicBase.queue_task(my_data, my_data.detection_task_key, TeamAILogicTravel._upd_enemy_detection, data, data.t)
	end

	my_data.advance_path_search_id = "TeamAILogicTravel_detailed" .. tostring(data.key)
	my_data.coarse_path_search_id = "TeamAILogicTravel_coarse" .. tostring(data.key)
	my_data.path_ahead = data.team.id == tweak_data.levels:get_default_team_ID("player")

	if data.objective then
		data.objective.called = false
		my_data.called = true

		if data.objective.follow_unit then
			my_data.cover_wait_t = {
				0,
				0
			}
		end

		if data.objective.path_style == "warp" then
			my_data.warp_pos = data.objective.pos
		end
	end

	data.unit:movement():set_allow_fire(false)

	local w_td = alive(data.unit) and data.unit:inventory():equipped_unit() and data.unit:inventory():equipped_unit():base():weapon_tweak_data()

	if w_td then
		local cw_td = data.char_tweak.weapon[w_td.usage]
		my_data.weapon_range = (cw_td or {}).range or 5000
	end

	if not data.unit:movement():chk_action_forbidden("walk") or data.unit:anim_data().act_idle then
		local new_action = {
			body_part = 2,
			type = "idle"
		}

		data.unit:brain():action_request(new_action)
	end
end

TeamAILogicTravel._pathing_complete_clbk = CopLogicTravel._pathing_complete_clbk