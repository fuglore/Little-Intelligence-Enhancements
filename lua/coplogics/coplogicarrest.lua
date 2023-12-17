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


function CopLogicArrest._upd_enemy_detection(data)
	managers.groupai:state():on_unit_detection_updated(data.unit)

	data.t = TimerManager:game():time()
	local my_data = data.internal_data
	local delay = CopLogicBase._upd_attention_obj_detection(data, nil, nil)
	local all_attention_objects = data.detected_attention_objects
	local arrest_targets = my_data.arrest_targets

	CopLogicArrest._verify_arrest_targets(data, my_data)

	local new_attention, new_prio_slot, new_reaction = CopLogicArrest._get_priority_attention(data, data.detected_attention_objects)
	local old_att_obj = data.attention_obj

	CopLogicBase._set_attention_obj(data, new_attention, new_reaction)

	local should_arrest = new_reaction == AIAttentionObject.REACT_ARREST
	local should_stand_close = new_reaction == AIAttentionObject.REACT_SCARED

	if should_arrest ~= my_data.should_arrest or should_stand_close ~= my_data.should_stand_close then
		CopLogicArrest._cancel_advance(data, my_data)
	end
	
	my_data.should_arrest = should_arrest
	my_data.should_stand_close = should_stand_close
	--log("should_arrest: " .. tostring(should_arrest))
	--log("should_stand_close: " .. tostring(should_stand_close))

	if should_arrest and not my_data.arrest_targets[new_attention.u_key] then
		my_data.arrest_targets[new_attention.u_key] = {
			attention_obj = new_attention
		}

		managers.groupai:state():on_arrest_start(data.key, new_attention.u_key)
	end

	CopLogicArrest._mark_call_in_event(data, my_data, new_attention)
	CopLogicArrest._chk_say_discovery(data, my_data, new_attention)

	if not should_arrest and not should_stand_close then
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
		if (not new_reaction or new_reaction < AIAttentionObject.REACT_SHOOT or not new_attention.verified or new_attention.dis >= 1500) and my_data.in_position then
			--log("a")
			if data.char_tweak.calls_in and my_data.next_action_delay_t < data.t and managers.groupai:state():can_police_be_called() and not managers.groupai:state():is_police_called() and not my_data.calling_the_police and not my_data.turning then
				CopLogicArrest._call_the_police(data, my_data, true)

				return delay
			end

			if not managers.groupai:state():can_police_be_called() or (managers.groupai:state():is_police_called() or managers.groupai:state():chk_enemy_calling_in_area(managers.groupai:state():get_area_from_nav_seg_id(data.unit:movement():nav_tracker():nav_segment()), data.key)) and not my_data.calling_the_police then
				local wanted_state = CopLogicBase._get_logic_state_from_reaction(data) or "idle"

				CopLogicBase._exit(data.unit, wanted_state)
				CopLogicBase._report_detections(data.detected_attention_objects)

				return delay
			end
		else
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
			end
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

				if data.unit:brain():action_request(shoot_action) then
					my_data.shooting = true
				end
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