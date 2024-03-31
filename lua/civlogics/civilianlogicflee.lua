function CivilianLogicFlee.enter(data, new_logic_name, enter_params)
	CopLogicBase.enter(data, new_logic_name, enter_params)
	data.unit:brain():cancel_all_pathing_searches()

	local old_internal_data = data.internal_data
	local my_data = {
		unit = data.unit
	}
	data.internal_data = my_data
	my_data.detection = data.char_tweak.detection.cbt

	data.unit:brain():set_update_enabled_state(false)

	local key_str = tostring(data.key)

	managers.groupai:state():register_fleeing_civilian(data.key, data.unit)

	my_data.panic_area = managers.groupai:state():get_area_from_nav_seg_id(data.unit:movement():nav_tracker():nav_segment())

	CivilianLogicFlee.reset_actions(data)

	if data.objective then
		if data.objective.alert_data then
			CivilianLogicFlee.on_alert(data, data.objective.alert_data)

			if my_data ~= data.internal_data then
				return
			end

			if data.unit:anim_data().react_enter then
				my_data.delayed_post_react_alert_id = "postreact_alert" .. key_str

				if data.char_tweak.faster_reactions then
					CopLogicBase.add_delayed_clbk(my_data, my_data.delayed_post_react_alert_id, callback(CivilianLogicFlee, CivilianLogicFlee, "post_react_alert_clbk", {
						data = data
					}), TimerManager:game():time() + math.lerp(2, 4, math.random()))
				else
					CopLogicBase.add_delayed_clbk(my_data, my_data.delayed_post_react_alert_id, callback(CivilianLogicFlee, CivilianLogicFlee, "post_react_alert_clbk", {
						data = data
					}), TimerManager:game():time() + math.lerp(4, 8, math.random()))
				end
			end
		elseif data.objective.dmg_info then
			CivilianLogicFlee.damage_clbk(data, data.objective.dmg_info)
		end
	end

	data.unit:movement():set_stance(data.is_tied and "cbt" or "hos")
	data.unit:movement():set_cool(false)

	if my_data ~= data.internal_data then
		return
	end

	CivilianLogicFlee._chk_add_delayed_rescue_SO(data, my_data)

	if data.objective and data.objective.was_rescued or not data.is_tied and data.char_tweak.faster_reactions and data.char_tweak.flee_type ~= "hide" and not data.char_tweak.is_escort and not data.unit:base()._tweak_table == "drunk_pilot" and managers.groupai:state():is_police_called() then
		local was_freed = data.objective and data.objective.was_rescued ~= nil
		
		if data.objective then
			data.objective.was_rescued = nil
		end

		if CivilianLogicFlee._get_coarse_flee_path(data) then
			data.unit:brain():set_update_enabled_state(true)
		
			if was_freed then
				managers.groupai:state():on_civilian_freed()
			end
		end
	end

	if not data.been_outlined and data.char_tweak.outline_on_discover then
		my_data.outline_detection_task_key = "CivilianLogicFlee_upd_outline_detection" .. key_str

		CopLogicBase.queue_task(my_data, my_data.outline_detection_task_key, CivilianLogicIdle._upd_outline_detection, data, data.t + 2)
	end

	if not my_data.detection_task_key and data.unit:anim_data().react_enter then
		my_data.detection_task_key = "CivilianLogicFlee._upd_detection" .. key_str

		CivilianLogicFlee._upd_detection(data)
	end

	local attention_settings = nil
	attention_settings = {
		"civ_enemy_cbt",
		"civ_civ_cbt",
		"civ_murderer_cbt"
	}

	CivilianLogicFlee.schedule_run_away_clbk(data)

	if not my_data.delayed_post_react_alert_id and not data.unit:anim_data().panic then
		my_data.delayed_post_react_alert_id = "postreact_alert" .. key_str
		
		if data.unit:anim_data().move or data.unit:anim_data().call_police or data.unit:anim_data().peaceful or data.unit:movement():stance_name() == "ntl" then
			CopLogicBase.add_delayed_clbk(my_data, my_data.delayed_post_react_alert_id, callback(CivilianLogicFlee, CivilianLogicFlee, "post_react_alert_clbk", {
				data = data,
			}), TimerManager:game():time() + 1)
		elseif data.char_tweak.faster_reactions then
			CopLogicBase.add_delayed_clbk(my_data, my_data.delayed_post_react_alert_id, callback(CivilianLogicFlee, CivilianLogicFlee, "post_react_alert_clbk", {
				data = data
			}), TimerManager:game():time() + math.lerp(2, 4, math.random()))
		else
			CopLogicBase.add_delayed_clbk(my_data, my_data.delayed_post_react_alert_id, callback(CivilianLogicFlee, CivilianLogicFlee, "post_react_alert_clbk", {
				data = data
			}), TimerManager:game():time() + math.lerp(4, 8, math.random()))
		end
	end

	data.unit:brain():set_attention_settings(attention_settings)

	if data.char_tweak.calls_in and not managers.groupai:state():is_police_called() then
		my_data.call_police_clbk_id = "civ_call_police" .. key_str
		local call_t = math.max(data.call_police_delay_t or 0, TimerManager:game():time() + math.lerp(1, 10, math.random()))

		CopLogicBase.add_delayed_clbk(my_data, my_data.call_police_clbk_id, callback(CivilianLogicFlee, CivilianLogicFlee, "clbk_chk_call_the_police", data), call_t)
	end

	my_data.next_action_t = 0
