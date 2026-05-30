local tmp_vec1 = Vector3()

function CivilianLogicIdle.enter(data, new_logic_name, enter_params)
	CopLogicBase.enter(data, new_logic_name, enter_params)

	local my_data = {
		unit = data.unit
	}
	data.internal_data = my_data

	if not data.char_tweak.detection then
		debug_pause_unit(data.unit, "missing detection tweak_data", data.unit)
	end

	local is_cool = data.unit:movement():cool()

	if is_cool then
		my_data.detection = data.char_tweak.detection.ntl
	else
		my_data.detection = data.char_tweak.detection.cbt
	end

	CopLogicBase._reset_attention(data)
	data.unit:brain():set_update_enabled_state(true)

	local key_str = tostring(data.key)
	my_data.tmp_vec3 = Vector3()
	my_data.detection_task_key = "CivilianLogicIdle._upd_detection" .. key_str

	CopLogicBase.queue_task(my_data, my_data.detection_task_key, CivilianLogicIdle._upd_detection, data, data.t + 1)

	if not data.been_outlined and data.char_tweak.outline_on_discover then
		my_data.outline_detection_task_key = "CivilianLogicIdle._upd_outline_detection" .. tostring(data.key)

		CopLogicBase.queue_task(my_data, my_data.outline_detection_task_key, CivilianLogicIdle._upd_outline_detection, data, data.t + 2)
	end

	if not data.unit:movement():cool() then
		my_data.registered_as_fleeing = true

		managers.groupai:state():register_fleeing_civilian(data.key, data.unit)
	end

	if objective and objective.stance then
		data.unit:movement():set_stance(objective.stance)
	end
	
	local old_objective = enter_params and enter_params.old_objective
	
	if not old_objective or not old_objective.action then
		CivilianLogicTravel._chk_has_old_action(data, my_data)
	end

	local attention_settings = nil

	if is_cool then
		attention_settings = {
			"civ_all_peaceful"
		}
	else
		attention_settings = {
			"civ_enemy_cbt",
			"civ_civ_cbt",
			"civ_murderer_cbt"
		}
	end

	data.unit:brain():set_attention_settings(attention_settings)
end

function CivilianLogicIdle.update(data)
	local my_data = data.internal_data
	
	if my_data.has_old_action or my_data.old_action_advancing then
		CivilianLogicTravel._upd_stop_old_action(data, my_data)
		
		if my_data.has_old_action or my_data.old_action_advancing then
			return
		end
	end
	
	CivilianLogicIdle._perform_objective_action(data, my_data, data.objective)
	
	if my_data.action_started then
		data.unit:brain():set_update_enabled_state(false)
	end
end

function CivilianLogicIdle._perform_objective_action(data, my_data, objective)
	if objective and not my_data.action_started then
		if objective.action and objective.action.type == "act" then
			my_data.action_started = data.unit:brain():action_request(objective.action)
		else
			my_data.action_started = true
			
			if objective.action then
				data.unit:brain():action_request(objective.action)
			end
		end

		if my_data.action_started then
			if objective.action_duration or objective.action_timeout_t then
				my_data.action_timeout_clbk_id = "CivilianLogicIdle_action_timeout" .. tostring(data.key)
				local action_timeout_t = objective.action_timeout_t or data.t + objective.action_duration
				objective.action_timeout_t = action_timeout_t

				CopLogicBase.add_delayed_clbk(my_data, my_data.action_timeout_clbk_id, callback(CivilianLogicIdle, CivilianLogicIdle, "clbk_action_timeout", data), action_timeout_t)
			end

			if objective.action_start_clbk then
				objective.action_start_clbk(data.unit)
			end
		end
	end
end

