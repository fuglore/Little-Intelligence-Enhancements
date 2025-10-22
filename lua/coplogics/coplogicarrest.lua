function CopLogicArrest.enter(data, new_logic_name, enter_params)
	CopLogicBase.enter(data, new_logic_name, enter_params)
	data.unit:brain():cancel_all_pathing_searches()

	local old_internal_data = data.internal_data
	local my_data = {
		unit = data.unit
	}
	data.internal_data = my_data
	my_data.detection = data.char_tweak.detection.guard
	my_data.arrest_targets = {}

	if old_internal_data then
		if old_internal_data.best_cover then
			my_data.best_cover = old_internal_data.best_cover

			managers.navigation:reserve_cover(my_data.best_cover[1], data.pos_rsrv_id)
		end

		if old_internal_data.nearest_cover then
			my_data.nearest_cover = old_internal_data.nearest_cover

			managers.navigation:reserve_cover(my_data.nearest_cover[1], data.pos_rsrv_id)
		end
	end
	
	CopLogicIdle._chk_has_old_action(data, my_data)
	data.unit:brain():set_attention_settings({
		cbt = true
	})
	my_data.next_action_delay_t = data.t + 0.5
	my_data.weapon_range = data.char_tweak.weapon[data.unit:inventory():equipped_unit():base():weapon_tweak_data().usage].range
	
	if (not data.char_tweak.allowed_poses or data.char_tweak.allowed_poses.stand) and not data.unit:anim_data().stand then
		CopLogicAttack._chk_request_action_stand(data)
	end

	data.unit:movement():set_cool(false)
	
	if my_data ~= data.internal_data then
		return
	end

	local key_str = tostring(data.key)
	my_data.update_task_key = "CopLogicArrest.queued_update" .. key_str
	
	data.unit:brain():set_update_enabled_state(false)
	CopLogicArrest.queued_update(data)
end

function CopLogicArrest._mark_call_in_event(data, my_data, attention_obj)
	if not attention_obj then
		return
	end

	if attention_obj.reaction == AIAttentionObject.REACT_ARREST then
		my_data.call_in_event = "criminal"
	elseif AIAttentionObject.REACT_SCARED <= attention_obj.reaction then
		local unit_base = attention_obj.unit:base()
		local unit_brain = attention_obj.unit:brain()

		if attention_obj.unit:in_slot(17) then
			my_data.call_in_event = managers.enemy:get_corpse_unit_data_from_key(attention_obj.unit:key()).is_civilian and "dead_civ" or "dead_cop"
		elseif attention_obj.unit:in_slot(managers.slot:get_mask("enemies")) then
			my_data.call_in_event = "w_hot"
		elseif unit_brain and unit_brain.is_hostage and unit_brain:is_hostage() then
			my_data.call_in_event = managers.enemy:is_civilian(attention_obj.unit) and "hostage_civ" or "hostage_cop"
		elseif unit_base and unit_base.is_drill then
			my_data.call_in_event = "drill"
		elseif unit_base and unit_base.sentry_gun then
			my_data.call_in_event = "sentry_gun"
		elseif unit_base and unit_base.is_hacking_device then
			my_data.call_in_event = "computer"
		elseif unit_base and unit_base.is_tripmine then
			my_data.call_in_event = "trip_mine"
		elseif attention_obj.unit:carry_data() then
			if attention_obj.unit:carry_data():carry_id() == "person" then
				my_data.call_in_event = "body_bag"
			else
				my_data.call_in_event = "bag"
			end
		elseif attention_obj.unit:in_slot(21) then
			my_data.call_in_event = "civilian"
		end
	end
end

function CopLogicArrest._say_call_the_police(data, my_data)
	if data.SO_access_str == "taser" then
		return
	end

	local blame_list = {
		bag = "a22",
		body_bag = "a19",
		drill = "a25",
		criminal = "a09",
		computer = "a24",
		trip_mine = "a21",
		w_hot = data.unit:base():has_tag("law") and "a16" or "a09",
		civilian = "a15",
		sentry_gun = "a20",
		dead_cop = data.unit:base():has_tag("law") and "a12" or "a15",
		hostage_cop = data.unit:base():has_tag("law") and "a14" or "a15",
		hostage_civ = "a13",
		dead_civ = "a11"
	}

	data.unit:sound():say(blame_list[my_data.call_in_event] or "a23", true)