end

function CivilianLogicFlee.on_alert(data, alert_data)
	local my_data = data.internal_data

	if my_data.coarse_path then
		return
	end

	if CopLogicBase.is_alert_aggressive(alert_data[1]) then
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
				data.unit:brain():on_intimidated(1, aggressor)

				return
			end
		end
	end

	local anim_data = data.unit:anim_data()

	if anim_data.react_enter then
		if not my_data.delayed_post_react_alert_id then
			my_data.delayed_post_react_alert_id = "postreact_alert" .. tostring(data.key)

			CopLogicBase.add_delayed_clbk(my_data, my_data.delayed_post_react_alert_id, callback(CivilianLogicFlee, CivilianLogicFlee, "post_react_alert_clbk", {
				data = data,
				alert_data = clone(alert_data)
			}), TimerManager:game():time() + 1)
		end

		return
	elseif alert_data[1] ~= "bullet" and alert_data[1] ~= "aggression" and alert_data[1] ~= "explosion" then
		return
	elseif anim_data.react or anim_data.halt then
		--civilians in drop shouldn't do this because if they're in drop they should be in fucking surrender
		local action_data = {
			clamp_to_graph = true,
			variant = "panic",
			body_part = 1,
			type = "act"
		}

		data.unit:brain():action_request(action_data)

		local is_dangerous = CopLogicBase.is_alert_dangerous(alert_data[1])

		if is_dangerous then
			data.unit:sound():say("a01x_any", true)
		end

		if data.unit:unit_data().mission_element then
			data.unit:unit_data().mission_element:event("panic", data.unit)
		end

		CopLogicBase._reset_attention(data)

		if is_dangerous and not managers.groupai:state():enemy_weapons_hot() then
			local alert = {
				"vo_distress",
				data.unit:movement():m_head_pos(),
				200,
				data.SO_access,
				data.unit
			}

			managers.groupai:state():propagate_alert(alert)
		end

		return
	elseif not anim_data.panic then
		local action_data = {
			clamp_to_graph = true,
			variant = "panic",
			body_part = 1,
			type = "act"
		}

		data.unit:brain():action_request(action_data)
		data.unit:sound():say("a01x_any", true)

		if data.unit:unit_data().mission_element then
			data.unit:unit_data().mission_element:event("panic", data.unit)
		end

		if not managers.groupai:state():enemy_weapons_hot() then
			local alert = {
				"vo_distress",
				data.unit:movement():m_head_pos(),
				200,
				data.SO_access,
				data.unit
			}

			managers.groupai:state():propagate_alert(alert)
		end

		return
	end

	CivilianLogicFlee._run_away_from_alert(data, alert_data)
end

