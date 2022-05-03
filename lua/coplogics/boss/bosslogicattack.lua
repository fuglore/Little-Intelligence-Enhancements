function BossLogicAttack.enter(data, new_logic_name, enter_params)
	CopLogicBase.enter(data, new_logic_name, enter_params)

	local brain_ext = data.brain

	brain_ext:cancel_all_pathing_searches()

	local unit = data.unit
	local char_tweak = data.char_tweak
	local old_internal_data = data.internal_data
	local new_internal_data = {}
	data.internal_data = new_internal_data
	new_internal_data.unit = unit
	new_internal_data.detection = char_tweak.detection.combat

	if old_internal_data then
		new_internal_data.turning = old_internal_data.turning
		new_internal_data.firing = old_internal_data.firing
		new_internal_data.shooting = old_internal_data.shooting
		new_internal_data.attention_unit = old_internal_data.attention_unit
	end

	if data.cool then
		unit:movement():set_cool(false)

		if new_internal_data ~= data.internal_data then
			return
		end
	end

	if not new_internal_data.shooting then
		local new_stance = nil
		local allowed_stances = char_tweak.allowed_stances

		if not allowed_stances or allowed_stances.hos then
			new_stance = "hos"
		elseif allowed_stances.cbt then
			new_stance = "cbt"
		end

		if new_stance then
			data.unit:movement():set_stance(new_stance)

			if new_internal_data ~= data.internal_data then
				return
			end
		end
	end

	local equipped_weap = unit:inventory():equipped_unit()

	if equipped_weap then
		local weap_usage = equipped_weap:base():weapon_tweak_data().usage
		new_internal_data.weapon_range = weap_usage and char_tweak.weapon[weap_usage].range
	end

	local objective = data.objective
	new_internal_data.attitude = objective and objective.attitude or "engage"
	local key_str = tostring(data.key)
	local detection_task_key = "BossLogicAttack._upd_enemy_detection" .. key_str
	new_internal_data.detection_task_key = detection_task_key

	CopLogicBase.queue_task(new_internal_data, detection_task_key, BossLogicAttack._upd_enemy_detection, data, data.t, true)
	CopLogicIdle._chk_has_old_action(data, new_internal_data)

	if objective and (objective.action_duration or objective.action_timeout_t and data.t < objective.action_timeout_t) then
		new_internal_data.action_timeout_clbk_id = "CopLogicIdle_action_timeout" .. key_str
		local action_timeout_t = objective.action_timeout_t or data.t + objective.action_duration
		objective.action_timeout_t = action_timeout_t

		CopLogicBase.add_delayed_clbk(new_internal_data, new_internal_data.action_timeout_clbk_id, callback(CopLogicIdle, CopLogicIdle, "clbk_action_timeout", data), action_timeout_t)
	end

	brain_ext:set_attention_settings({
		cbt = true
	})
	brain_ext:set_update_enabled_state(true)

	if data.char_tweak.throwable then
		new_internal_data.last_seen_throwable_pos = Vector3()
	end
end

function BossLogicAttack._pathing_complete_clbk(data)
	local my_data = data.internal_data

	if my_data.pathing_to_chase_pos then
		BossLogicAttack._process_pathing_results(data, my_data)
		BossLogicAttack._upd_combat_movement(data, my_data)
	end
end