end

function CopLogicArrest._verify_arrest_targets(data, my_data)
	local all_attention_objects = data.detected_attention_objects
	local arrest_targets = my_data.arrest_targets
	local group_ai = managers.groupai:state()

	for u_key, arrest_data in pairs(arrest_targets) do
		local drop, penalty = nil
		local record = group_ai:criminal_record(u_key)

		if not record then
			-- Nothing
		elseif arrest_data.intro_pos and mvector3.distance_sq(arrest_data.attention_obj.m_pos, arrest_data.intro_pos) > 28900 then
			drop = true
			penalty = true
		elseif record.status ~= "tased" and arrest_data.intro_t and record.assault_t and record.assault_t > arrest_data.intro_t + 0.6 then
			drop = true
			penalty = true
		elseif record.status and record.status ~= "tased" then
			drop = true
		elseif all_attention_objects[u_key] ~= arrest_data.attention_obj or not arrest_data.attention_obj.identified then
			drop = true

			if arrest_data.intro_pos then
				penalty = true
			end
		end

		if drop then
			if penalty then
				record.arrest_timeout = data.t + arrest_data.attention_obj.unit:base():arrest_settings().arrest_timeout
			end

			group_ai:on_arrest_end(data.key, u_key)

			arrest_targets[u_key] = nil
		end
	end
end

function CopLogicArrest._upd_enemy_detection(data)
	managers.groupai:state():on_unit_detection_updated(data.unit)

	data.t = TimerManager:game():time()
	local my_data = data.internal_data
	local delay = CopLogicBase._upd_attention_obj_detection(data, nil, nil)
	local all_attention_objects = data.detected_attention_objects
	local arrest_targets = my_data.arrest_targets

	CopLogicArrest._verify_arrest_targets(data, my_data)

	local new_attention, new_prio_slot, new_reaction = CopLogicIdle._get_priority_attention(data, data.detected_attention_objects)
	local old_att_obj = data.attention_obj

	CopLogicBase._set_attention_obj(data, new_attention, new_reaction)

	local should_arrest = new_reaction == AIAttentionObject.REACT_ARREST
	local should_stand_close = new_reaction == AIAttentionObject.REACT_SCARED or new_attention and new_attention.criminal_record and new_attention.criminal_record.status

	if should_arrest ~= my_data.should_arrest or should_stand_close ~= my_data.should_stand_close then
		my_data.should_arrest = should_arrest
		my_data.should_stand_close = should_stand_close

		CopLogicArrest._cancel_advance(data, my_data)
	end

	if should_arrest and not my_data.arrest_targets[new_attention.u_key] then
		my_data.arrest_targets[new_attention.u_key] = {
			attention_obj = new_attention
		}

		managers.groupai:state():on_arrest_start(data.key, new_attention.u_key)
	end

	CopLogicArrest._mark_call_in_event(data, my_data, new_attention)
	CopLogicArrest._chk_say_discovery(data, my_data, new_attention)

	if not my_data.should_arrest and not my_data.should_stand_close then
		my_data.in_position = true
	end

	local current_attention = data.unit:movement():attention()

	if new_attention and not current_attention or current_attention and not new_attention or new_attention and current_attention.u_key ~= new_attention.u_key then
		if new_attention then
			CopLogicBase._set_attention(data, new_attention)
		else
			CopLogicBase._reset_attention(data)
		end
	end

	if new_reaction ~= AIAttentionObject.REACT_ARREST then
		local wanted_state = CopLogicBase._get_logic_state_from_reaction(data)

		if wanted_state and wanted_state ~= data.name then
			if my_data.calling_the_police then
				local action_data = {
					body_part = 3,
					type = "idle"
				}

				data.unit:brain():action_request(action_data)
			end

			CopLogicBase._exit(data.unit, wanted_state)
			CopLogicBase._report_detections(data.detected_attention_objects)

			return delay
		elseif not my_data.calling_the_police and my_data.in_position then
			CopLogicArrest._call_the_police(data, my_data, true)
			
			return delay
		end
	end
	
	return delay
end