function CivilianLogicFlee.on_intimidated(data, amount, aggressor_unit)
	if not data.char_tweak.intimidateable or data.unit:base().unintimidateable or data.unit:anim_data().unintimidateable then
		return
	end

	local my_data = data.internal_data
	
	if data.unit:anim_data().move or data.unit:anim_data().call_police or data.unit:anim_data().peaceful or data.unit:movement():stance_name() == "ntl" then
		local params = {
			data,
			amount,
			aggressor_unit
		}
	
		CivilianLogicFlee._delayed_intimidate_clbk(nil, params)
	elseif not my_data.delayed_intimidate_id then
		my_data.delayed_intimidate_id = "intimidate" .. tostring(data.key)
		local delay = 1 - amount + math.random() * 0.2

		CopLogicBase.add_delayed_clbk(my_data, my_data.delayed_intimidate_id, callback(CivilianLogicFlee, CivilianLogicFlee, "_delayed_intimidate_clbk", {
			data,
			amount,
			aggressor_unit
		}), TimerManager:game():time() + delay)
	end
end

function CivilianLogicFlee.post_react_alert_clbk(shait, params)
	local data = params.data
	local alert_data = params.alert_data
	local my_data = data.internal_data
	local anim_data = data.unit:anim_data()

	CopLogicBase.on_delayed_clbk(my_data, my_data.delayed_post_react_alert_id)

	if anim_data.react_enter then
		CopLogicBase.add_delayed_clbk(my_data, my_data.delayed_post_react_alert_id, callback(CivilianLogicFlee, CivilianLogicFlee, "post_react_alert_clbk", {
			data = data,
			alert_data = data.objective and data.objective.alert_data and clone(data.objective.alert_data) or alert_data
		}), TimerManager:game():time() + 1)

		return
	end

	my_data.delayed_post_react_alert_id = nil

	if alert_data and alive(alert_data[5]) then
		CivilianLogicFlee._run_away_from_alert(data, alert_data)

		return
	end
	
	if anim_data.react or anim_data.panic or anim_data.peaceful then
		if not data.is_tied and data.char_tweak.faster_reactions and data.char_tweak.flee_type ~= "hide" and managers.groupai:state():is_police_called() then --faster reactions = just book it
			if CivilianLogicFlee._get_coarse_flee_path(data) then
				data.unit:brain():set_update_enabled_state(true)
				
				return
			end
		end
	
		CivilianLogicFlee._find_hide_cover(data)
		
		return
	else
		--drop is not the right anim for this, i think
		local action_data = {
			clamp_to_graph = true,
			variant = "panic",
			body_part = 1,
			type = "act"
		}

		data.unit:brain():action_request(action_data)
		data.unit:sound():say("a01x_any", true)

		if data.unit:unit_data().mission_element then
			data.unit:unit_data().mission_element:event("panic", data.unit)
		end

		CopLogicBase._reset_attention(data)

		if not managers.groupai:state():enemy_weapons_hot() then
			local alert = {
				"vo_distress",
				data.unit:movement():m_head_pos(),
				200,
				data.SO_access,
				data.unit
			}

			managers.groupai:state():propagate_alert(alert)
		end

		return
	end

	CopLogicBase.add_delayed_clbk(my_data, my_data.delayed_post_react_alert_id, callback(CivilianLogicFlee, CivilianLogicFlee, "post_react_alert_clbk", {
		data = data,
		alert_data = data.objective and data.objective.alert_data and clone(data.objective.alert_data) or alert_data
	}), TimerManager:game():time() + 1)
end

function CivilianLogicFlee.reset_actions(data)
	local walk_action = data.unit:movement()._active_actions[2]

	if walk_action and walk_action:type() == "walk" then
		data.internal_data.old_action_advancing = true
		local action = {
			body_part = 2,
			type = "idle"
		}

		data.unit:movement():action_request(action)
	end
end