function CivilianLogicIdle.on_new_objective(data, old_objective, params)
	local new_objective = data.objective

	CivilianLogicIdle.super.on_new_objective(data, old_objective)

	local my_data = data.internal_data

	if new_objective then
		if new_objective.type == "escort" then
			CopLogicBase._exit(data.unit, "escort")
		elseif CopLogicIdle._chk_objective_needs_travel(data, new_objective) then
			CopLogicBase._exit(data.unit, "travel")
		elseif new_objective.type == "act" then
			local params = {old_objective = old_objective and old_objective.action and old_objective.action.type == "act" and old_objective}
			CopLogicBase._exit(data.unit, "idle", params)
		elseif data.is_tied then
			CopLogicBase._exit(data.unit, "surrender", params)
		elseif new_objective.type == "free" then
			if data.unit:movement():cool() or not new_objective.is_default then
				CopLogicBase._exit(data.unit, "idle")
			else
				CopLogicBase._exit(data.unit, "flee")
			end
		elseif new_objective.type == "surrender" then
			CopLogicBase._exit(data.unit, "surrender", params)
		end
	elseif data.unit:movement():cool() then
		CopLogicBase._exit(data.unit, "idle")
	elseif data.is_tied then
		CopLogicBase._exit(data.unit, "surrender", params)
	else
		CopLogicBase._exit(data.unit, "flee")
	end

	if new_objective and new_objective.stance then
		local stance_cool = new_objective.stance == "ntl"

		data.unit:movement():set_cool(stance_cool)
		data.unit:movement():set_stance(new_objective.stance)
	end

	if old_objective and old_objective.fail_clbk then
		old_objective.fail_clbk(data.unit)
	end
end

function CivilianLogicIdle._upd_detection(data)
	managers.groupai:state():on_unit_detection_updated(data.unit)

	data.t = TimerManager:game():time()
	local my_data = data.internal_data
	local delay = managers.groupai:state():whisper_mode() and 0 or data.is_tied and data.unit:anim_data().stand and 0 or 1
	CopLogicBase._upd_attention_obj_detection(data, nil, nil)
	local new_attention, new_reaction = CivilianLogicIdle._get_priority_attention(data, data.detected_attention_objects)

	CivilianLogicIdle._set_attention_obj(data, new_attention, new_reaction)

	if new_reaction and AIAttentionObject.REACT_SCARED <= new_reaction then
		local objective = data.objective
		local allow_trans, obj_failed = CopLogicBase.is_obstructed(data, objective, nil, new_attention)

		if allow_trans then
			local alert = {
				"vo_cbt",
				new_attention.m_head_pos,
				[5] = new_attention.unit
			}

			CivilianLogicIdle.on_alert(data, alert)

			if my_data ~= data.internal_data then
				return
			end
		end
	elseif not data.char_tweak.ignores_attention_focus then
		CopLogicIdle._chk_focus_on_attention_object(data, my_data)
	end

	local should_alert = data.name ~= "idle" or my_data.action_started

	if not data.unit:movement():cool() and should_alert and CivilianLogicFlee.needs_panic_redirect(data) then
		local objective = data.objective

		if not objective or objective.interrupt_dis == -1 or objective.is_default then
			local alert = {
				"vo_cbt",
				data.m_pos
			}

			CivilianLogicIdle.on_alert(data, alert)

			if my_data ~= data.internal_data then
				return
			end
		end
	end

	if CopLogicIdle._chk_relocate(data) then
		return
	end

	CopLogicBase.queue_task(my_data, my_data.detection_task_key, CivilianLogicIdle._upd_detection, data, data.t + delay)
end

