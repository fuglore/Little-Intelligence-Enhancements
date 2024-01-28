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
	data.unit:brain():set_update_enabled_state(false)

	local key_str = tostring(data.key)
	local objective = data.objective

	if objective then
		if objective.action then
			local action = data.unit:brain():action_request(objective.action)

			if action and objective.action.type == "act" then
				my_data.acting = action

				if objective.action_start_clbk then
					objective.action_start_clbk(data.unit)

					if my_data ~= data.internal_data then
						return
					end
				end
			end
		end

		if objective.action_duration then
			my_data.action_timeout_clbk_id = "CivilianLogicIdle_action_timeout" .. key_str
			local action_timeout_t = data.t + objective.action_duration

			CopLogicBase.add_delayed_clbk(my_data, my_data.action_timeout_clbk_id, callback(CivilianLogicIdle, CivilianLogicIdle, "clbk_action_timeout", data), action_timeout_t)
		end
	end

	my_data.tmp_vec3 = tmp_vec1
	
	if not managers.groupai:state():enemy_weapons_hot() or not my_data.acting or CivilianLogicIdle._objective_can_be_interrupted(data) then
		my_data.detection_task_key = "CivilianLogicIdle._upd_detection" .. key_str

		CivilianLogicIdle._upd_detection(data)
	end
	
	if my_data ~= data.internal_data then
		return
	end
	
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

function CivilianLogicIdle._objective_can_be_interrupted(data)
	return data.objective and (data.objective.interrupt_dis or data.objective.interrupt_suppression or data.objective.interrupt_health)
end

function CivilianLogicIdle._upd_detection(data)
	managers.groupai:state():on_unit_detection_updated(data.unit)

	data.t = TimerManager:game():time()
	local my_data = data.internal_data
	CopLogicBase._upd_attention_obj_detection(data, nil, nil)
	
	local delay = 0
	
	if not managers.groupai:state():whisper_mode() then
		delay = 1.4
	end
	
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
	
	if my_data ~= data.internal_data then
		return
	end

	if not data.unit:movement():cool() and (not my_data.acting or not not data.unit:anim_data().act_idle) then
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
	
	if my_data ~= data.internal_data then
		return
	end
	
	if managers.groupai:state():whisper_mode() or not my_data.acting or CivilianLogicIdle._objective_can_be_interrupted(data) then
		CopLogicBase.queue_task(my_data, my_data.detection_task_key, CivilianLogicIdle._upd_detection, data, data.t + delay)
	else
		my_data.detection_task_key = nil
	end
end

function CivilianLogicIdle.on_alert(data, alert_data)
	if data.is_tied and data.unit:anim_data().stand then
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
		my_dis = my_dis or alert_epicenter and mvector3.distance(my_listen_pos, alert_epicenter) or 3000
		alert_delay = math.lerp(1, 4, math.min(1, my_dis / 2000)) * math.random()
		
		if data.char_tweak.faster_reactions then
			alert_delay = alert_delay * 0.5
		end

		if not my_data.delayed_alert_id then
			my_data.delayed_alert_id = "alert" .. tostring(data.key)

			CopLogicBase.add_delayed_clbk(my_data, my_data.delayed_alert_id, callback(CivilianLogicIdle, CivilianLogicIdle, "_delayed_alert_clbk", {
				data = data,
				alert_data = clone(alert_data)
			}), TimerManager:game():time() + alert_delay)
		end
	end
end

function CivilianLogicIdle._delayed_alert_clbk(ignore_this, params)
	local data = params.data
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
	
	if not data.call_police_delay_t then
		local call_t = TimerManager:game():time() + 20 + 10 * math.random()
		
		if data.char_tweak.faster_reactions then
			call_t = call_t * 0.25
		end

		data.call_police_delay_t = call_t
	end

	data.unit:brain():set_objective({
		is_default = true,
		type = "free",
		alert_data = alert_data
	})
end

function CivilianLogicIdle.is_obstructed(data, aggressor_unit)
	if data.unit:movement():chk_action_forbidden("walk") and not data.unit:anim_data().act_idle then
		return
	end

	if not objective or objective.is_default or (objective.in_place or not objective.nav_seg or objective.type == "free") and not objective.action and not objective.action_duration then
		return true
	end

	if objective.interrupt_dis == -1 then
		return true
	end

	if aggressor_unit and aggressor_unit:movement() and objective.interrupt_dis and mvector3.distance_sq(data.m_pos, aggressor_unit:movement():m_newest_pos()) < objective.interrupt_dis * objective.interrupt_dis then
		return true
	end

	if objective.interrupt_health then
		local health_ratio = data.unit:character_damage():health_ratio()

		if health_ratio < 1 and health_ratio < objective.interrupt_health then
			return true
		end
	end
end

function CivilianLogicIdle.action_complete_clbk(data, action)
	local my_data = data.internal_data

	if action:type() == "turn" then
		my_data.turning = nil
	elseif action:type() == "act" then
		local act_action = my_data.acting
		
		my_data.acting = nil
	
		if act_action == action then			
			if action:expired() then				
				if not my_data.action_timeout_clbk_id then
					data.objective_complete_clbk(data.unit, data.objective)
				end
			else
				data.objective_failed_clbk(data.unit, data.objective)
			end
		end
		
		if data.internal_data == my_data then
			if managers.groupai:state():enemy_weapons_hot() and not my_data.detection_task_key then				
				my_data.detection_task_key = "CivilianLogicIdle._upd_detection" .. tostring(data.key)
				
				CivilianLogicIdle._upd_detection(data)
			end
		end
	end
end