function CivilianLogicFlee.action_complete_clbk(data, action)
	local my_data = data.internal_data

	if action:type() == "walk" then
		if not my_data.old_action_advancing then
			if not data.char_tweak.faster_reactions then
				my_data.next_action_t = TimerManager:game():time() + math.lerp(2, 8, math.random())
			end

			if action:expired() then
				if my_data.moving_to_cover then
					data.unit:sound():say("a03x_any", true)

					my_data.in_cover = my_data.moving_to_cover

					CopLogicAttack._set_nearest_cover(my_data, my_data.in_cover)
					CivilianLogicFlee._chk_add_delayed_rescue_SO(data, my_data)
				end

				if my_data.coarse_path_index then
					my_data.coarse_path_index = my_data.coarse_path_index + 1
				end
			end
		end

		my_data.moving_to_cover = nil
		my_data.advancing = nil
		my_data.old_action_advancing = nil

		if not my_data.coarse_path_index then
			data.unit:brain():set_update_enabled_state(false)
		end
	elseif action:type() == "act" and my_data.calling_the_police then
		my_data.calling_the_police = nil

		if not my_data.called_the_police then
			managers.groupai:state():on_criminal_suspicion_progress(nil, data.unit, "call_interrupted")
		end
	end
end

function CivilianLogicFlee._find_hide_cover(data)
	local my_data = data.internal_data
	my_data.cover_search_task_key = nil

	if data.unit:anim_data().dont_flee then
		return
	end

	local avoid_pos = nil

	if my_data.avoid_pos then
		avoid_pos = my_data.avoid_pos
	elseif data.attention_obj and AIAttentionObject.REACT_SCARED <= data.attention_obj.reaction then
		avoid_pos = data.attention_obj.m_pos
	else
		local closest_crim, closest_crim_dis = nil

		for u_key, att_data in pairs(data.detected_attention_objects) do
			if not closest_crim_dis or att_data.dis < closest_crim_dis then
				closest_crim = att_data
				closest_crim_dis = att_data.dis
			end
		end

		if closest_crim then
			avoid_pos = closest_crim.m_pos
		else
			avoid_pos = Vector3()

			mvector3.random_orthogonal(avoid_pos)
			mvector3.multiply(avoid_pos, 100)
			mvector3.add(avoid_pos, data.m_pos) --this could crash in vanilla
		end
	end

	if my_data.best_cover then
		local best_cover_vec = avoid_pos - my_data.best_cover[1][1]

		if mvector3.dot(best_cover_vec, my_data.best_cover[1][2]) > 0.7 then
			return
		end
	end
	
	if not my_data.panic_area then
		my_data.panic_area = managers.groupai:state():get_area_from_nav_seg_id(data.unit:movement():nav_tracker():nav_segment())
	end
	
	local cover = managers.navigation:find_cover_away_from_pos(data.m_pos, avoid_pos, my_data.panic_area.nav_segs)

	if cover then
		if not data.unit:anim_data().panic then
			local action_data = {
				clamp_to_graph = true,
				variant = "panic",
				body_part = 1,
				type = "act"
			}

			data.unit:brain():action_request(action_data)
		end

		CivilianLogicFlee._cancel_pathing(data, my_data)
		CopLogicAttack._set_best_cover(data, my_data, {
			cover
		})
		data.unit:brain():set_update_enabled_state(true)
		CopLogicBase._reset_attention(data)
		--log("waaah!")
	elseif data.unit:anim_data().react or data.unit:anim_data().halt or not data.unit:anim_data().panic then
		local action_data = {
			clamp_to_graph = true,
			variant = "panic",
			body_part = 1,
			type = "act"
		}

		data.unit:brain():action_request(action_data)
		data.unit:sound():say("a02x_any", true)

		if data.unit:unit_data().mission_element then
			data.unit:unit_data().mission_element:event("panic", data.unit)
		end

		CopLogicBase._reset_attention(data)

		if not managers.groupai:state():enemy_weapons_hot() then
			local alert = {
				"vo_distress",
				data.unit:movement():m_head_pos(),
				200,
				data.SO_access,
				data.unit
			}

			managers.groupai:state():propagate_alert(alert)
		end
	end
end