function CopLogicArrest.queued_update(data)
	data.t = TimerManager:game():time()
	local my_data = data.internal_data

	local delay = CopLogicArrest._upd_enemy_detection(data)

	if my_data ~= data.internal_data then
		CopLogicBase._report_detections(data.detected_attention_objects)
		
		return
	end

	if my_data.has_old_action or my_data.old_action_advancing then
		CopLogicAttack._upd_stop_old_action(data, my_data)
		
		if my_data.has_old_action or my_data.old_action_advancing then
			CopLogicBase.queue_task(my_data, my_data.update_task_key, CopLogicArrest.queued_update, data, data.t + delay, data.important)
			CopLogicBase._report_detections(data.detected_attention_objects)
			
			return
		end
	end

	local attention_obj = data.attention_obj
	local arrest_data = attention_obj and my_data.arrest_targets[attention_obj.u_key]

	if not data.unit:anim_data().reload and not data.unit:movement():chk_action_forbidden("action") then
		if attention_obj and AIAttentionObject.REACT_ARREST <= attention_obj.reaction then
			if not my_data.shooting and not data.unit:anim_data().reload then
				local shoot_action = {
					body_part = 3,
					type = "shoot"
				}

				my_data.shooting = data.unit:brain():action_request(shoot_action)
			end
		elseif my_data.shooting and not data.unit:anim_data().reload then
			local idle_action = {
				body_part = 3,
				type = "idle"
			}

			data.unit:brain():action_request(idle_action)
		end
	end

	if arrest_data then
		if not arrest_data.intro_t then
			arrest_data.intro_t = data.t
			
			if managers.groupai:state():whisper_mode() then
				data.unit:sound():say("i01", true)
			end

			if not attention_obj.is_human_player then
				attention_obj.unit:brain():on_intimidated(1, data.unit)
			end

			if not data.unit:movement():chk_action_forbidden("action") then
				local new_action = {
					variant = "arrest",
					body_part = 1,
					type = "act"
				}

				if data.unit:brain():action_request(new_action) then
					my_data.gesture_arrest = true
				end
			end
		elseif not arrest_data.intro_pos and data.t - arrest_data.intro_t > 1 then
			arrest_data.intro_pos = mvector3.copy(attention_obj.m_pos)
		end
	end

	if arrest_data and arrest_data.intro_pos or my_data.should_stand_close and not my_data.in_position then
		CopLogicArrest._upd_advance(data, my_data, attention_obj, arrest_data)
	end

	if attention_obj and not my_data.turning and not my_data.advancing and not data.unit:movement():chk_action_forbidden("walk") then
		CopLogicIdle._chk_request_action_turn_to_look_pos(data, my_data, data.m_pos, attention_obj.m_pos)
	end

	CopLogicArrest._upd_cover(data)
	CopLogicBase.queue_task(my_data, my_data.update_task_key, CopLogicArrest.queued_update, data, data.t + delay, data.important)
	CopLogicBase._report_detections(data.detected_attention_objects)
end

function CopLogicArrest._call_the_police(data, my_data, paniced)
	if my_data.has_old_action or my_data.old_action_advancing then
		return
	end

	local action = {
		variant = "arrest_call",
		body_part = 1,
		type = "act",
		blocks = {
			aim = -1,
			action = -1,
			walk = -1
		}
	}
	my_data.calling_the_police = data.unit:movement():action_request(action)

	if my_data.calling_the_police then
		managers.groupai:state():on_criminal_suspicion_progress(nil, data.unit, "calling")
		CopLogicArrest._say_call_the_police(data, my_data)
	end
end