function CivilianLogicIdle.on_alert(data, alert_data)
	if data.unit:anim_data().dont_flee then
		return
	end

	if data.is_tied and data.unit:anim_data().stand then
		if not LIES.settings.hhtacs then
			if TimerManager:game():time() - data.internal_data.state_enter_t > 3 then
				data.unit:brain():on_hostage_move_interaction(nil, "stay")
			end
		end

		return
	end

	local my_data = data.internal_data
	local my_dis, alert_delay = nil
	local my_listen_pos = data.unit:movement():m_head_pos()
	local alert_epicenter = alert_data[2]

	if CopLogicBase._chk_alert_obstructed(data.unit:movement():m_head_pos(), alert_data) then
		return
	end

	if CopLogicBase.is_alert_aggressive(alert_data[1]) and not data.unit:base().unintimidateable then
		if not data.unit:movement():cool() then
			local aggressor = alert_data[5]

			if aggressor and aggressor:base() then
				local is_intimidation = nil

				if aggressor:base().is_local_player then
					if managers.player:has_category_upgrade("player", "civ_calming_alerts") then
						is_intimidation = true
					end
				elseif aggressor:base().is_husk_player and aggressor:base():upgrade_value("player", "civ_calming_alerts") then
					is_intimidation = true
				end

				if is_intimidation then
					if not data.brain:interaction_voice() then
						data.unit:brain():on_intimidated(1, aggressor)
					end

					return
				end
			end
		end

		data.unit:movement():set_cool(false, managers.groupai:state().analyse_giveaway(data.unit:base()._tweak_table, alert_data[5], alert_data))
		data.unit:movement():set_stance(data.is_tied and "cbt" or "hos")
	end

	if alert_data[5] then
		local att_obj_data, is_new = CopLogicBase.identify_attention_obj_instant(data, alert_data[5]:key())
	end

	if my_data == data.internal_data and not data.char_tweak.ignores_aggression then
		if data.char_tweak.faster_reactions then
			local params = {
				data = data,
				alert_data = clone(alert_data)
			}
		
			CivilianLogicIdle._delayed_alert_clbk(nil, params)
		else
			my_dis = my_dis or alert_epicenter and mvector3.distance(my_listen_pos, alert_epicenter) or 3000
			alert_delay = math.lerp(1, 4, math.min(1, my_dis / 2000)) * math.random()

			if not my_data.delayed_alert_id then
				my_data.delayed_alert_id = "alert" .. tostring(data.key)

				CopLogicBase.add_delayed_clbk(my_data, my_data.delayed_alert_id, callback(CivilianLogicIdle, CivilianLogicIdle, "_delayed_alert_clbk", {
					data = data,
					alert_data = clone(alert_data)
				}), TimerManager:game():time() + alert_delay)
			end
		end
	end
end

function CivilianLogicIdle._delayed_alert_clbk(ignore_this, params)
	local data = params.data
	
	if not alive(data.unit) then
		return
	end
	
	local alert_data = params.alert_data
	local my_data = data.internal_data

	CopLogicBase.on_delayed_clbk(my_data, my_data.delayed_alert_id)

	my_data.delayed_alert_id = nil
	local alerting_unit = alert_data[5]
	alerting_unit = alive(alerting_unit) and alerting_unit

	if not CivilianLogicIdle.is_obstructed(data, alerting_unit) then
		my_data.delayed_alert_id = "alert" .. tostring(data.key)

		CopLogicBase.add_delayed_clbk(my_data, my_data.delayed_alert_id, callback(CivilianLogicIdle, CivilianLogicIdle, "_delayed_alert_clbk", {
			data = data,
			alert_data = clone(alert_data)
		}), TimerManager:game():time() + 1)

		return
	end

	alert_data[5] = alerting_unit
	
	local delay = 20 + 10 * math.random()
	
	if data.char_tweak.faster_reactions then
		delay = delay * 0.25
	end
	
	data.call_police_delay_t = data.call_police_delay_t or TimerManager:game():time() + delay

	data.unit:brain():set_objective({
		is_default = true,
		type = "free",
		alert_data = alert_data
	})
end

function CivilianLogicIdle.action_complete_clbk(data, action)
	local my_data = data.internal_data
	local action_type = action:type()

	if action_type == "turn" then
		my_data.turning = nil
	elseif action_type == "walk" then
		my_data.advancing = nil
		my_data.old_action_advancing = nil
	elseif action_type == "act" then
		local my_data = data.internal_data

		if my_data.action_started == action then
			if action:expired() then
				if not my_data.action_timeout_clbk_id then
					data.objective_complete_clbk(data.unit, data.objective)
				end
			elseif not my_data.action_expired and not my_data.detected_criminal then
				data.objective_failed_clbk(data.unit, data.objective)
			else
				my_data.action_started = nil
			end
		end
	end
end

function CivilianLogicIdle.is_available_for_assignment(data, objective)
	if objective and objective.forced then
		return true
	end

	local my_data = data.internal_data

	return (my_data.action_started == true or data.unit:anim_data().act_idle or data.unit:anim_data().peaceful or data.unit:anim_data().idle) and not my_data.exiting and not my_data.delayed_alert_id
end