function CivilianLogicFlee.update(data)
	local my_data = data.internal_data
	
	if my_data.next_upd_t and my_data.next_upd_t > data.t then --couldn't be fucked to set up task updates due to how this logic works, decided to do it like this instead
		return
	end

	local exit_state = nil
	local unit = data.unit
	local objective = data.objective
	local t = data.t

	if my_data.calling_the_police then
		-- Nothing
	elseif my_data.flee_path_search_id or my_data.coarse_path_search_id then
		CivilianLogicFlee._update_pathing(data, my_data)
	elseif my_data.flee_path then
		if not unit:movement():chk_action_forbidden("walk") and not my_data.advancing then
			CivilianLogicFlee._start_moving_to_cover(data, my_data)
		end
	elseif my_data.coarse_path then
		if not my_data.advancing and my_data.next_action_t < data.t then
			local coarse_path = my_data.coarse_path
			local cur_index = my_data.coarse_path_index
			local total_nav_points = #coarse_path

			if cur_index >= total_nav_points then
				if data.unit:unit_data().mission_element then
					data.unit:unit_data().mission_element:event("fled", data.unit)
				end

				data.unit:base():set_slot(unit, 0)
				
				return
			else
				local to_pos, to_cover = nil

				if cur_index == total_nav_points - 1 then
					to_pos = my_data.flee_target.pos
				else
					local next_area = managers.groupai:state():get_area_from_nav_seg_id(coarse_path[cur_index + 1][1])
					
					local crim_pos
					local cover
					
					if data.attention_obj and AIAttentionObject.REACT_SCARED <= data.attention_obj.reaction then
						crim_pos = data.attention_obj.m_head_pos
					else
						local closest_crim, closest_crim_dis = nil

						for u_key, att_data in pairs(data.detected_attention_objects) do
							if not closest_crim_dis or att_data.dis < closest_crim_dis then
								closest_crim = att_data
								closest_crim_dis = att_data.dis
							end
						end
						
						if closest_crim then
							crim_pos = closest_crim.m_head_pos
						end
					end
					
					if crim_pos then
						cover = managers.navigation:find_cover_away_from_pos(coarse_path[cur_index + 2][2], crim_pos, next_area.nav_segs)
					end

					if cover then
						CopLogicAttack._set_best_cover(data, my_data, {
							cover
						})

						to_cover = my_data.best_cover
					else
						to_pos = CopLogicTravel._get_pos_on_wall(coarse_path[cur_index + 1][2], 700)
					end
				end

				my_data.flee_path_search_id = "civ_flee" .. tostring(data.key)

				if to_cover then
					my_data.pathing_to_cover = to_cover

					unit:brain():search_for_path_to_cover(my_data.flee_path_search_id, to_cover[1], nil, nil)
				else
					data.brain:add_pos_rsrv("path", {
						radius = 30,
						position = to_pos
					})
					unit:brain():search_for_path(my_data.flee_path_search_id, to_pos)
				end
			end
		end
	elseif my_data.best_cover then
		local best_cover = my_data.best_cover

		if not my_data.moving_to_cover or my_data.moving_to_cover ~= best_cover then
			if not my_data.in_cover or my_data.in_cover ~= best_cover then
				if not unit:anim_data().panic then
					local action_data = {
						clamp_to_graph = true,
						variant = "panic",
						body_part = 1,
						type = "act"
					}

					data.unit:brain():action_request(action_data)
					data.unit:brain():set_update_enabled_state(true)
					CopLogicBase._reset_attention(data)
				end

				my_data.pathing_to_cover = my_data.best_cover
				local search_id = "civ_cover" .. tostring(data.key)
				my_data.flee_path_search_id = search_id

				data.unit:brain():search_for_path_to_cover(search_id, my_data.best_cover[1])
			end
		end
	end
	
	my_data.next_upd_t = data.t + 0.5
end

function CivilianLogicFlee.rescue_SO_verification(ignore_this, params, unit)
	local areas = params.areas
	local data = params.logic_data

	if not unit:base():char_tweak().rescue_hostages or unit:movement():cool() or data.team.foes[unit:movement():team().id] then
		return
	end

	local u_nav_seg = unit:movement():nav_tracker():nav_segment()

	for _, area in ipairs(areas) do
		if area.nav_segs[u_nav_seg] or data.tactics and data.tactics.hrt and math.abs(data.m_pos.z - area.pos.z) < 250 then
			return true
		end
	end
end