function CopLogicArrest._upd_advance(data, my_data, attention_obj, arrest_data)
	local action_taken = my_data.turning or data.unit:movement():chk_action_forbidden("walk")
	local whisper = managers.groupai:state():whisper_mode()
	
	if arrest_data and my_data.should_arrest then
		if attention_obj.dis < 180 then
			if not action_taken then
				if not data.unit:anim_data().idle_full_blend then
					if attention_obj.dis < 150 and not data.unit:anim_data().idle then
						local action_data = {
							body_part = 1,
							type = "idle"
						}

						data.unit:brain():action_request(action_data)
					end
				elseif not data.unit:anim_data().crouch then
					CopLogicAttack._chk_request_action_crouch(data)
				end

				attention_obj.unit:movement():on_cuffed()
				data.unit:sound():say("i03", true, false)

				return
			end
		elseif not arrest_data.approach_snd and attention_obj.dis < 600 and attention_obj.dis >= 180 and not data.unit:sound():speaking(data.t) then
			arrest_data.approach_snd = true
			
			if whisper then
				data.unit:sound():say("i02", true)
			end
		elseif not my_data.advancing then
			my_data.in_position = nil
			my_data.next_action_delay_t = -1 --start next one immediately, target moved slightly out of range
		end
	end

	if action_taken then
		return
	end

	if my_data.advancing then
		-- Nothing
	elseif my_data.advance_path then
		if (not whisper and LIES.settings.hhtacs or my_data.next_action_delay_t < data.t) and not data.unit:movement():chk_action_forbidden("walk") then
			if (not data.char_tweak.allowed_poses or data.char_tweak.allowed_poses.stand) and my_data.should_stand_close and not data.unit:anim_data().stand then
				CopLogicAttack._chk_request_action_stand(data)
			end

			local new_action_data = {
				variant = not LIES.settings.hhtacs and "walk" or "run",
				body_part = 2,
				type = "walk",
				nav_path = my_data.advance_path
			}
			my_data.advance_path = nil
			my_data.advancing = data.unit:brain():action_request(new_action_data)
		end
	elseif my_data.processing_path then
		CopLogicArrest._process_pathing_results(data, my_data)
		
		if my_data.advance_path then
			if (not whisper and LIES.settings.hhtacs or my_data.next_action_delay_t < data.t) and not data.unit:movement():chk_action_forbidden("walk") then
				if (not data.char_tweak.allowed_poses or data.char_tweak.allowed_poses.stand) and my_data.should_stand_close and not data.unit:anim_data().stand then
					CopLogicAttack._chk_request_action_stand(data)
				end

				local new_action_data = {
					variant = not LIES.settings.hhtacs and "walk" or "run",
					body_part = 2,
					type = "walk",
					nav_path = my_data.advance_path
				}
				my_data.advance_path = nil
				my_data.advancing = data.unit:brain():action_request(new_action_data)
			end
		end
	elseif not my_data.in_position and my_data.next_action_delay_t < data.t then
		if my_data.should_arrest then
			my_data.path_search_id = "cuff" .. tostring(data.key)
			my_data.processing_path = true

			if attention_obj.nav_tracker:lost() then
				data.unit:brain():search_for_path(my_data.path_search_id, attention_obj.nav_tracker:field_position(), 1)
			else
				data.unit:brain():search_for_path_to_unit(my_data.path_search_id, attention_obj.unit)
			end
		elseif my_data.should_stand_close and attention_obj then
			local close_pos = CopLogicArrest._get_att_obj_close_pos(data, my_data)

			if close_pos then
				my_data.path_search_id = "stand_close" .. tostring(data.key)
				my_data.processing_path = true

				data.unit:brain():search_for_path(my_data.path_search_id, close_pos, 1, nil)
			else
				my_data.in_position = true
			end
		else
			my_data.in_position = true --just call it in, whatever
		end
	end
end

function CopLogicArrest._process_pathing_results(data, my_data)
	if data.pathing_results then
		for path_id, path in pairs(data.pathing_results) do
			if path_id == my_data.path_search_id then
				if path ~= "failed" then
					my_data.advance_path = path
				elseif my_data.should_arrest or my_data.should_stand_close then
					my_data.in_position = true
				end

				my_data.processing_path = nil
				my_data.path_search_id = nil
			end
		end

		data.pathing_results = nil
	end
end

function CopLogicArrest.action_complete_clbk(data, action)
	local my_data = data.internal_data
	local action_type = action:type()

	if action_type == "walk" then
		my_data.advancing = nil
		my_data.old_action_advancing = nil
		my_data.next_action_delay_t = TimerManager:game():time() + math.lerp(2, 2.5, math.random())

		if not my_data.old_action_advancing then
			my_data.in_position = true
		end
	elseif action_type == "shoot" then
		my_data.shooting = nil
	elseif action_type == "turn" then
		my_data.turning = nil
	elseif action_type == "act" then
		if my_data.gesture_arrest then
			my_data.gesture_arrest = nil
		elseif my_data.calling_the_police then
			my_data.calling_the_police = nil

			if not my_data.called_the_police then
				managers.groupai:state():on_criminal_suspicion_progress(nil, data.unit, "call_interrupted")
			end
		end

		my_data.next_action_delay_t = TimerManager:game():time() + math.lerp(2, 2.5, math.random())
	end
end