function CivilianLogicFlee.on_rescue_SO_administered(ignore_this, data, receiver_unit)
	managers.groupai:state():on_civilian_try_freed()

	local my_data = data.internal_data
	my_data.rescuer = receiver_unit
	my_data.rescue_SO_id = nil
	
	receiver_unit:sound():say("cr1", true)
	
	managers.groupai:state():unregister_rescueable_hostage(data.key)
end

function CivilianLogicFlee.register_rescue_SO(ignore_this, data)
	local my_data = data.internal_data

	CopLogicBase.on_delayed_clbk(my_data, my_data.delayed_rescue_SO_id)

	my_data.delayed_rescue_SO_id = nil

	if data.unit:anim_data().dont_flee then
		return
	end

	local my_tracker = data.unit:movement():nav_tracker()
	local objective_pos = my_tracker:field_position()
	local side = data.unit:movement():m_rot():x()

	mvector3.multiply(side, 65)

	local test_pos = mvector3.copy(objective_pos)

	mvector3.add(test_pos, side)

	local so_pos, so_rot = nil
	local ray_params = {
		allow_entry = false,
		trace = true,
		tracker_from = data.unit:movement():nav_tracker(),
		pos_to = test_pos
	}

	if not managers.navigation:raycast(ray_params) then
		so_pos = test_pos
		so_rot = Rotation(-side, math.UP)
	else
		test_pos = mvector3.copy(objective_pos)

		mvector3.subtract(test_pos, side)

		ray_params.pos_to = test_pos

		if not managers.navigation:raycast(ray_params) then
			so_pos = test_pos
			so_rot = Rotation(side, math.UP)
		else
			so_pos = mvector3.copy(objective_pos)
			so_rot = nil
		end
	end
	
	local followup_objective = {
		type = "act",
		action = {
			variant = "idle",
			body_part = 1,
			type = "act",
			blocks = {
				action = -1,
				walk = -1
			}
		}
	}
	
	local objective = {
		type = "act",
		interrupt_health = 0.75,
		destroy_clbk_key = false,
		stance = "hos",
		scan = true,
		interrupt_dis = 700,
		sabo_voiceline = "none",
		follow_unit = data.unit,
		pos = so_pos,
		rot = so_rot,
		nav_seg = data.unit:movement():nav_tracker():nav_segment(),
		fail_clbk = callback(CivilianLogicFlee, CivilianLogicFlee, "on_rescue_SO_failed", data),
		complete_clbk = callback(CivilianLogicFlee, CivilianLogicFlee, "on_rescue_SO_completed", data),
		action = {
			variant = "untie",
			body_part = 1,
			type = "act",
			blocks = {
				action = -1,
				walk = -1
			}
		},
		action_duration = tweak_data.interaction.free.timer,
		followup_objective = followup_objective
	}
	local receiver_areas = managers.groupai:state():get_areas_from_nav_seg_id(objective.nav_seg)
	local so_descriptor = {
		interval = 10,
		search_dis_sq = 25000000,
		AI_group = "enemies",
		base_chance = 1,
		chance_inc = 0,
		usage_amount = 1,
		objective = objective,
		search_pos = mvector3.copy(data.m_pos),
		admin_clbk = callback(CivilianLogicFlee, CivilianLogicFlee, "on_rescue_SO_administered", data),
		verification_clbk = callback(CivilianLogicFlee, CivilianLogicFlee, "rescue_SO_verification", {
			logic_data = data,
			areas = receiver_areas
		})
	}
	local so_id = "rescue" .. tostring(data.key)
	my_data.rescue_SO_id = so_id

	managers.groupai:state():add_special_objective(so_id, so_descriptor)
	managers.groupai:state():register_rescueable_hostage(data.unit, nil)
end

function CivilianLogicFlee._unregister_rescue_SO(data, my_data)
	if my_data.rescuer then
		if alive(my_data.rescuer) then
			local rescuer = my_data.rescuer

			managers.groupai:state():on_objective_failed(rescuer, rescuer:brain():objective())
		end
		
		my_data.rescuer = nil
	elseif my_data.rescue_SO_id then
		managers.groupai:state():remove_special_objective(my_data.rescue_SO_id)

		my_data.rescue_SO_id = nil

		managers.groupai:state():unregister_rescueable_hostage(data.key)
	elseif my_data.delayed_rescue_SO_id then
		CopLogicBase.chk_cancel_delayed_clbk(my_data, my_data.delayed_rescue_SO_id)

		my_data.delayed_rescue_SO_id = nil
	end

	my_data.rescue_active = nil
end

function CivilianLogicFlee._run_away_from_alert(data, alert_data)
	if not data.is_tied and data.char_tweak.faster_reactions and data.char_tweak.flee_type ~= "hide" and not data.char_tweak.is_escort and not data.unit:base()._tweak_table == "drunk_pilot" and managers.groupai:state():is_police_called() then --faster reactions = just book it
		if CivilianLogicFlee._get_coarse_flee_path(data) then
			data.unit:brain():set_update_enabled_state(true)
			
			return
		end
	end

	local my_data = data.internal_data
	local avoid_pos = nil

	if alert_data[1] == "bullet" then
		local tail = alert_data[2]
		local head = alert_data[6]
		local alert_dir = head - tail
		local alert_len = mvector3.normalize(alert_dir)
		avoid_pos = data.m_pos - tail
		local my_dot = mvector3.dot(alert_dir, avoid_pos)

		mvector3.set(avoid_pos, alert_dir)
		mvector3.multiply(avoid_pos, my_dot)
		mvector3.add(avoid_pos, tail)
	else
		avoid_pos = alert_data[2] or alert_data[5] and alert_data[5]:position() or math.UP:random_orthogonal() * 100 + data.m_pos
	end

	my_data.avoid_pos = avoid_pos

	if not my_data.cover_search_task_key then
		my_data.cover_search_task_key = "CivilianLogicFlee._find_hide_cover" .. tostring(data.key)

		CopLogicBase.queue_task(my_data, my_data.cover_search_task_key, CivilianLogicFlee._find_hide_cover, data, data.t + 0.5)
	end
end

function CivilianLogicFlee.clbk_chk_call_the_police(ignore_this, data)
	local my_data = data.internal_data

	CopLogicBase.on_delayed_clbk(my_data, my_data.call_police_clbk_id)

	my_data.call_police_clbk_id = nil

	if managers.groupai:state():is_police_called() or not alive(data.unit) then
		return
	end

	local my_areas = managers.groupai:state():get_areas_from_nav_seg_id(data.unit:movement():nav_tracker():nav_segment())
	local already_calling = false

	for u_key, u_data in pairs(managers.enemy:all_civilians()) do
		local civ_nav_seg = u_data.unit:movement():nav_tracker():nav_segment()

		if my_areas[civ_nav_seg] and u_data.unit:anim_data().call_police then
			already_calling = true

			break
		end
	end
	
	if data.unit:anim_data() and data.unit:anim_data().react_enter then
		my_data.call_police_clbk_id = "civ_call_police" .. tostring(data.key)
		local call_t = math.max(data.call_police_delay_t or 0, TimerManager:game():time() + 0.5)

		CopLogicBase.add_delayed_clbk(my_data, my_data.call_police_clbk_id, callback(CivilianLogicFlee, CivilianLogicFlee, "clbk_chk_call_the_police", data), call_t)
		
		return
	elseif not already_calling and (not my_data.calling_the_police or not data.unit:movement():chk_action_forbidden("walk")) then
		local action = {
			variant = "cmf_so_call_police",
			body_part = 1,
			type = "act",
			blocks = {}
		}
		my_data.calling_the_police = data.unit:movement():action_request(action)

		if my_data.calling_the_police then
			CivilianLogicFlee._say_call_the_police(data, my_data)
			managers.groupai:state():on_criminal_suspicion_progress(nil, data.unit, "calling")
		end
	end
	
	my_data.call_police_clbk_id = "civ_call_police" .. tostring(data.key)
	local call_t = math.max(data.call_police_delay_t or 0, TimerManager:game():time() + math.lerp(1, 10, math.random()))

	CopLogicBase.add_delayed_clbk(my_data, my_data.call_police_clbk_id, callback(CivilianLogicFlee, CivilianLogicFlee, "clbk_chk_call_the_police", data), call_t)
end
